# Source Layout

The source tree is organized by hardware and verification responsibility:

- `core/`: processor RTL that is the subject of core verification.
- `uncore/`: platform-component RTL, currently caches and an interrupt
  controller.
- `verification/`: formal verification miters. These files instantiate multiple
  hardware copies, implement PTCI behavior, and define the signals checked by
  the JasperGold experiment scripts. Miter files and their top-level modules use
  the `miter_<subject>_<contract-or-variant>` naming convention.

The current demonstration contains core-side and uncore-side miters for C1, C2,
and C4, plus direct full-system controls for C2 and C4. C3 miter support is a
TODO.

All core experiments reuse the same Sodor RTL. The Sodor-S C4 experiment is
represented by the PMP constraint in its JasperGold script rather than by a
separate processor implementation.

The SimpleOoO RTL is retained as source provenance but is not part of the
current runnable demonstration.
