module Prometheus {

  use List, Map;
  use IO;
  use Time;

  class CollectorBase {
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

  class Collector: CollectorBase {
    var name: string;
    var value: real;
    var labels: map(string, string);

    proc init(name: string) {
      this.name = name;
    }

  }

  class Counter: Collector {

    proc init(name: string) { super.init(name); }

    inline proc inc(v: real) { value += v; }
    inline proc inc() { inc(1); }

    inline proc reset() { value = 0; }

    override proc collect() {
      return [new Sample(this.name, this.labels, this.value),];
    }
  }

  class Gauge: Collector {

    proc init(name: string) { super.init(name); }

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

  // TODO can't make this a class+context, so can't make it extend CollectorBase...
  class ManagedTimer: CollectorBase, contextManager {
    var context: string;

    var timer: stopwatch;
    var minGauge, maxGauge, totGauge: shared Gauge;
    var entryCounter: shared Counter;

    var collectors: list(shared Collector);

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


      collectors.pushBack(minGauge);
      collectors.pushBack(maxGauge);
      collectors.pushBack(totGauge);
      collectors.pushBack(entryCounter);
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

    override proc collect() {
      return [minGauge.collect()[0], maxGauge.collect()[0],
              totGauge.collect()[0], entryCounter.collect()[0]];

    }

    /*override iter collect() {*/
      /*try {*/
        /*for collector in collectors {*/
          /*for sample in collector.collect() {*/
            /*yield sample;*/
          /*}*/
        /*}*/
      /*}*/
      /*catch {*/
        /*halt("An iterator has thrown?");*/
      /*}*/
    /*}*/
  }


  class CollectorRegistry {

    var collectors: list(shared CollectorBase);

    proc collectMetrics() {
      var ret: bytes;

      try {
        var mem = openMemFile();
        var writer = mem.writer();
        var reader = mem.reader();

        for collector in collectors {
          /*for sample in collector.collect() {*/
          const sample = collector.collect();
            writeln(sample);
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

    proc register(c) {
      if !collectors.contains(c: shared CollectorBase) {
        collectors.pushBack(c);
      }
    }

    proc unregister(c) {
      if !collectors.contains(c: shared CollectorBase) {
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
