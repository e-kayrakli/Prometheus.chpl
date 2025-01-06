use Prometheus;  // TODO using import causes interface errors from ctxManager
use Random;
use Time;

config const numElems = 250_000_000;
config const port = 8888:uint(16);
proc main() {
  Prometheus.start(port=port);

  var histTimer = new shared Prometheus.HistogramTimer(name="chpl_stream_histtimer",
                                                       buckets=[0.82,
                                                                0.84,
                                                                0.86,
                                                                0.88,
                                                                0.90,
                                                                0.92,
                                                                0.94,
                                                                0.96,
                                                                0.98,
                                                                1.00,
                                                                ]);
  // TODO this shows a potential leak?
  var usedMemGauge = new shared Prometheus.UsedMemGauge();

  var histogramTest = new shared Prometheus.Histogram(name="chpl_stream_result",
                                                      buckets=[i in 1..10] i/10.0);

  var bandwidthGauge = new shared Prometheus.Gauge(name="chpl_stream_bw");

  var rs = new randomStream(real);

  var t: stopwatch;

  const dataInBytes:real = numElems*numBytes(real)*3;

  var tempT: stopwatch;

  while true {
    manage histTimer {
      tempT.start();
      var A, B, C: [1..numElems] real;
      B = rs.next(0, 1);
      C = rs.next(0, 1);

      t.start();
      A = B + C;
      t.stop();
      const time = t.elapsed();
      t.clear();

      writeln(time);
      writeln(dataInBytes/2**30);
      writeln((dataInBytes/2**30)/time);
      bandwidthGauge.set((dataInBytes/2**30)/time);

      histogramTest.observe(A[1]);
      assert((+ reduce A) > 0);
      tempT.stop();
      writeln("tempT: ", tempT.elapsed());
      tempT.clear();
    }
  }
}
