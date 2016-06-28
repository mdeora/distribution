#!/usr/bin/env perl

use strict;
use warnings;

use File::Temp qw/tempfile/;
use ImplyTest;
use JSON;
use Test::Differences;
use Test::More tests => 11;

my $iap = ImplyTest->new;
my $dir = $iap->dir;

# Start up services
ok($iap->start('quickstart'), 'started');

{
# Load example data
my $taskok = $iap->runtask(JSON::decode_json(scalar qx[cat \Q$dir\E/quickstart/wikiticker-index.json]));
ok($taskok, 'example index task');

# Wait for data to load
is($iap->await_load('wikiticker'), 100, 'example loading complete');

# Direct Druid query
my $druid_result = $iap->query_druid(JSON::decode_json(scalar qx[cat $dir/quickstart/wikiticker-top-pages.json]));
my $druid_expected = JSON::decode_json(<<'EOT');
[
  {
    "timestamp":"2016-06-27T00:00:11.080Z",
    "result":[
      {"edits":29,"page":"Copa América Centenario"},
      {"edits":16,"page":"User:Cyde/List of candidates for speedy deletion/Subpage"},
      {"edits":16,"page":"Wikipedia:Administrators' noticeboard/Incidents"},
      {"edits":15,"page":"2016 Wimbledon Championships – Men's Singles"},
      {"edits":15,"page":"Wikipedia:Administrator intervention against vandalism"},
      {"edits":15,"page":"Wikipedia:Vandalismusmeldung"},
      {"edits":12,"page":"The Winds of Winter (Game of Thrones)"},
      {"edits":12,"page":"ولاية الجزائر"},
      {"edits":10,"page":"Copa América"},
      {"edits":10,"page":"Lionel Messi"},
      {"edits":10,"page":"Wikipedia:Requests for page protection"},
      {"edits":10,"page":"Wikipedia:Usernames for administrator attention"},
      {"edits":10,"page":"Википедия:Опросы/Унификация шаблонов «Не переведено»"},
      {"edits":9,"page":"Bailando 2015"},
      {"edits":9,"page":"Bud Spencer"},
      {"edits":9,"page":"User:Osterb/sandbox"},
      {"edits":9,"page":"Wikipédia:Le Bistro/27 juin 2016"},
      {"edits":9,"page":"Ветра зимы (Игра престолов)"},
      {"edits":8,"page":"Användare:Lsjbot/Namnkonflikter-PRIVAT"},
      {"edits":8,"page":"Eurocopa 2016"},
      {"edits":8,"page":"Mistrzostwa Europy w Piłce Nożnej 2016"},
      {"edits":8,"page":"Usuario:Carmen González C/Science and technology in China"},
      {"edits":8,"page":"Wikipedia:Administrators' noticeboard"},
      {"edits":8,"page":"Wikipédia:Demande de suppression immédiate"},
      {"edits":8,"page":"World Deaf Championships"}
    ]
  }
]
EOT

eq_or_diff($druid_result, $druid_expected, 'example druid query results are as expected');

# Pivot home page
my $pivot_result = $iap->get_pivot_config(1);
my @datasources = sort map { $_->{name} } @{$pivot_result->{'appSettings'}{'dataSources'}};
eq_or_diff(\@datasources, ['wikiticker'], 'example pivot config includes all datasources');

# PlyQL query
my $plyql_result = $iap->post_pivot("/plyql", {
  query => "SELECT page, SUM(count) AS Edits FROM wikiticker WHERE '2016-06-27' <= __time AND __time < '2016-06-28' GROUP BY page ORDER BY Edits DESC LIMIT 5",
  outputType => 'json'
});
my $plyql_expected = JSON::decode_json(<<'EOT');
[
  {"Edits":29,"page":"Copa América Centenario"},
  {"Edits":16,"page":"User:Cyde/List of candidates for speedy deletion/Subpage"},
  {"Edits":16,"page":"Wikipedia:Administrators' noticeboard/Incidents"},
  {"Edits":15,"page":"2016 Wimbledon Championships – Men's Singles"},
  {"Edits":15,"page":"Wikipedia:Administrator intervention against vandalism"}
]
EOT

eq_or_diff($plyql_result, $plyql_expected, 'example plyql query results are as expected');
}

