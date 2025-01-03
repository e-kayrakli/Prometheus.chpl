use Prometheus;

Prometheus.start(metaMetrics=false);

var testGauge = new Gauge("chpl_test_gauge");
testGauge.inc();

writeln(Prometheus.getRegistry().collectMetrics());
