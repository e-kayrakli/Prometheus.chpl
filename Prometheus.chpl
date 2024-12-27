module Prometheus {

  use List, Map;
  use IO;
  use Time;
  use Socket;
  use OS.POSIX;

  config const debugPrometheus = true;
  config const acceptTimeout = 20;
  config const port: uint(16) = 8888;

  var registry: collectorRegistry;

  record metricServer {
    var listener: tcpListener;
    var running: atomic bool;

    proc init() {
      // TODO wanted to catch this or throw. Neither is supported right now.
      try! {
        this.listener = listen(ipAddr.create(host="127.0.0.1", port=port));
        writeln("created the listener");
      }
    }

    proc ref deinit() {
      stop();
    }

    proc ref start() {
      this.running.write(true);
      begin with (ref this) { serve(); }
    }

    proc ref stop() {
      // TODO do we need to make sure that the server moves past accept()?
      running.write(false);
    }

    proc ref serve() {
      while running.read() {
        try {
          // TODO accept that takes a real argument is not working
          var comm = listener.accept(new struct_timeval(acceptTimeout, 0));
          var socketFile = new file(comm.socketFd);
          var writer = socketFile.writer();

          if debugPrometheus {
            var reader = socketFile.reader();
            const msg = reader.readThrough("\r\n\r\n");
            writeln(msg);
          }

          // TODO check for the message and confirm it is from prometheus

          var data = registry.collectMetrics();

          if debugPrometheus {
            writeln("Response:");
            writeln(data);
          }

          writer.write("HTTP/1.1 200 OK\r\n");
          writer.writef("Content-Length: %i\r\n", data.size);
          writer.write("Content-Type: text/plain; version=0.0.4\r\n");
          writer.write("\r\n");
          writer.write(data);
          writer.write("\r\n");

          writer.close();
        }
        catch e {
          writeln("Error caught serving prometheus. Stopping server.");
          writeln(e.message());
          running.write(false);
        }
        // for debugging only
        running.write(false);
      }
    }
  }

  class Collector {
    var name: string;
    var value: real;
    var labels: map(string, string);

    proc init(name: string, register) {
      this.name = name;
      init this;

      if register then registry.register(this);
    }

    // TODO : can't make this an iterator. Virtual dispatch with overridden
    // iterators doesn't work
    proc collect() {
      writeln("here");
      /*var dummyFlag = true;*/
      /*if dummyFlag {*/
        /*throw new Error("Abstract method called");*/
      /*}*/
      return [new Sample(),];
    }

  }

  class Counter: Collector {

    proc init(name: string, register=true) { super.init(name, register); }

    inline proc inc(v: real) { value += v; }
    inline proc inc() { inc(1); }

    inline proc reset() { value = 0; }

    override proc collect() {
      return [new Sample(this.name, this.labels, this.value),];
    }
  }

  class Gauge: Collector {

    proc init(name: string, register=true) { super.init(name, register); }

    inline proc inc(v: real) { value += v; }
    inline proc inc() { inc(1); }

    inline proc dec(v: real) { value -= v; }
    inline proc dec() { dec(1); }

    inline proc set(v: real) { value = v; }
    inline proc reset() { value = 0; }

    override proc collect() {
      return [new Sample(this.name, this.labels, this.value),];
    }
  }

  // TODO can't make this a class+context, so can't make it extend Collector...
  class ManagedTimer: contextManager {
    var context: string;

    var timer: stopwatch;
    var minGauge, maxGauge, totGauge: shared Gauge;
    var entryCounter: shared Counter;

    proc init(context: string) {
      this.context = context;

      this.minGauge = new shared Gauge("chpl_managedtimer_min");
      this.maxGauge = new shared Gauge("chpl_managedtimer_max");
      this.totGauge = new shared Gauge("chpl_managedtimer_tot");
      this.entryCounter = new shared Counter("chpl_managedtimer_cnt");

      init this;

      this.minGauge.labels["context"] = context;
      this.maxGauge.labels["context"] = context;
      this.totGauge.labels["context"] = context;
      this.entryCounter.labels["context"] = context;
    }

    // this is a mock context manager for the time being
    proc ref enterContext() {
      timer.clear();
      timer.start();
      return this;
    }

    proc ref exitContext() {
      timer.stop();
      const elapsed = timer.elapsed();
      timer.clear();

      if elapsed < minGauge.value then minGauge.set(elapsed);
      if elapsed > maxGauge.value then maxGauge.set(elapsed);

      totGauge.inc(elapsed);
      entryCounter.inc();
    }
  }


  record collectorRegistry {

    // TODO I want to add `this` from the Collector initializer. That makes me
    // tied to `borrowed`, whereas I feel like I need `shared` here.
    var collectors: list(borrowed Collector);

    proc collectMetrics() {
      var ret: bytes;

      try {
        var mem = openMemFile();
        var writer = mem.writer();
        var reader = mem.reader();

        for collector in collectors {
          /*for sample in collector.collect() {*/
          const sample = collector.collect();
            /*writeln(sample);*/
            writer.write(sample);
          /*}*/
        }
        writer.close();

        ret = reader.readAll(bytes);
        reader.close();

        mem.close();
      }
      catch {
        writeln("An error occured while collecting metrics.");
      }

      return ret;
    }

    proc ref register(c) {
      if !collectors.contains(c: Collector) {
        collectors.pushBack(c);
      }
    }

    proc unregister(c) {
      if !collectors.contains(c: Collector) {
        collectors.remove(c);
      }
    }
  }

  record Sample: writeSerializable {
    var name: string;
    var labels: map(string, string);
    var value: real;
    var timestamp = -1;


    proc serialize(writer: fileWriter(?), ref serializer) throws {
      writer.write(name);

      if labels.size > 0 {
        writer.write("{");
        var firstDone = false;
        for (key, value) in zip(labels.keys(), labels.values()) {
          if firstDone {
            writer.write(",");
          }
          else {
            firstDone = true;
          }
          writer.write(key,"=", "\"", value, "\"");
        }

        writer.write("}");
      }
      writer.write(" ");
      writer.write(value);

      if timestamp > 0 {
        writer.write(" ", timestamp);
      }

      writer.write("\n");
    }
  }
}