#
# Your own data!
#

{
# Write pageviews data to a file
my ($datafh, $datafile) = tempfile(UNLINK => 1);
$datafile = File::Spec->rel2abs($datafile);
print $datafh <<'EOT';
{"time": "2015-09-01T00:00:00Z", "url": "/foo/bar", "user": "alice", "latencyMs": 32}
{"time": "2015-09-01T01:00:00Z", "url": "/", "user": "bob", "latencyMs": 11}
{"time": "2015-09-01T01:30:00Z", "url": "/foo/bar", "user": "bob", "latencyMs": 45}
EOT
close $datafh;

# Index task
my $task_object = JSON::decode_json(<<EOT);
{
  "type" : "index_hadoop",
  "spec" : {
    "ioConfig" : {
      "type" : "hadoop",
      "inputSpec" : {
        "type" : "static",
        "paths" : "$datafile"
      }
    },
    "dataSchema" : {
      "dataSource" : "pageviews",
      "granularitySpec" : {
        "type" : "uniform",
        "segmentGranularity" : "day",
        "queryGranularity" : "none",
        "intervals" : ["2015-09-01/2015-09-02"]
      },
      "parser" : {
        "type" : "string",
        "parseSpec" : {
          "format" : "json",
          "dimensionsSpec" : {
            "dimensions" : ["url", "user"]
          },
          "timestampSpec" : {
            "format" : "auto",
            "column" : "time"
          }
        }
      },
      "metricsSpec" : [
        {"name" : "views", "type" : "count"},
        {"name" : "latencyMs", "type" : "doubleSum", "fieldName" : "latencyMs"}
      ]
    },
    "tuningConfig" : {
      "type" : "hadoop",
      "partitionsSpec" : {
        "type" : "hashed",
        "targetPartitionSize" : 5000000
      },
      "jobProperties" : {}
    }
  }
}
EOT

# Load data!
my $taskok = $iap->runtask($task_object);
ok($taskok, 'example index task');

# Wait for data to load
is($iap->await_load('pageviews'), 100, 'pageviews loading complete');

# Direct Druid query
my $query_result = $iap->query_druid({
  queryType => 'timeseries',
  dataSource => 'pageviews',
  granularity => 'day',
  filter => {
    type => 'selector',
    dimension => 'user',
    value => 'bob',
  },
  aggregations => [
    {type => 'longSum', name => 'views', fieldName => 'views'},
  ],
  intervals => "2015-09-01/P1D",
});

my $expected_result = [{
  'timestamp' => '2015-09-01T00:00:00.000Z',
  'result' => {'views' => 2},
}];

eq_or_diff($query_result, $expected_result, 'pageviews druid query results are as expected');

# Pivot home page
my $pivot_result = $iap->get_pivot_config(2);
my @datasources = sort map { $_->{name} } @{$pivot_result->{'appSettings'}{'dataSources'}};
eq_or_diff(\@datasources, ['pageviews', 'wikiticker'], 'pageviews pivot config includes all datasources');

# PlyQL query
my $plyql_result = $iap->post_pivot("/plyql", {
  query => "SELECT user, SUM(views) FROM pageviews WHERE '2015-09-01T00:00:00' <= __time AND __time < '2015-09-02T00:00:00' GROUP BY user ORDER BY user",
  outputType => 'json'
});
my $plyql_expected = [
  {"user" => "alice", "SUM(views)" => 1},
  {"user" => "bob", "SUM(views)" => 2},
];

eq_or_diff($plyql_result, $plyql_expected, 'pageviews plyql query results are as expected');
}
