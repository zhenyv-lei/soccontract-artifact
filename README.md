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
- Core verification under C3 and uncore compliance checks for C1-C3.

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
| SimpleOoO with NoFwd | Pass | Fail | Fail |
| SimpleOoO-S with Delay and PMP | Pass | Pass | Pass |
| Sodor | Pass | Pass | Fail |
| Sodor-S with interrupt masking | Pass | Pass | Pass |

The C3 experiments show that secret-dependent stores can affect a
memory-mapped interrupt controller and create observable timing differences.
The secure variants show that interrupt masking or preventing secret writes to
the peripheral range can remove this channel.

## Repository Layout

- `src/sodor2/`: Sodor RTL, platform models, and PTCI verification tops.
- `src/simpleooo/`: SimpleOoO RTL, cache models, interrupt model, and PTCI
  verification tops.
- `experiments/core/`: C3 verification for the four processor configurations.
- `experiments/uncore/`: platform compliance checks for the uncore components.

## Requirements

Formal verification requires **Cadence JasperGold FPV**. JasperGold is
commercial software and is not distributed with this repository.

Run all commands from the repository root.

## Reproducing Experiments

Core verification under C3:

```sh
jg -batch -proj my_proj_sodor experiments/core/sodor.tcl
jg -batch -proj my_proj_sodor_s experiments/core/sodor_s.tcl
jg -batch -proj my_proj_simpleooo experiments/core/simpleooo.tcl
jg -batch -proj my_proj_simpleooo_s experiments/core/simpleooo_s.tcl
```

Uncore platform compliance:

```sh
jg -batch -proj my_proj_regular_cache experiments/uncore/regular_cache.tcl
jg -batch -proj my_proj_secure_cache experiments/uncore/secure_cache.tcl
jg -batch -proj my_proj_interrupt_controller experiments/uncore/interrupt_controller.tcl
```

See [`experiments/README.md`](experiments/README.md) for the purpose and
expected result of each script.

Generated JasperGold project directories, databases, and raw terminal logs are
intentionally excluded from version control.

## Code Provenance

The verification harness and processor models were initially derived from the
artifact for *RTL Verification for Secure Speculation Using Contract Shadow
Logic*. This repository repurposes and extends that infrastructure for platform
timing contract experiments. Shadow Logic is an implementation provenance, not
the subject of this repository.

See [`LICENSE`](LICENSE) for licensing terms.
