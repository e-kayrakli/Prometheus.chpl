use Prometheus;
use UnitTest;
use IO;
use BlockDist;

config const localBytes = 100_000_000;

proc basic(test: borrowed Test) throws {
  test.skipIf(numLocales != 4);
  Prometheus.start(metaMetrics=false, unitTest=true);

  var g = new shared UsedMemGauge();

  var LocalArr: [1..localBytes] uint(8);

  test.assertEqual(Prometheus.getRegistry().collectMetrics().strip(),
  b"""
    # HELP chpl_mem_used Amount of memory used in each locale as reported by the Chapel runtime's memory tracking (--memTrack)
    # TYPE chpl_mem_used gauge
    chpl_mem_used{locale="0"} 1.00096e+08
    chpl_mem_used{locale="1"} 40.0
    chpl_mem_used{locale="2"} 40.0
    chpl_mem_used{locale="3"} 40.0
  """.strip().dedent());

  var DistArr = blockDist.createArray(1..localBytes, uint(8));

  test.assertEqual(Prometheus.getRegistry().collectMetrics().strip(),
  b"""
    # HELP chpl_mem_used Amount of memory used in each locale as reported by the Chapel runtime's memory tracking (--memTrack)
    # TYPE chpl_mem_used gauge
    chpl_mem_used{locale="0"} 1.2511e+08
    chpl_mem_used{locale="1"} 2.50022e+07
    chpl_mem_used{locale="2"} 2.50022e+07
    chpl_mem_used{locale="3"} 2.50022e+07
  """.strip().dedent());

  Prometheus.stop();
}

UnitTest.main();
