use Prometheus;
use UnitTest;
use Random;
use Time;

proc histogramTimer(test: borrowed Test) throws {
  var rs = new randomStream(real, seed=17);

  const numRuns = 1000;
  const minTimeMs = 1.0;
  const maxTimeMs = 10.0;

  Prometheus.start(metaMetrics=false, unitTest=true);

  const numBuckets = 20;
  const interval = (maxTimeMs-minTimeMs)/100;
  const buckets = [i in 0..#numBuckets] (minTimeMs+i*interval)/1000;
  var histTimer = new HistogramTimer("chpl_test_histtimer",
                                     desc="test histogram timer",
                                     buckets=buckets);

  for 0..#numRuns {
    manage histTimer {
      sleep(rs.next(minTimeMs/1000, maxTimeMs/1000));
    }
  }

  // TODO couldn't make multiline byte literals work with regex
  test.assertRegexMatch(Prometheus.getRegistry().collectMetrics().strip(),
      b'# HELP chpl_test_histtimer test histogram timer\n'+
      b'# TYPE chpl_test_histtimer histogram\n'+
      b'chpl_test_histtimer_bucket{le="0.001"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00109"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00118"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00127"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00136"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00145"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00154"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00163"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00172"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00181"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.0019"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00199"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00208"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00217"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00226"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00235"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00244"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00253"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00262"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="0.00271"} \\d+.0\n'+
      b'chpl_test_histtimer_bucket{le="\\+Inf"} 1000.0\n'+
      b'chpl_test_histtimer_sum 5.\\d+\n'+
      b'chpl_test_histtimer_count 1000.0'
  );

  Prometheus.stop();
}

UnitTest.main();
