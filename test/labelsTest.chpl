use Prometheus;
use UnitTest;

proc gauge(test: borrowed Test) throws {
  Prometheus.start(metaMetrics=false, unitTest=true);

  var labeledGauge = new shared Gauge("chpl_test_gauge",
                                      labelNames=["label1", "label2"]);

  labeledGauge.labels(["label1"=>"foo", "label2"=>"bar"]).inc(1);
  labeledGauge.labels(["label1"=>"bar", "label2"=>"foo"]).inc(2);

  test.assertEqual(Prometheus.getRegistry().collectMetrics().strip(),
  b"""
    # HELP chpl_test_gauge No description provided for chpl_test_gauge
    # TYPE chpl_test_gauge gauge
    chpl_test_gauge{label2="bar",label1="foo"} 1.0
    # HELP chpl_test_gauge No description provided for chpl_test_gauge
    # TYPE chpl_test_gauge gauge
    chpl_test_gauge{label2="foo",label1="bar"} 2.0
  """.strip().dedent());

  Prometheus.stop();
}

UnitTest.main();
