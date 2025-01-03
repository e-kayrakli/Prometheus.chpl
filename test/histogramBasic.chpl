use Prometheus;
use UnitTest;
use IO;

proc basic(test: borrowed Test) throws {
  Prometheus.start(metaMetrics=false, unitTest=true);

  var h = new Histogram("chpl_test_histogram",
                        desc="test histogram",
                        buckets=[10,20,30]);

  var sum = 0;

  for data in 1..#50 {
    h.observe(data);
    sum += data;
  }

  const incVal = 25;
  for 0..#5 {
    h.observe(incVal);
    sum += incVal;
  }

  test.assertEqual(Prometheus.getRegistry().collectMetrics().strip(),
  b"""
    # HELP chpl_test_histogram test histogram
    # TYPE chpl_test_histogram histogram
    chpl_test_histogram_bucket{le="10.0"} 10.0
    chpl_test_histogram_bucket{le="20.0"} 20.0
    chpl_test_histogram_bucket{le="30.0"} 35.0
    chpl_test_histogram_bucket{le="+Inf"} 55.0
    chpl_test_histogram_sum 1400.0
    chpl_test_histogram_count 55.0
  """.strip().dedent());

  Prometheus.stop();
}

UnitTest.main();
