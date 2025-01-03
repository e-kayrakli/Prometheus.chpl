use Prometheus;

Prometheus.start(metaMetrics=false);

var testCounter = new Counter("chpl_test_counter");
testCounter.inc();

writeln(Prometheus.getRegistry().collectMetrics());
