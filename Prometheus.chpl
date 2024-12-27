module Prometheus {

  use List, Map;
  use IO;
  use Time;
  use Socket;
  use OS.POSIX;
  use MemDiagnostics;


  config const debugPrometheus = true;
  config const acceptTimeout = 20;

  private var registry: collectorRegistry;
  private var server: metricServer;
  private var started = false;

  proc start(host="127.0.0.1", port=8888:uint(16)) {
    server = new metricServer(host, port);
    server.start();
    started = true;
  }

  proc stop() {
    server.stop();
    started = false;
  }

  record metricServer {
    var host: string;
    var port: uint(16);

    var running: atomic bool = false;

    proc init() { }

    proc init(host:string, port:uint(16)) {
      this.host = host;
      this.port = port;
    }

    proc ref deinit() { this.stop(); }

    proc ref start() {
      // TODO wanted to catch this or throw. Neither is supported right now.
      this.running.write(true);
      begin with (ref this) { serve(); }
    }

    proc ref stop() {
      // TODO do we need to make sure that the server moves past accept()?
      running.write(false);
    }

    proc ref serve() {
      var listener: tcpListener;
      try! {
        listener = listen(ipAddr.create(host="127.0.0.1", port=port));
        writeln("created the listener");
      }
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
      }
    }
  }

  class Collector {
    var name: string;
    var value: real;
    var labels: map(string, string);
    var desc: string;
    var pType: string; // prometheus type for the generated metric

    proc init(name: string, const ref labels: map(string, string),
              desc: string, register: bool) {
      // TODO wanted to throw
      if !started then halt("Promotheus.start() hasn't been called yet");

      this.name = name;
      this.labels = labels;

      if desc=="" then
        this.desc = "No description provided for " + name;
      else
        this.desc = desc;
      init this;

      if register then registry.register(this);
    }

    // TODO : can't make this an iterator. Virtual dispatch with overridden
    // iterators doesn't work
    proc collect() throws {
      var dummyFlag = true;
      if dummyFlag {
        throw new Error("Abstract method called");
      }
      return [new Sample(),];
    }

  }

  class Counter: Collector {

    proc init(name: string, desc="", register=true) {
      var labels: map(string, string);
      super.init(name=name, labels=labels, desc=desc, register=register);
    }

    // TODO I shouldn't have needed this initializer?
    proc init(name: string, const ref labels: map(string, string),
              desc="", register=true) {
      super.init(name=name, labels=labels, desc=desc, register=register);
    }

    proc postinit() { this.pType = "counter"; }

    inline proc inc(v: real) { value += v; }
    inline proc inc() { inc(1); }

    inline proc reset() { value = 0; }

    override proc collect() throws {
      return [new Sample(this.name, this.labels, this.value,
                         this.desc, this.pType),];
    }
  }

  class Gauge: Collector {

    proc init(name: string, desc="", register=true) {
      var labels: map(string, string);
      super.init(name=name, labels=labels, desc=desc, register=register);
    }

    // TODO I shouldn't have needed this initializer?
    proc init(name: string, const ref labels: map(string, string),
              desc="", register=true) {
      super.init(name=name, labels=labels, desc=desc, register=register);

    }

    proc postinit() { this.pType = "gauge"; }

    inline proc inc(v: real) { value += v; }
    inline proc inc() { inc(1); }

    inline proc dec(v: real) { value -= v; }
    inline proc dec() { dec(1); }

    inline proc set(v: real) { value = v; }
    inline proc reset() { value = 0; }

    override proc collect() throws {
      return [new Sample(this.name, this.labels, this.value,
                         this.desc, this.pType),];
    }
  }

  // TODO can't make this a class+context, so can't make it extend Collector...
  class ManagedTimer: contextManager {
    var name: string;

    var timer: stopwatch;
    var minGauge, maxGauge, totGauge: shared Gauge;
    var entryCounter: shared Counter;

    proc init(name: string) {
      this.name = name;

      var labels: map(string, string);
      labels["context"] = name;

      this.minGauge = new shared Gauge("chpl_managedtimer_min", labels,
                                       desc="Min time for the context");
      this.maxGauge = new shared Gauge("chpl_managedtimer_max", labels,
                                       desc="Max time for the context");
      this.totGauge = new shared Gauge("chpl_managedtimer_tot", labels,
                                       desc="Total time for the context");
      this.entryCounter = new shared Counter("chpl_managedtimer_cnt", labels,
                                             desc="Number of entries");

      init this;
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

  class UsedMemGauge: Gauge {
    proc init(register=true) {
      var labels: map(string, string);
      super.init(name="chpl_mem_used", labels=labels,
                 desc="Amount of memory used in Locales[0] as reported by "+
                      "the Chapel runtime's memory tracking (--memTrack)",
                 register=register);
    }

    override proc collect() throws {
      this.value = memoryUsed();

      return super.collect();
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
            writer.writeln();
          /*}*/
        }
        writer.close();

        ret = reader.readAll(bytes);
        reader.close();

        mem.close();
      }
      catch e {
        writeln("An error occured while collecting metrics.");
        writeln(e.message());
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
    var desc: string;
    var pType: string;

    var timestamp = -1;

    proc serialize(writer: fileWriter(?), ref serializer) throws {
      writer.writef("# HELP %s %s\n", name, desc);
      writer.writef("# TYPE %s %s\n", name, pType);

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
