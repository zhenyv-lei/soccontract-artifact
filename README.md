# Platform Timing Contracts

Experimental artifact and follow-up experiments for:

> **Platform Timing Contracts: A Language and Instrumentation for Capturing SoC Timing Channels**

The paper is included as [`soccontracts.pdf`](soccontracts.pdf).

## Overview

Constant-time CPU verification is commonly performed on an isolated processor.
Its guarantees may become insufficient after the CPU is integrated with caches,
memory controllers, interrupt controllers, or other SoC components that create
additional timing channels.

Platform timing contracts describe the information flows that a platform is
allowed to feed back into a CPU. A synthesizable **Platform Timing Contract
Instrumentation (PTCI)** materializes these platform-induced flows so that
existing CPU verification methods can detect timing channels that would
otherwise remain outside their verification scope.

The paper makes three main contributions:

1. A language for expressing expected platform-induced timing channels.
2. A lightweight synthesizable PTCI compatible with existing CPU verification
   methods.
3. An evaluation showing that PTCI exposes platform-specific timing channels
   that isolated CPU verification can miss.

## Repository Scope

This cleaned repository contains the experiments that were actually conducted
in this codebase:

- **Sodor**, a 2-stage in-order RISC-V processor.
- **SimpleOoO**, a small out-of-order processor with NoFwd and Delay defenses.
- Platform models covering ideal memory, caches, and memory-mapped interrupt
  behavior.
- C1-C4 platform timing contract verification and PMP-based refinements.

The paper evaluates Sodor and Kronos. This repository instead retains Sodor and
the additional SimpleOoO experiments performed during the follow-up study. It
is therefore not a byte-for-byte copy of the paper's original artifact.

## Example Contracts

The contracts model increasingly permissive platform-induced flows:

| Contract | Platform behavior represented in this repository |
| --- | --- |
| C1 | Ideal memory with address-independent timing. |
| C2 | Cache-like behavior where memory addresses may affect response timing. |
| C3 | Data-dependent timing and interrupts, such as a memory-mapped interrupt controller. |
| C4 | C3 refined to a designated peripheral address range; PMP can prevent secret writes to that range. |

A processor verified under a contract is only secure when integrated with a
platform compatible with that contract.

## Main Results

The retained experiments demonstrate that stronger processor-side defenses are
required as the platform permits more feedback channels:

| Processor configuration | C1 | C2 | C3 |
| --- | --- | --- | --- |
| SimpleOoO NoFwd | Pass | Fail | Fail |
| SimpleOoO Delay | Pass | Pass | Fail |
| Sodor | Pass | Pass | Fail |
| Sodor with PMP constraint | Pass | Pass | Pass |

The C3 experiments show that secret-dependent stores can affect a
memory-mapped interrupt controller and create observable timing differences.
The PMP experiments show that preventing secret writes to the peripheral range
can remove this channel.

Detailed results and timings are documented in
[`docs/supplementary_experiments_2026-04-01.md`](docs/supplementary_experiments_2026-04-01.md).

## Repository Layout

- `src/sodor2/`: Sodor RTL, platform models, and PTCI verification tops.
- `src/simpleooo/`: SimpleOoO RTL, cache models, interrupt model, and PTCI
  verification tops.
- `verification/`: primary JasperGold verification entry scripts.
- `results/`: additional experiment-specific JasperGold TCL scripts.
- `docs/`: experiment results and repository maintenance notes.

## Requirements

Formal verification requires **Cadence JasperGold FPV**. JasperGold is
commercial software and is not distributed with this repository.

Run all commands from the repository root.

## Reproducing Representative Experiments

Sodor under C1 and C2:

```sh
jg -batch -proj my_proj_sodor_c1 verification/verify_2_copy_c1_sodor2.tcl
jg -batch -proj my_proj_sodor_c2 verification/verify_2_copy_c2_sodor2.tcl
```

SimpleOoO under C3:

```sh
jg -batch -proj my_proj_simpleooo_nofwd_c3 verification/verify_nofwd_ct_ptci_c3_simpleooo.tcl
jg -batch -proj my_proj_simpleooo_delay_c3 verification/verify_delay_ct_ptci_c3_simpleooo.tcl
```

Sodor C4 with and without the PMP constraint:

```sh
jg -batch -proj my_proj_sodor_c4_no_pmp results/veri_sodor_cpu_c4_no_pmp.tcl
jg -batch -proj my_proj_sodor_c4_pmp results/veri_sodor_cpu_c4_pmp.tcl
```

Generated JasperGold project directories, databases, and raw terminal logs are
intentionally excluded from version control.

## Code Provenance

The verification harness and processor models were initially derived from the
artifact for *RTL Verification for Secure Speculation Using Contract Shadow
Logic*. This repository repurposes and extends that infrastructure for platform
timing contract experiments. Shadow Logic is an implementation provenance, not
the subject of this repository.

See [`docs/REPOSITORY_CLEANUP.md`](docs/REPOSITORY_CLEANUP.md) for repository
scope and maintenance rules. See [`NOTICE.md`](NOTICE.md) for code provenance
and [`LICENSE`](LICENSE) for licensing terms.
