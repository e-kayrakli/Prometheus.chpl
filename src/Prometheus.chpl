module Prometheus {

  use List, Map;
  use IO;
  use Time;
  use Socket;
  use OS.POSIX;
  use MemDiagnostics;

  // TODO put this in a class/record definition and compilation fails
  extern proc printf(s...);

  private config const debugPrometheus = true;
  private config const acceptTimeout = 20;

  private var registry: collectorRegistry;
  private var server: metricServer;
  private var started = false;
  private var unitTest = false;

  proc start(host="127.0.0.1", port=8888:uint(16), metaMetrics=true,
             unitTest=false) {
    started = true;
    server = new metricServer(host, port, metaMetrics, unitTest);
    server.start();
  }

  proc stop() {
    server.stop();
    started = false;
  }

  proc getRegistry() const ref {
    return registry;
  }

  record metricServer {
    var host: string;
    var port: uint(16);

    var running: atomic bool = false;

    var responseGauge: shared Gauge?;

    var unitTest: bool;

    proc init() { }

    proc init(host:string, port:uint(16), metaMetrics: bool, unitTest: bool) {
      this.host = host;
      this.port = port;
      if metaMetrics then
        this.responseGauge = new shared Gauge("chpl_prometheus_response_time");
      else
        this.responseGauge = nil;

      this.unitTest = unitTest;
    }

    proc ref deinit() { this.stop(); }

    proc ref start() {
      import currentTask;
      // TODO wanted to catch this or throw. Neither is supported right now.
      begin with (ref this) { serve(); }
      while this.running.read() == false {
        currentTask.yieldExecution();
      }
    }

    proc ref stop() {
      // TODO do we need to make sure that the server moves past accept()?
      this.running.write(false);
    }


    proc ref serve() {
      if unitTest {
        this.running.write(true);
        return;
      }

      var t: stopwatch;

      try {
        if this.running.read() == true {
          throw new Error("The metricServer is already serving");
        }
        writeln("creating the listener", port);
        var listener = try! listen(ipAddr.create(host="127.0.0.1", port=port));

        this.running.write(true);

        while running.read() {
          if responseGauge != nil then responseGauge!.set(t.elapsed()*1000);
          t.clear();
          // TODO accept that takes a real argument is not working
          var comm = listener.accept(new struct_timeval(acceptTimeout, 0));

          t.start();
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

          // TODO I couldn't put \r in the end after the refactor. Why?
          param header = "HTTP/1.1 200 OK\n" +
            "Content-Length: %i\n" +
            "Content-Type: text/plain; version=0.0.4\n" +
            "\n";

          writer.writef(header, data.size);
          writer.write("\n");
          writer.write(data);
          writer.write("\n");

          writer.close();

          defer { t.stop(); }
        }
      }
      catch e {
        writeln("Error caught serving prometheus. Stopping server.");
        writeln(e.message());
        running.write(false);
      }
    }
  }

  enum relType { standalone, parent, child };

  class Collector {
    var name: string;
    var value: real;
    var desc: string;
    var pType: string; // prometheus type for the generated metric

    var labelNamesDom = {1..0};
    var labelNames: [labelNamesDom] string;
    /*var isParent: bool;*/
    var rel: relType;

    var labelMap: map(string, string);

    proc init(name: string, desc: string = "", register: bool = true) {
      // TODO wanted to throw
      if !started then halt("Promotheus.start() hasn't been called yet");

      this.name = name;
      if desc=="" then
        this.desc = "No description provided for " + name;
      else
        this.desc = desc;

      this.rel = if labelNames.size>0 then relType.parent
                                      else relType.standalone;

      init this;

      if register && this.rel!=relType.child then registry.register(this);
    }

    proc init(name: string, const ref labelNames: [] string, desc: string,
              register: bool) {
      // TODO wanted to throw
      if !started then halt("Promotheus.start() hasn't been called yet");

      this.name = name;

      if desc=="" then
        this.desc = "No description provided for " + name;
      else
        this.desc = desc;

      this.labelNamesDom = labelNames.domain;
      this.labelNames = labelNames;
      this.rel = if labelNames.size>0 then relType.parent
                                      else relType.standalone;

      init this;

      if register && this.rel!=relType.child then registry.register(this);
    }

    // TODO I have to add this ref, why?
    proc init(ref labelMap: map(string, string)) {
      this.name = "NO NAME -- CHILD";
      this.desc = "NO DESC -- CHILD";
      this.pType = "NO PTYPE -- CHILD";
      this.rel = relType.child;
      this.labelMap = labelMap;
    }


    // TODO : can't make this an iterator. Virtual dispatch with overridden
    // iterators doesn't work
    proc collect() throws {
      writeln("in Collector.collect rel ", this.rel);
      if this.rel==relType.parent {
        // TODO can't directly return this. got an internal compiler error
        var ret = [sample in childrenSamples()] new Sample(this.name,
                                                           sample.m,
                                                           sample.v,
                                                           this.desc,
                                                           this.pType);

        return ret;
      }
      else {
        throw new Error("Collector.collect can only be called with parent collectors");
      }
      return [new Sample(),];
    }

    proc generateBasicSample() {
      return [new Sample(this.name, this.labelMap, this.value,
                         this.desc, this.pType),];
    }

    // TODO these iterators needed to be ref. Why?
    iter childrenSamples() ref {
      writeln("in Collector.childrenSample");
      var dummy: partialSample;
      yield dummy;
      // TODO throw?
    }
  }

  class Counter: Collector {
    forwarding var children: labeledChildrenCache(shared Counter);

    // TODO I shouldn't have needed this initializer?
    proc init(ref labelMap: map(string, string)) { super.init(labelMap); }

    // TODO I shouldn't have needed this initializer?
    proc init(name: string, desc="", register=true) {
      super.init(name=name, desc=desc, register=register);
    }

    // TODO I shouldn't have needed this initializer?
    proc init(name: string, const ref labelNames: [] string, desc="",
              register=true) {
      super.init(name, labelNames, desc, register);
    }

    proc postinit() { this.pType = "counter"; }

    inline proc inc(v: real) { value += v; }
    inline proc inc() { inc(1); }

    inline proc reset() { value = 0; }

    override proc collect() throws {
      if this.rel==relType.parent {
        return super.collect();
      }
      else {
        return generateBasicSample();
      }
    }

    override iter childrenSamples() ref {
      for ps in children.partialSamples() do yield ps;
    }
  }

  class Gauge: Collector {
    forwarding var children: labeledChildrenCache(shared Gauge);

    // TODO I shouldn't have needed this initializer?
    proc init(ref labelMap: map(string, string)) {
      super.init(labelMap);
    }

    proc init(name: string, desc="", register=true) {
      super.init(name=name, desc=desc, register=register);
    }

    // TODO I shouldn't have needed this initializer?
    proc init(name: string, const ref labelNames: [] string, desc="",
              register=true) {
      super.init(name, labelNames, desc, register);
    }

    proc postinit() { this.pType = "gauge"; }

    inline proc inc(v: real) { value += v; }
    inline proc inc() { inc(1); }

    inline proc dec(v: real) { value -= v; }
    inline proc dec() { dec(1); }

    inline proc set(v: real) { value = v; }
    inline proc reset() { value = 0; }

    override proc collect() throws {
      writeln("in Gauge.collect rel ", this.rel);
      if this.rel==relType.parent then return super.collect();
      else return generateBasicSample();
    }

    override iter childrenSamples() ref {
      for ps in children.partialSamples() do yield ps;
    }
  }

  // per specs, we SHOULD make this a context manager, but class-based context
  // managers don't work
  class Histogram: Collector {
    var numBuckets = 0;
    var buckets: [0..#numBuckets] real;
    var counts: [buckets.domain] int;
    var allSum: real;
    var allCount: int;

    proc init(name: string, buckets: [], desc="", register=true) {
      super.init(name=name, desc=desc, register=register);
      this.numBuckets = buckets.size;
      this.buckets = buckets;

      init this;
    }

    proc init(name: string, buckets,  desc="", register=true)
        where !isArray(buckets) {

      const bucketsArr = buckets;
      init(name=name, buckets=bucketsArr, desc=desc, register=register);
    }

    proc postinit() { this.pType = "histogram"; }

    inline proc bucketName do return this.name+"_bucket";
    inline proc sumName do return this.name+"_sum";
    inline proc countName do return this.name+"_count";

    proc observe(v: real) {
      for (bucket, count) in zip(buckets, counts) {
        if v<=bucket then count += 1;
      }
      allSum += v;
      allCount += 1;
    }

    override proc collect() throws {
      var samples: [0..#counts.size+3] Sample; // +3 for +Inf, sum, and count
      const locBucketName = bucketName;
      var allLabels = labelMap;
      var firstDone = false;
      for (count, bucket, sample) in zip(counts, buckets,
                                         samples[buckets.domain]) {
        allLabels["le"] = bucket:string;

        if !firstDone {
          sample = new Sample(locBucketName, allLabels, count, this.desc,
                              this.pType, helpName=this.name);
          firstDone = true;
        }
        else {
          sample = new Sample(locBucketName, allLabels, count);
        }
      }

      // +Inf
      allLabels["le"] = "+Inf";
      samples[counts.size] = new Sample(locBucketName, allLabels, allCount);

      // sum
      samples[counts.size+1] = new Sample(sumName, labelMap, allSum);

      // count
      samples[counts.size+2] = new Sample(countName, labelMap, allCount);

      return samples;
    }
  }

  class HistogramTimer: Histogram, contextManager {
    type contextReturnType = nothing;
    var timer: stopwatch;

    proc init(name: string, buckets: [], desc="", register=true) {
      super.init(name, buckets, desc, register);
    }

    // TODO shouldn't these have ref this intent? I can't make that work with
    // context managers
    proc enterContext(): contextReturnType {
      timer.clear();
      timer.start();
    }

    proc exitContext(in err: owned Error?) {
      timer.stop();
      this.observe(timer.elapsed());
      timer.clear();
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

      var labelMap: map(string, string);
      labelMap["context"] = name;

      this.minGauge = new shared Gauge("chpl_managedtimer_min", labelMap,
                                       desc="Min time for the context");
      this.maxGauge = new shared Gauge("chpl_managedtimer_max", labelMap,
                                       desc="Max time for the context");
      this.totGauge = new shared Gauge("chpl_managedtimer_tot", labelMap,
                                       desc="Total time for the context");
      this.entryCounter = new shared Counter("chpl_managedtimer_cnt", labelMap,
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
    // to avoid reallocating/repopulatin at every collection
    var tmpMem: [LocaleSpace] uint;
    var samples: [LocaleSpace] Sample;
    var labelMaps: [LocaleSpace] map(string, string);

    proc init(register=true) {
      super.init(name="chpl_mem_used", labelNames=["locale",],
                 desc="Amount of memory used in each locale as reported by "+
                      "the Chapel runtime's memory tracking (--memTrack)",
                 register=register);

      init this;

      for loc in Locales {
        labelMaps[loc.id]["locale"] = loc.id:string;
      }
    }

    proc postinit() { this.pType = "gauge"; }

    // TODO I wanted to have these `compilerError`, but apparently we compile
    // them and can't use that in lieu of ` = delete` in CPP
    override proc inc(v: real) {writeln("Can't call UsedMemGauge.inc");}
    override proc inc()        {writeln("Can't call UsedMemGauge.inc");}

    override proc dec(v: real) {writeln("Can't call UsedMemGauge.dec");}
    override proc dec()        {writeln("Can't call UsedMemGauge.dec");}

    override proc set(v: real) {writeln("Can't call UsedMemGauge.set");}
    override proc reset()      {writeln("Can't call UsedMemGauge.reset");}

    override proc collect() throws {
      // collect numbers
      coforall loc in Locales do on loc {
        tmpMem[loc.id] = memoryUsed();
      }

      // create samples
      coforall (loc, labelMap, mem) in zip(Locales, labelMaps, tmpMem) {
        if loc.id == 0 {
          samples[loc.id] = new Sample(this.name, labelMap, mem,
                                       this.desc, this.pType);
        }
        else {
          samples[loc.id] = new Sample(this.name, labelMap, mem);
        }
      }

      return samples;
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

        // write to memory
        var writer = mem.writer();
        for collector in collectors {
          for sample in collector!.collect() {
            writer.write(sample);
          }
          writer.writeln();
        }
        writer.close();

        // read into a bytes
        var reader = mem.reader();
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
    var labelMap: map(string, string); // TODO this gets `ref` intent in the default
                                     // init, maybe it should be const ref?
    var value: real;
    var desc: string = "";
    var pType: string = "";

    var helpName: string = "";

    var timestamp = -1;

    proc serialize(writer: fileWriter(?), ref serializer) throws {
      const _helpName = if helpName.size>0 then helpName else name;

      if desc.size>0 then writer.writef("# HELP %s %s\n", _helpName, desc);
      if pType.size>0 then writer.writef("# TYPE %s %s\n", _helpName, pType);

      writer.write(name);
      if labelMap.size > 0 {
      /*if false {*/
        writer.write("{");
        var firstDone = false;
        /*for (key, value) in zip(labels.domain, labels) {*/
        for (key, value) in zip(labelMap.keys(), labelMap.values()) {
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

  record partialSample {
    var m: map(string, string);
    var v: real;
  }

  record labeledChildrenCache {
    type t;
    var cache: map(bytes, t);
  }

  iter labeledChildrenCache.these() ref {
    for child in cache.values() do yield child;
  }

  iter labeledChildrenCache.partialSamples() ref {
    // TODO can I yield the map by ref?
    for child in cache.values() {
      var sample = new partialSample(child.labelMap, child.value);
      yield sample;
    }
  }

  proc ref labeledChildrenCache.labels(ref l: map(string, string)) ref {
    const key = getBytesFromLabelMap(l);
    try! { // TODO handle properly
      if !cache.contains(key) {
        cache.add(key, new t(labelMap=l));
      }
      return cache[key];
    }
  }

  proc ref labeledChildrenCache.labels(l: []) ref { // TODO check for assoc.
    var m: map(string, string);
    for (key, value) in zip(l.domain, l) {
      m[key] = value;
    }
    return labels(m);
  }

  // helper for labeledChildrenCache
  private proc getBytesFromLabelMap(l) {
    // inefficient
    var ret: bytes;
    for value in l.values(){
      ret += value:bytes + b"XXX";
    }
    return ret;
  }
}
