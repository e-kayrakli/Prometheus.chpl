import Prometheus;
use Random;

Prometheus.start();

/*var promServer = new Prometheus.metricServer();*/
/*promServer.start();*/

var managedTimer = new shared Prometheus.ManagedTimer(name="prometheus_latency");
// TODO this shows a potential leak?
var usedMemGauge = new shared Prometheus.UsedMemGauge();


var histogramTest = new shared Prometheus.Histogram(name="histogram_test",
                                                    buckets=[i in 1..10] i/10.0);


var rs = new randomStream(real);

while true {
  managedTimer.enterContext();
  var A, B, C: [1..100000] real;
  B = rs.next();
  C = rs.next();
  A = B + C;
  histogramTest.observe(A[1]);
  assert((+ reduce A) > 0);
  managedTimer.exitContext();
}
