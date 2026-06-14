# Platform Timing Contracts

Demonstration artifact for:

> **Platform Timing Contracts: A Language and Instrumentation for Capturing SoC Timing Channels**

The paper is included as [`soccontracts.pdf`](soccontracts.pdf).

## Overview

Platform timing contracts summarize the timing-relevant information flows
between a processor core and its surrounding platform. They enable a
compositional verification strategy:

```text
CPU_TCI(C4) and Platform_TCI(C4) imply Secure(Core + Platform)
```

The processor core and platform can therefore be verified independently against
the same contract. A direct full-system verification is retained as a control
experiment for comparing verification effort.

## Demo Scope

This cleaned demonstration focuses on the conditional C4 contract and a Sodor
processor connected to a memory-mapped interrupt controller.

C4 permits write data to influence timing and interrupt behavior only when the
write address is within the designated peripheral range. The PMP-constrained
configuration prevents secret-dependent writes to that range.

The repository contains three verification layers:

1. **Core verification:** verifies Sodor against C4 using PTCI without a
   concrete platform implementation.
2. **Uncore verification:** verifies that the address-decoded interrupt
   controller complies with C4.
3. **Full-system verification:** directly composes Sodor and the interrupt
   controller as a control experiment.

Support for the unconditional C3 contract is a **TODO** and is intentionally not
included in the current runnable experiments.

## Demonstrated Results

Historical JasperGold runs from the development repository produced:

| Verification object | Configuration | Result | Time |
| --- | --- | --- | --- |
| Core under C4 | Sodor without PMP | Counterexample | 0.44 s |
| Core under C4 | Sodor with PMP | Proven | 8.13 s |
| Full system | Sodor + interrupt controller, without PMP | Timeout | 604800.31 s |
| Full system | Sodor + interrupt controller, with PMP | Proven | 1.70 s |

The seven-day full-system timeout demonstrates that direct composition can
create a difficult verification problem. It does not imply that every
full-system verification attempt times out.

## Repository Layout

- `src/core/`: processor RTL.
- `src/uncore/`: platform-component RTL.
- `src/verification/core/`: core-side C4 PTCI miter.
- `src/verification/uncore/`: platform-side C4 compliance miter.
- `src/verification/system/`: direct core-plus-uncore control miter.
- `experiments/core/`: core-side C4 JasperGold scripts.
- `experiments/uncore/`: platform-side C4 JasperGold script.
- `experiments/system/`: direct full-system control scripts.
- `results/`: concise summaries of historical results.

## Requirements

Formal verification requires **Cadence JasperGold FPV**. JasperGold is
commercial software and is not distributed with this repository.

Run all commands from the repository root. A counterexample or timeout may be
an expected experimental result.

## Running the Demo

Run the decomposed C4 verification:

```sh
jg -batch -proj my_proj_sodor_c4 experiments/core/sodor_c4.tcl
jg -batch -proj my_proj_sodor_s_c4 experiments/core/sodor_s_c4.tcl
jg -batch -proj my_proj_interrupt_controller_c4 experiments/uncore/interrupt_controller_c4.tcl
```

Run the direct full-system controls:

```sh
jg -batch -proj my_proj_system_c4 experiments/system/sodor_interrupt_controller_c4.tcl
jg -batch -proj my_proj_system_s_c4 experiments/system/sodor_s_interrupt_controller_c4.tcl
```

The configured time limits are upper bounds. In particular, reproducing the
historical full-system timeout requires allowing the baseline control to run
for seven days.

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
