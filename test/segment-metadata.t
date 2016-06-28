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
  analysisTypes => ['interval','minMax','aggregators','queryGranularity']
});

delete $druid_result_minus_id->[0]{id};

my $druid_expected_minus_id = JSON::decode_json(<<'EOT');
[
  {
    "intervals":["2016-06-27T00:00:00.000Z/2016-06-28T00:00:00.000Z"],
    "columns": {
      "__time": {"type":"LONG","hasMultipleValues":false,"size":0,"cardinality":null,"minValue":null,"maxValue":null,"errorMessage":null},
      "added": {"type":"LONG","hasMultipleValues":false,"size":0,"cardinality":null,"minValue":null,"maxValue":null,"errorMessage":null},
      "channel": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"#ar.wikipedia","maxValue":"#zh.wikipedia","errorMessage":null},
      "cityName": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"","maxValue":"Zurich","errorMessage":null},
      "comment": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"!vote Keep","maxValue":"（简体中文）. 引文格式1维护：未识别语文类型 (link)其他特色條目：綏遠抗戰 － 巴伐利亚级战列舰 － 第一代纳尔逊子爵霍雷肖·纳尔逊 特色列表：印度尼西亚总理列表 － 苏联最高领导人列","errorMessage":null},
      "commentLength": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"1","maxValue":"99","errorMessage":null},
      "count": {"type":"LONG","hasMultipleValues":false,"size":0,"cardinality":null,"minValue":null,"maxValue":null,"errorMessage":null},
      "countryIsoCode": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"","maxValue":"ZA","errorMessage":null},
      "countryName": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"","maxValue":"Vietnam","errorMessage":null},
      "deleted": {"type":"LONG","hasMultipleValues":false,"size":0,"cardinality":null,"minValue":null,"maxValue":null,"errorMessage":null},
      "delta": {"type":"LONG","hasMultipleValues":false,"size":0,"cardinality":null,"minValue":null,"maxValue":null,"errorMessage":null},
      "deltaBucket": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"-100.0","maxValue":"9900.0","errorMessage":null},
      "diffUrl": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"https://ar.wikipedia.org/w/index.php?diff=20310994&oldid=20310977","maxValue":"https://zh.wikipedia.org/w/index.php?title=Topic:T6oo8x0xa2kghw9d&action=history","errorMessage":null},
      "flags": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"","maxValue":"NB","errorMessage":null},
      "isAnonymous": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"false","maxValue":"true","errorMessage":null},
      "isMinor": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"false","maxValue":"true","errorMessage":null},
      "isNew": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"false","maxValue":"true","errorMessage":null},
      "isRobot": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"false","maxValue":"true","errorMessage":null},
      "isUnpatrolled": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"false","maxValue":"true","errorMessage":null},
      "metroCode": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"","maxValue":"866","errorMessage":null},
      "namespace": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"Aide","maxValue":"틀토론","errorMessage":null},
      "page": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"'t Suydevelt","maxValue":"황소자리 세타","errorMessage":null},
      "regionIsoCode": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"","maxValue":"ZP","errorMessage":null},
      "regionName": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"","maxValue":"Świętokrzyskie","errorMessage":null},
      "user": {"type":"STRING","hasMultipleValues":false,"size":0,"cardinality":0,"minValue":"*feridiák","maxValue":"ＫｏＺ","errorMessage":null},
      "user_unique": {"type":"hyperUnique","hasMultipleValues":false,"size":0,"cardinality":null,"minValue":null,"maxValue":null,"errorMessage":null}
    },
    "size":0,
    "numRows":24433,
    "aggregators": {
      "deleted": {"type":"longSum","name":"deleted","fieldName":"deleted"},
      "added": {"type":"longSum","name":"added","fieldName":"added"},
      "count": {"type":"longSum","name":"count","fieldName":"count"},
      "delta": {"type":"longSum","name":"delta","fieldName":"delta"},
      "user_unique": {"type":"hyperUnique","name":"user_unique","fieldName":"user_unique"}
    },
    "queryGranularity": {"type":"none"}
  }
]
EOT

eq_or_diff($druid_result_minus_id, $druid_expected_minus_id, 'druid query results are as expected');
