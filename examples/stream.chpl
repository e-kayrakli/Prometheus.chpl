use Prometheus;  // TODO using import causes interface errors from ctxManager
use Random;

config const port = 8888:uint(16);
proc main() {
  Prometheus.start(port=port);

  var histTimer = new shared Prometheus.HistogramTimer(name="chpl_stream_histtimer",
                                                       buckets=[0.001, 0.002]);
  // TODO this shows a potential leak?
  /*var usedMemGauge = new shared Prometheus.UsedMemGauge();*/

  var histogramTest = new shared Prometheus.Histogram(name="chpl_stream_result",
                                                      buckets=[i in 1..10] i/10.0);

  var rs = new randomStream(real);

  while true {
    manage histTimer {
      var A, B, C: [1..100000] real;
      B = rs.next(0, 1);
      C = rs.next(0, 1);
      A = B + C;
      histogramTest.observe(A[1]);
      assert((+ reduce A) > 0);
    }
  }
}
