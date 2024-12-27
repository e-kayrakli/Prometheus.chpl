import Prometheus;

var promServer = new Prometheus.metricServer();
promServer.start();


/*var responseCounter = new shared Counter("chpl_prometheus_responses");*/
/*var latencyGauge = new shared Gauge("chpl_prometheus_response_latency");*/
var managedTimer = new shared Prometheus.ManagedTimer(context="prometheus_latency");


/*server.registry.register(responseCounter);*/
/*server.registry.register(latencyGauge);*/
/*Prometheus.registry.register(managedTimer);*/

/*use Time;*/

/*var s: stopwatch;*/

while true {
  managedTimer.enterContext();
  var A, B, C: [1..100000] real;
  B = 1;
  C = 2;
  A = B + C;
  assert((+ reduce A) == A.size*3);
  managedTimer.exitContext();
}


/*do {*/
  /*var server = listen(ipAddr.create(host="127.0.0.1", port=port));*/
  /*writeln("created server");*/
  /*writeln("waiting for connection");*/
  /*var client = server.accept();*/
  /*writeln("accepted connection");*/

  /*latencyGauge.set(s.elapsed());*/

  /*s.clear();*/
  /*s.start();*/

  /*managedTimer.enterContext();*/
    /*var socketFile = new file(client.socketFd);*/
    /*var socketReader = socketFile.reader();*/
    /*var socketWriter = socketFile.writer();*/

    /*const msg = socketReader.readThrough("\r\n\r\n");*/
    /*writeln(msg);*/


    /*responseCounter.inc();*/

    /*var data = registry.collectMetrics();*/

    /*writeln("Response:");*/
    /*writeln(data);*/

    /*socketWriter.write("HTTP/1.1 200 OK\r\n");*/
    /*socketWriter.writef("Content-Length: %i\r\n", data.size);*/
    /*[>socketWriter.write("Content-Encoding: snappy\r\n");<]*/
    /*[>socketWriter.write("Content-Type: application/x-protobuf\r\n");<]*/
    /*socketWriter.write("Content-Type: text/plain; version=0.0.4\r\n");*/
    /*[>socketWriter.write("User-Agent: Chapel application\r\n");<]*/
    /*[>socketWriter.write("X-Prometheus-Remote-Write-Version: 2.0.0\r\n");<]*/
    /*[>socketWriter.write("Content-Type: text/plain; charset=utf-8\r\n");<]*/
    /*socketWriter.write("\r\n");*/
    /*socketWriter.write(data);*/
    /*socketWriter.write("\r\n");*/

    /*socketWriter.close();*/
  /*managedTimer.exitContext();*/
  /*s.stop();*/



/*} while true;*/

/*proc null_write_callback(ptr: c_ptr(c_char), size: c_size_t, nmemb: c_size_t, userdata: c_ptr(void)) {*/
  /*return size * nmemb;*/
/*}*/
