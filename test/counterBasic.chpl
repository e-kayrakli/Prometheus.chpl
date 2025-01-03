use Prometheus;
use UnitTest;
use IO;

proc basic(test: borrowed Test) throws {
  const expectedFormat =
  b"""
    # HELP chpl_test_counter No description provided for chpl_test_counter
    # TYPE chpl_test_counter counter
    chpl_test_counter %.1r
  """;

  proc check(val: real) {
    test.assertEqual(Prometheus.getRegistry().collectMetrics().strip(),
                     expectedFormat.format(val).strip().dedent());
  }

  Prometheus.start(metaMetrics=false, unitTest=true);


  var g = new Counter("chpl_test_counter");

  check(0);
  g.inc();  check(1);
  g.inc(2); check(3);
  g.reset();
  check(0);

  Prometheus.stop();
}

proc description(test: borrowed Test) throws {
  Prometheus.start(metaMetrics=false, unitTest=true);

  const desc = "this is a test counter";
  var g = new Counter("chpl_test_counter", desc=desc);
  g.inc();

  test.assertEqual(Prometheus.getRegistry().collectMetrics().strip(),
  b"""
    # HELP chpl_test_counter %s
    # TYPE chpl_test_counter counter
    chpl_test_counter 1.0
  """.format(desc).strip().dedent());

  Prometheus.stop();
}

UnitTest.main();
