# Experiments

This directory contains the JasperGold scripts for the C4 demonstration. Run
each script independently from the repository root.

## Core Verification

These experiments verify Sodor against the C4 platform timing contract without
instantiating a concrete platform.

| Script | Configuration | Expected result |
| --- | --- | --- |
| `core/sodor_c4.tcl` | Sodor without PMP constraint | Counterexample |
| `core/sodor_s_c4.tcl` | Sodor with PMP constraint | Proven |

## Uncore Verification

This experiment verifies that the address-decoded interrupt-controller platform
complies with C4.

| Script | Expected result |
| --- | --- |
| `uncore/interrupt_controller_c4.tcl` | Proven |

## Full-System Baseline

These control experiments directly verify the composed Sodor and interrupt
controller instead of using the contract-based decomposition.

| Script | Configuration | Historical result |
| --- | --- | --- |
| `system/sodor_interrupt_controller_c4.tcl` | Without PMP constraint | Timeout after 7 days |
| `system/sodor_s_interrupt_controller_c4.tcl` | With PMP constraint | Proven |

The full-system timeout is an expected control result demonstrating that direct
composition can be substantially harder to analyze. It does not imply that
every full-system verification attempt must time out.

C3 experiment support is planned but is not included in this demonstration.
