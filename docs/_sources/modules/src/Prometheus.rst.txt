.. default-domain:: chpl

.. module:: Prometheus
   :synopsis: This is a Prometheus API implementation in Chapel.

Prometheus
==========
**Usage**

.. code-block:: chapel

   use Prometheus;


or

.. code-block:: chapel

   import Prometheus;

**Submodules**

.. toctree::
   :maxdepth: 1
   :glob:

   Prometheus/*


This is a Prometheus API implementation in Chapel.


.. function:: proc start(host = "127.0.0.1", port = 8888: uint(16), metaMetrics = true, unitTest = false)

.. function:: proc stop()

.. function:: proc getRegistry() const ref

