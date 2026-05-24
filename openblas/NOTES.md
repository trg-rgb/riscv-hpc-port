# OpenBLAS Investigation — Progression

This directory documents two builds of OpenBLAS for riscv64, in chronological order. Both are kept because the progression itself is part of the engineering story.

## `generic_scalar_build_may21/` — initial validation (May 21-22, 2026)

First cross-compile of OpenBLAS 0.3.33 for riscv64 using `TARGET=RISCV64_GENERIC`. DGEMM smoke test passed on a 2×2 identity matrix multiply under qemu-riscv64. The build was correct but, as later investigation revealed, scalar — `RISCV64_GENERIC` is intentionally non-vectorized by upstream design.

This work is preserved as a baseline. The DGEMM result is genuine; the library just doesn't use RVV instructions.

## `zvl128b_rvv_build/` — RVV investigation (May 23-24, 2026)

Triggered by [@Vaibhav805's Issue #23](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/23) on the LFX cluster challenge board, which raised the question of why RVV doesn't activate in default RISC-V cross-compilations.

Investigation found that OpenBLAS already ships `TARGET=RISCV64_ZVL128B` as the documented RVV-1.0 build target ([upstream Issue #3808](https://github.com/OpenMathLib/OpenBLAS/issues/3808), [README](https://github.com/OpenMathLib/OpenBLAS)). Using this target produces a fully vectorized build including L3 BLAS (DGEMM) with zero source patches.

Results:
- 14,355 RVV instructions across the library
- 75 RVV instructions inside `dgemm_kernel` (vectorized L3)
- 11/12 DGEMM correctness tests pass under Higham 2002 §3.5 eq. 3.13 error bounds
- 10/10 reproducibility on opcode count and QEMU result hashes

Full writeup and reproduction commands: see `zvl128b_rvv_build/README.md`.

## Why both are kept

The scalar build was honest work. The vectorized build is the result of deeper investigation. Showing the progression — including the limitation we didn't initially know about — is more rigorous than hiding the earlier baseline.
