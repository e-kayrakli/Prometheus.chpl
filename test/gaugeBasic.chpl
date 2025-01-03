use Prometheus;
use UnitTest;
use IO;

proc basic(test: borrowed Test) throws {
  const expectedFormat =
  b"""
    # HELP chpl_test_gauge No description provided for chpl_test_gauge
    # TYPE chpl_test_gauge gauge
    chpl_test_gauge %.1r
  """;

  proc check(val: real) {
    test.assertEqual(Prometheus.getRegistry().collectMetrics().strip(),
                     expectedFormat.format(val).strip().dedent());
  }

  Prometheus.start(metaMetrics=false);


  var g = new Gauge("chpl_test_gauge");

  check(0);
  g.inc();  check(1);
  g.inc(2); check(3);
  g.dec();  check(2);
  g.dec(3); check(-1);
  g.set(4); check(4);
  g.reset();
  check(0);
}

proc description(test: borrowed Test) throws {
  Prometheus.start(metaMetrics=false);

  const desc = "this is a test gauge";
  var g = new Gauge("chpl_test_gauge", desc=desc);
  g.inc();

  test.assertEqual(Prometheus.getRegistry().collectMetrics().strip(),
  b"""
    # HELP chpl_test_gauge %s
    # TYPE chpl_test_gauge gauge
    chpl_test_gauge 1.0
  """.format(desc).strip().dedent());
}

UnitTest.main();
