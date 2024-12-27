import Prometheus;

Prometheus.start();

/*var promServer = new Prometheus.metricServer();*/
/*promServer.start();*/

var managedTimer = new shared Prometheus.ManagedTimer(name="prometheus_latency");
var usedMemGauge = new shared Prometheus.UsedMemGauge();

while true {
  managedTimer.enterContext();
  var A, B, C: [1..100000] real;
  B = 1;
  C = 2;
  A = B + C;
  assert((+ reduce A) == A.size*3);
  managedTimer.exitContext();
}
