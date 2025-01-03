use Prometheus;

use Time;

Prometheus.start();

var labeledGauge = new shared Gauge("chpl_test_gauge",
                                    labelNames=["label1", "label2"]);
/*var labeledCounter = new shared Counter("chpl_test_counter",*/
                                    /*labelNames=["label1", "label2"]);*/

while true {
  labeledGauge.labels(["label1"=>"foo", "label2"=>"bar"]).inc();
  /*labeledCounter.labels(["label1"=>"baz", "label2"=>"bat"]).inc();*/
  sleep(3);
}
