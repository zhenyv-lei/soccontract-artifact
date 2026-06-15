# Platform Timing Contracts

Demonstration artifact for:

> **Platform Timing Contracts: A Language and Instrumentation for Capturing SoC Timing Channels**

The paper is included as [`soccontracts.pdf`](soccontracts.pdf).

## Overview

Platform timing contracts summarize timing-relevant information flows between a
processor core and its surrounding platform. They enable a compositional
verification strategy:

```text
CPU_TCI(Ci) and Platform_TCI(Ci) imply Secure(Core + Platform)
```

The processor core and platform can therefore be verified independently against
the same contract. Direct full-system verification is retained as a control for
comparing verification effort.

## Demo Scope

This cleaned demonstration includes three platform timing contracts:

| Contract | Demonstrated platform behavior |
| --- | --- |
| C1 | Fixed-latency platform with address-independent timing. |
| C2 | Cache platform with address-dependent timing. |
| C4 | Conditional interrupt platform where write data may affect interrupts only within a peripheral address range. |

The repository contains three verification layers:

1. **Core verification:** verifies SimpleOoO against C1 and C2, and Sodor
   against C1, C2, and C4, using PTCI without instantiating a concrete
   platform.
2. **Uncore verification:** verifies representative platforms against C1, C2,
   and C4.
3. **Full-system verification:** directly composes Sodor with the C2 cache or
   C4 interrupt-controller platform as control experiments.

Support for the unconditional C3 contract is a **TODO** and is intentionally not
included in the current runnable experiments.

## Historical Results

Selected JasperGold results from the development repository:

| Verification object | Contract/configuration | Result | Time |
| --- | --- | --- | --- |
| Core | SimpleOoO under C1 | Proven | 652 s |
| Core | SimpleOoO-S under C1 | Proven | 207 s |
| Core | SimpleOoO under C2 | Counterexample | 32.91 s |
| Core | SimpleOoO-S under C2 | Proven | 8118 s |
| Core | Sodor under C1 | Proven | 4.82 s |
| Core | Sodor under C2 | Proven | 7.76 s |
| Core | Sodor under C4 without PMP | Counterexample | 0.44 s |
| Core | Sodor under C4 with PMP | Proven | 8.13 s |
| Full system | Sodor + regular cache under C2 | Proven | 25.30 s |
| Full system | Sodor + interrupt controller under C4, without PMP | Timeout | 604800.31 s |
| Full system | Sodor + interrupt controller under C4, with PMP | Proven | 1.70 s |

The seven-day C4 full-system timeout demonstrates that direct composition can
create a difficult verification problem. It does not imply that every
full-system verification attempt times out.

## Repository Layout

- `src/core/`: processor RTL.
- `src/uncore/`: platform-component RTL.
- `src/verification/core/`: core-side C1, C2, and C4 PTCI miters.
- `src/verification/uncore/`: platform-side C1, C2, and C4 compliance miters.
- `src/verification/system/`: direct C2 and C4 full-system control miters.
- `experiments/`: JasperGold scripts organized by verification layer.
- `results/`: concise summaries of historical results.

## Requirements

Formal verification requires **Cadence JasperGold FPV**. JasperGold is
commercial software and is not distributed with this repository.

Run all commands from the repository root. A counterexample or timeout may be
an expected experimental result.

## Running the Demo

Run SimpleOoO core-side verification:

```sh
jg -batch -proj my_proj_simpleooo_c1 experiments/core/simpleooo_c1.tcl
jg -batch -proj my_proj_simpleooo_s_c1 experiments/core/simpleooo_s_c1.tcl
jg -batch -proj my_proj_simpleooo_c2 experiments/core/simpleooo_c2.tcl
jg -batch -proj my_proj_simpleooo_s_c2 experiments/core/simpleooo_s_c2.tcl
```

Run Sodor core-side verification:

```sh
jg -batch -proj my_proj_sodor_c1 experiments/core/sodor_c1.tcl
jg -batch -proj my_proj_sodor_c2 experiments/core/sodor_c2.tcl
jg -batch -proj my_proj_sodor_c4 experiments/core/sodor_c4.tcl
jg -batch -proj my_proj_sodor_s_c4 experiments/core/sodor_s_c4.tcl
```

Run platform-side compliance verification:

```sh
jg -batch -proj my_proj_secure_cache_c1 experiments/uncore/secure_cache_c1.tcl
jg -batch -proj my_proj_regular_cache_c2 experiments/uncore/regular_cache_c2.tcl
jg -batch -proj my_proj_interrupt_controller_c4 experiments/uncore/interrupt_controller_c4.tcl
```

Run direct full-system controls:

```sh
jg -batch -proj my_proj_system_c2 experiments/system/sodor_regular_cache_c2.tcl
jg -batch -proj my_proj_system_c4 experiments/system/sodor_interrupt_controller_c4.tcl
jg -batch -proj my_proj_system_s_c4 experiments/system/sodor_s_interrupt_controller_c4.tcl
```

The configured time limits are upper bounds. Reproducing the historical C4
full-system timeout requires allowing the baseline control to run for seven
days.

See [`experiments/README.md`](experiments/README.md) for the expected result of
each script and [`results/README.md`](results/README.md) for the historical
comparison.

## Code Provenance

The verification harness and processor models were initially derived from the
artifact for *RTL Verification for Secure Speculation Using Contract Shadow
Logic*. This repository repurposes and extends that infrastructure for platform
timing contract experiments. Shadow Logic is implementation provenance, not
the subject of this repository.

See [`LICENSE`](LICENSE) for licensing terms.
