use Prometheus;

use Time;

Prometheus.start();

var labeledGauge = new shared Gauge("test_metric",
                                    labelNames=["label1", "label2"]);

while true {
  var labelMap = ["label1"=>"foo", "label2"=>"bar"];
  writeln(labelMap);
  /*labeledGauge.labels(labelMap).inc();*/
  sleep(3);
}
