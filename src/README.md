# Source Layout

The source tree is organized by hardware and verification responsibility:

- `core/`: processor RTL that is the subject of core verification.
- `uncore/`: platform-component RTL, currently caches and an interrupt
  controller.
- `verification/`: formal verification environments. These files instantiate
  multiple hardware copies, implement PTCI behavior, and define the signals
  checked by the JasperGold experiment scripts.

The `-S` processor configurations reuse the corresponding base processor RTL:

- Sodor-S uses the Sodor core with an interrupt-masking verification top.
- SimpleOoO-S uses the SimpleOoO core with the Delay defense enabled by compile
  definitions and a PMP constraint in the experiment script.
