.. default-domain:: chpl

.. module:: Collectors

Collectors
==========
**Usage**

.. code-block:: chapel

   use Prometheus.Collectors;


or

.. code-block:: chapel

   import Prometheus.Collectors;

.. class:: Collector

   .. attribute:: var name: string

   .. attribute:: var value: real

   .. attribute:: var desc: string

   .. attribute:: var pType: string

   .. attribute:: var labelNamesDom = {1..0}

   .. attribute:: var labelNames: [labelNamesDom] string

   .. attribute:: var rel: relType

      var isParent: bool;

   .. attribute:: var labelMap: map(string, string)

   .. method:: proc init(name: string, desc: string = "", register: bool = true)

   .. method:: proc init(name: string, const ref labelNames: [] string, desc: string, register: bool)

   .. method:: proc init(ref labelMap: map(string, string))

   .. method:: proc collect() throws

   .. method:: proc generateBasicSample()

   .. itermethod:: iter childrenSamples() ref

.. class:: Counter : Collector

   .. method:: proc init(ref labelMap: map(string, string))

   .. method:: proc init(name: string, desc = "", register = true)

   .. method:: proc init(name: string, const ref labelNames: [] string, desc = "", register = true)

   .. method:: proc postinit()

   .. method:: proc inc(v: real)

   .. method:: proc inc()

   .. method:: proc reset()

   .. method:: override proc collect() throws

   .. itermethod:: override iter childrenSamples() ref

.. class:: Gauge : Collector

   .. method:: proc init(ref labelMap: map(string, string))

   .. method:: proc init(name: string, desc = "", register = true)

   .. method:: proc init(name: string, const ref labelNames: [] string, desc = "", register = true)

   .. method:: proc postinit()

   .. method:: proc inc(v: real)

   .. method:: proc inc()

   .. method:: proc dec(v: real)

   .. method:: proc dec()

   .. method:: proc set(v: real)

   .. method:: proc reset()

   .. method:: override proc collect() throws

   .. itermethod:: override iter childrenSamples() ref

.. class:: Histogram : Collector

   .. attribute:: var numBuckets = 0

   .. attribute:: var buckets: [0..#numBuckets] real

   .. attribute:: var counts: [buckets.domain] int

   .. attribute:: var allSum: real

   .. attribute:: var allCount: int

   .. method:: proc init(name: string, buckets: [], desc = "", register = true)

   .. method:: proc init(name: string, buckets, desc = "", register = true) where !isArray(buckets)

   .. method:: proc postinit()

   .. method:: proc bucketName

   .. method:: proc sumName

   .. method:: proc countName

   .. method:: proc observe(v: real)

   .. method:: override proc collect() throws

.. class:: HistogramTimer : Histogram, contextManager

   .. attribute:: type contextReturnType = nothing

   .. attribute:: var timer: stopwatch

   .. method:: proc init(name: string, buckets: [], desc = "", register = true)

   .. method:: proc enterContext(): contextReturnType

   .. method:: proc exitContext(in err: owned Error?)

.. class:: ManagedTimer : contextManager

   .. attribute:: var name: string

   .. attribute:: var timer: stopwatch

   .. attribute:: var minGauge: shared Gauge

   .. attribute:: var maxGauge: minGauge.type

   .. attribute:: var totGauge: maxGauge.type

   .. attribute:: var entryCounter: shared Counter

   .. method:: proc init(name: string)

   .. method:: proc ref enterContext()

   .. method:: proc ref exitContext()

.. class:: UsedMemGauge : Gauge

   .. method:: proc init(register = true)

      var labelMaps: [LocaleSpace] map(string, string);

   .. method:: proc postinit()

   .. method:: override proc inc(v: real)

   .. method:: override proc inc()

   .. method:: override proc dec(v: real)

   .. method:: override proc dec()

   .. method:: override proc set(v: real)

   .. method:: override proc reset()

   .. method:: override proc collect() throws

