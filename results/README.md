# Curated Follow-up Experiments

This directory contains selected JasperGold entry scripts that complement the
primary experiments in `verification/`. Intermediate scripts, generated
parameter sweeps, GUI helpers, and superseded versions are intentionally not
included.

Run every script from the repository root:

```sh
jg -batch -proj my_project results/<group>/<script>.tcl
```

## Platform Compliance

| Script | Expected result | Purpose |
| --- | --- | --- |
| `platform/verify_cache_c2.tcl` | Pass | Regular cache complies with C2. |
| `platform/verify_cache_secure_c1.tcl` | Pass | Fixed-latency secure cache complies with C1. |
| `platform/verify_interrupt_controller_c3.tcl` | Pass | Interrupt controller complies with C3. |

## Sodor

| Script | Expected result | Purpose |
| --- | --- | --- |
| `sodor/verify_c3.tcl` | Fail | Secret store data can influence interrupts. |
| `sodor/verify_c3_pmp.tcl` | Pass | PMP-constrained Sodor satisfies C3. |
| `sodor/verify_c4_no_pmp.tcl` | Fail | Secret writes can reach the peripheral range. |
| `sodor/verify_c4_pmp.tcl` | Pass | PMP blocks secret writes to the peripheral range. |
| `sodor/verify_c4_combined_no_pmp.tcl` | Fail | Combined CPU and interrupt-controller check without PMP. |
| `sodor/verify_c4_combined_pmp.tcl` | Pass | Combined CPU and interrupt-controller check with PMP. |
| `sodor/verify_cache_regular.tcl` | Pass | Sodor remains secure with a regular cache. |

## SimpleOoO

| Script | Expected result | Purpose |
| --- | --- | --- |
| `simpleooo/verify_c1_nofwd.tcl` | Pass | NoFwd satisfies C1. |
| `simpleooo/verify_c1_delay.tcl` | Pass | Delay satisfies C1. |
| `simpleooo/verify_c2_nofwd.tcl` | Fail | NoFwd does not satisfy C2. |
| `simpleooo/verify_c2_delay.tcl` | Pass | Delay satisfies C2. |
| `simpleooo/verify_cache_regular_nofwd.tcl` | Fail | Regular-cache timing exposes NoFwd leakage. |
| `simpleooo/verify_cache_secure_nofwd.tcl` | Pass | Fixed-latency cache removes the NoFwd cache channel. |
| `simpleooo/verify_cache_secure_delay.tcl` | Pass | Delay combined with the secure cache passes. |

JasperGold project directories, databases, and raw terminal logs are generated
locally and intentionally excluded from version control.
