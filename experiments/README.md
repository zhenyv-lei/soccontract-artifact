# Experiments

This directory contains the JasperGold scripts for the C1, C2, and C4
demonstration. Run each script independently from the repository root.

## Core Verification

| Script | Contract/configuration | Expected result |
| --- | --- | --- |
| `core/simpleooo_c1.tcl` | SimpleOoO (NoFwd) under C1 | Proven |
| `core/simpleooo_s_c1.tcl` | SimpleOoO-S (Delay) under C1 | Proven |
| `core/simpleooo_c2.tcl` | SimpleOoO (NoFwd) under C2 | Counterexample |
| `core/simpleooo_s_c2.tcl` | SimpleOoO-S (Delay) under C2 | Proven |
| `core/sodor_c1.tcl` | Sodor under C1 | Proven |
| `core/sodor_c2.tcl` | Sodor under C2 | Proven |
| `core/sodor_c4.tcl` | Sodor under C4 without PMP | Counterexample |
| `core/sodor_s_c4.tcl` | Sodor under C4 with PMP | Proven |

## Uncore Verification

| Script | Contract/platform | Expected result |
| --- | --- | --- |
| `uncore/secure_cache_c1.tcl` | C1 fixed-latency cache | Proven |
| `uncore/regular_cache_c2.tcl` | C2 regular cache | Proven |
| `uncore/interrupt_controller_c4.tcl` | C4 address-decoded interrupt controller | Proven |

## Full-System Controls

| Script | Contract/configuration | Historical result |
| --- | --- | --- |
| `system/sodor_regular_cache_c2.tcl` | Sodor + regular cache under C2 | Proven |
| `system/sodor_interrupt_controller_c4.tcl` | C4 without PMP | Timeout after 7 days |
| `system/sodor_s_interrupt_controller_c4.tcl` | C4 with PMP | Proven |

The C4 full-system timeout is an expected control result demonstrating that
direct composition can be substantially harder to analyze. C3 experiment
support is planned but is not included in this demonstration.
