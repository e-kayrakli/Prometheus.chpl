use Prometheus;

Prometheus.start(metaMetrics=false);

var labeledGauge = new shared Gauge("chpl_test_gauge",
                                    labelNames=["label1", "label2"]);

labeledGauge.labels(["label1"=>"foo", "label2"=>"bar"]).inc(1);
labeledGauge.labels(["label1"=>"bar", "label2"=>"foo"]).inc(2);

writeln(Prometheus.getRegistry().collectMetrics());
