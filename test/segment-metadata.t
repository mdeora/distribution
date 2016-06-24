#!/usr/bin/env perl

use strict;
use warnings;

use ImplyTest;
use JSON;
use Test::Differences;
use Test::More tests => 4;

my $iap = ImplyTest->new;
my $dir = $iap->dir;

# Start up services
ok($iap->start('quickstart'), 'started');

# Load example data
my $taskok = $iap->runtask(JSON::decode_json(scalar qx[cat \Q$dir\E/quickstart/wikiticker-index.json]));
ok($taskok, 'example index task');

# Wait for data to load
is($iap->await_load('wikiticker'), 100, 'example loading complete');

# Direct Druid query
my $druid_result_minus_id = $iap->query_druid({
  queryType => 'segmentMetadata',
  dataSource => 'wikiticker',
  merge => JSON::true,
  analysisTypes => ['INTERVAL']
});

delete $druid_result_minus_id->[0]{id};

my $druid_expected_minus_id = [{
  "aggregators" => undef,
  "columns" => {
     "__time" => {"minValue" => undef, "maxValue" => undef, "cardinality" => undef, "errorMessage" => undef, "size" => 0, "type" => "LONG", "hasMultipleValues" => $JSON::false},
     "added" => {"minValue" => undef, "maxValue" => undef, "cardinality" => undef, "errorMessage" => undef, "size" => 0, "type" => "LONG", "hasMultipleValues" => $JSON::false},
     "channel" => {"minValue" => undef, "maxValue" => undef, "cardinality" => 0, "errorMessage" => undef, "size" => 0, "type" => "STRING", "hasMultipleValues" => $JSON::false},
     "cityName" => {"minValue" => undef, "maxValue" => undef, "cardinality" => 0, "errorMessage" => undef, "size" => 0, "type" => "STRING", "hasMultipleValues" => $JSON::false},
     "comment" => {"minValue" => undef, "maxValue" => undef, "cardinality" => 0, "errorMessage" => undef, "size" => 0, "type" => "STRING", "hasMultipleValues" => $JSON::false},
     "count" => {"minValue" => undef, "maxValue" => undef, "cardinality" => undef, "errorMessage" => undef, "size" => 0, "type" => "LONG", "hasMultipleValues" => $JSON::false},
     "countryIsoCode" => {"minValue" => undef, "maxValue" => undef, "cardinality" => 0, "errorMessage" => undef, "size" => 0, "type" => "STRING", "hasMultipleValues" => $JSON::false},
     "countryName" => {"minValue" => undef, "maxValue" => undef, "cardinality" => 0, "errorMessage" => undef, "size" => 0, "type" => "STRING", "hasMultipleValues" => $JSON::false},
     "deleted" => {"minValue" => undef, "maxValue" => undef, "cardinality" => undef, "errorMessage" => undef, "size" => 0, "type" => "LONG", "hasMultipleValues" => $JSON::false},
     "delta" => {"minValue" => undef, "maxValue" => undef, "cardinality" => undef, "errorMessage" => undef, "size" => 0, "type" => "LONG", "hasMultipleValues" => $JSON::false},
     "isAnonymous" => {"minValue" => undef, "maxValue" => undef, "cardinality" => 0, "errorMessage" => undef, "size" => 0, "type" => "STRING", "hasMultipleValues" => $JSON::false},
     "isMinor" => {"minValue" => undef, "maxValue" => undef, "cardinality" => 0, "errorMessage" => undef, "size" => 0, "type" => "STRING", "hasMultipleValues" => $JSON::false},
     "isNew" => {"minValue" => undef, "maxValue" => undef, "cardinality" => 0, "errorMessage" => undef, "size" => 0, "type" => "STRING", "hasMultipleValues" => $JSON::false},
     "isRobot" => {"minValue" => undef, "maxValue" => undef, "cardinality" => 0, "errorMessage" => undef, "size" => 0, "type" => "STRING", "hasMultipleValues" => $JSON::false},
     "isUnpatrolled" => {"minValue" => undef, "maxValue" => undef, "cardinality" => 0, "errorMessage" => undef, "size" => 0, "type" => "STRING", "hasMultipleValues" => $JSON::false},
     "metroCode" => {"minValue" => undef, "maxValue" => undef, "cardinality" => 0, "errorMessage" => undef, "size" => 0, "type" => "STRING", "hasMultipleValues" => $JSON::false},
     "namespace" => {"minValue" => undef, "maxValue" => undef, "cardinality" => 0, "errorMessage" => undef, "size" => 0, "type" => "STRING", "hasMultipleValues" => $JSON::false},
     "page" => {"minValue" => undef, "maxValue" => undef, "cardinality" => 0, "errorMessage" => undef, "size" => 0, "type" => "STRING", "hasMultipleValues" => $JSON::false},
     "regionIsoCode" => {"minValue" => undef, "maxValue" => undef, "cardinality" => 0, "errorMessage" => undef, "size" => 0, "type" => "STRING", "hasMultipleValues" => $JSON::false},
     "regionName" => {"minValue" => undef, "maxValue" => undef, "cardinality" => 0, "errorMessage" => undef, "size" => 0, "type" => "STRING", "hasMultipleValues" => $JSON::false},
     "user" => {"minValue" => undef, "maxValue" => undef, "cardinality" => 0, "errorMessage" => undef, "size" => 0, "type" => "STRING", "hasMultipleValues" => $JSON::false},
     "user_unique" => {"minValue" => undef, "maxValue" => undef, "cardinality" => undef, "errorMessage" => undef, "size" => 0, "type" => "hyperUnique", "hasMultipleValues" => $JSON::false}
  },
  "intervals" => ["2015-09-12T00:00:00.000Z/2015-09-13T00:00:00.000Z"],
  "numRows" => 39244,
  "queryGranularity" => undef,
  "size" => 0
}];

eq_or_diff($druid_result_minus_id, $druid_expected_minus_id, 'druid query results are as expected');
