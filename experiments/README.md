# Experiments

This directory contains the JasperGold scripts used to reproduce the artifact
experiments. Run all scripts from the repository root.

## Core

The core experiments verify four processor configurations under the C3
platform timing contract. C3 models a platform where written data may affect
response timing and a memory-mapped interrupt.

| Script | Processor configuration | Expected result |
| --- | --- | --- |
| `core/sodor.tcl` | Baseline Sodor | Fail |
| `core/sodor_s.tcl` | Sodor-S with interrupt masking | Pass |
| `core/simpleooo.tcl` | SimpleOoO with NoFwd | Fail |
| `core/simpleooo_s.tcl` | SimpleOoO-S with Delay and PMP | Pass |

Run a core experiment with:

```sh
jg -batch -proj my_project experiments/core/sodor.tcl
```

## Uncore

The uncore experiments verify whether individual platform components comply
with the platform timing contracts expected by a core.

| Script | Component | Checks |
| --- | --- | --- |
| `uncore/regular_cache.tcl` | Regular cache | C2 passes; C1 fails. |
| `uncore/secure_cache.tcl` | Fixed-latency secure cache | C1 passes. |
| `uncore/interrupt_controller.tcl` | Memory-mapped interrupt controller | C2 fails; C3 permits the flow. |

Run an uncore experiment with:

```sh
jg -batch -proj my_project experiments/uncore/regular_cache.tcl
```

JasperGold project directories, databases, and raw terminal logs are generated
locally and intentionally excluded from version control.
