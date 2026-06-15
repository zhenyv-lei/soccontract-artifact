# Source Layout

The source tree is organized by hardware and verification responsibility:

- `core/`: processor RTL that is the subject of core verification.
- `uncore/`: platform-component RTL, currently caches and an interrupt
  controller.
- `verification/`: formal verification miters. These files instantiate multiple
  hardware copies, implement PTCI behavior, and define the signals checked by
  the JasperGold experiment scripts. Miter files and their top-level modules use
  the `miter_<subject>_<contract-or-variant>` naming convention.

The current demonstration contains SimpleOoO core-side miters for C1 and C2,
Sodor core-side miters for C1, C2, and C4, uncore-side miters for C1, C2, and
C4, and direct full-system controls for C2 and C4. C3 miter support is a TODO.

SimpleOoO and SimpleOoO-S reuse the same RTL and miter files; their NoFwd and
Delay configurations are selected through JasperGold analyze-time macros.
Sodor and Sodor-S also reuse the same RTL and C4 miter, with the Sodor-S PMP
constraint applied in its JasperGold script.
