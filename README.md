# riscv-hpc-port
 
**RISC-V (riscv64) HPC porting portfolio** — cross-compilation, forensic RVV verification, and Debian packaging of scientific and HPC libraries.  
Tanmay Gulhane · MIT World Peace University, Pune
 
![arch](https://img.shields.io/badge/arch-riscv64-blue)
![gcc](https://img.shields.io/badge/gcc-15.2.0_cross-orange)
![qemu](https://img.shields.io/badge/qemu--riscv64-verified-purple)
![lammps](https://img.shields.io/badge/LAMMPS_30Mar26-zero_patches-brightgreen)
![openmm](https://img.shields.io/badge/OpenMM_8.5.0-12%2F12_tests-brightgreen)
![verify](https://img.shields.io/badge/verify--rvv--port-3%2F3_compliance-brightgreen)
![openblas](https://img.shields.io/badge/OpenBLAS_0.3.33-14355_RVV_opcodes-brightgreen)
![tflite](https://img.shields.io/badge/TF_Lite_v2.17.0-INT8_inference-brightgreen)
![hal](https://img.shields.io/badge/HAL_SIMD-4_backends_bit--identical-brightgreen)
![doom](https://img.shields.io/badge/Doom_3.0.0-riscv64-brightgreen)
![eigen](https://img.shields.io/badge/Eigen_5.0.1-42%2F42_PASS-brightgreen)
 
---
 
## What This Repo Contains
 
Cross-compilation, forensic verification, and packaging of HPC and scientific libraries for RISC-V. All RISC-V binaries are built on x86_64 with `riscv64-linux-gnu-gcc 15.2.0` and verified under `qemu-riscv64`; performance claims are explicitly deferred to hardware. The forensic methodology that emerged from this work is documented in the [closing statement (issue #32)](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/32).
 
### Core ports (forensic + plug-and-play)
 
| Project | Issue | Status |
|---|---|---|
| LAMMPS 30 Mar 2026 | [#30](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/30) | Zero upstream patches, 63,913 RVV opcodes, plug-and-play `.deb` (22 MB) with trajectory MP4/GIF visualizer |
| OpenMM 8.5.0 | [#29](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/29) | 4-hunk upstream-friendly patch, 14,425 RVV opcodes (861 in `CpuNonbondedForceFvec<fvec4>::calculateBlockIxn`), 12/12 platform tests PASS, plug-and-play `.deb` |
| TensorFlow Lite v2.17.0 (plug-and-play) | [#27](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/27) | INT8 CNN inference, packaged as `.deb` |
| f64 HAL SIMD shim | [#26](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/26) | 4 backends (RVV / AVX2+FMA / SSE2 / scalar), 20/20 bit-identical, 596 RVV opcodes in RVV binary |
| OpenBLAS 0.3.33 ZVL128B forensic | [#25](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/25) | 14,355 RVV opcodes, 75 in `dgemm_kernel`, 11/12 DGEMM under Higham 2002 §3.5 eq. 3.13 bounds |
| OpenMathLib/OpenBLAS upstream PR | [#5819](https://github.com/OpenMathLib/OpenBLAS/pull/5819) | Documentation surfacing the ZVL128B build target (under review) |
| Chocolate Doom 3.0.0 | [#20](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/20) | Full graphical UI, deterministic timedemo (gametics identical to x86) |
 
### Tooling
 
| Tool | Issue | Purpose |
|---|---|---|
| `verify-rvv-port.sh` | [#31](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/31) | 5-gate forensic verifier; 3-port compliance matrix (LAMMPS / OpenMM / OpenBLAS) reproducible in one command |
 
### Methodology and closing
 
The [closing statement (#32)](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/32) distills the methodology into five principles, walks the full portfolio arc, and frames Phase 2 future work.
 
### Earlier demonstrations
 
| Project | Result | Issue |
|---|---|---|
| Numerical methods (Bisection, RK4, LU) | All PASS (residuals 1e-10 or better) | local only |
| Eigen 5.0.1 | 42/42 tests PASS | local only |
| OpenBLAS 0.3.33 initial DGEMM | exact 2×2 multiply | superseded by [#25](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/25) |
| TensorFlow Lite v2.17.0 initial library | `libtensorflow-lite.a` built, inference on riscv64 | [#17](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/17), superseded by [#27](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/27) |
| ML/AI subdir RFC | architectural | [#14](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/14) |
| 12-week implementation plan | proposal | [#13](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/13) |
 
---
 
## Toolchain
 
| Component | Value |
|---|---|
| C/C++ cross-compiler | `riscv64-linux-gnu-gcc 15.2.0` |
| Fortran cross-compiler | `riscv64-linux-gnu-gfortran 15.2.0` |
| Target ISA | `rv64gcv_zba_zbb_zfh` (RVV 1.0, ZVL128B baseline) |
| ABI | `lp64d` (double-float) |
| Emulator | `qemu-riscv64 10.2.1` (user-mode), `qemu-system-riscv64` (full-system, for Doom) |
| CMake | 4.2.3 |
| Ninja | 1.13.2 |
| Host | Ubuntu 24.04 WSL2 on x86_64 (12 cores, 6.7 GB RAM) |
 
Reproduce the full toolchain setup: [`setup_toolchain.sh`](setup_toolchain.sh).
 
---
 
## verify-rvv-port.sh
 
A portfolio-wide forensic verification tool that applies five static gates to any `riscv64` ELF binary or relocatable object:
 
1. **Architecture** (ELF is UCB RISC-V)
2. **Total RVV opcode count** (catch catastrophic regressions)
3. **Arith/setup ratio** (detect silent scalar fallback, supports hand-asm signature)
4. **Backend selection canary** (confirm the intended backend compiled in)
5. **Hot-function attribution** (substring or exact match; supports `scalar` / `=N` / minimum assertions)
Three ports verified at writing time, all 5 gates PASS each:
 
```
| Port           | Arch | Total RVV    | Arith/Setup     | Backend Canary | Hot Fn       |
|----------------|------|--------------|-----------------|----------------|--------------|
| lammps         | PASS | PASS (64750) | PASS (10%)      | PASS (22748)   | PASS (=24)   |
| openmm-cpu     | PASS | PASS (7609)  | PASS (406%)     | PASS (607)     | PASS (=861)  |
| openblas-dgemm | PASS | PASS (91)    | PASS (asm:45)   | PASS (7)       | (no hot fn)  |
```
 
Reproduce on any host with `riscv64-linux-gnu-binutils` installed:
 
```bash
./scripts/verify-rvv-port.sh --table \
    ports/lammps.conf ports/openmm.conf ports/openblas.conf
```
 
Tool: [`scripts/verify-rvv-port.sh`](scripts/verify-rvv-port.sh)  
Per-port configs: [`ports/*.conf`](ports/)  
Full discussion: [issue #31](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/31)
 
---
 
## Core ports
 
### LAMMPS 30 Mar 2026
 
Issue: [#30](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/30)
 
Cross-compile of LAMMPS development tip (commit `7f680de`) to riscv64 with **zero upstream patches required**. Packages enabled: KSPACE, MOLECULE, RIGID, MANYBODY.
 
Key forensic numbers:
 
| Metric | Value |
|---|---|
| Upstream patches | 0 |
| Total RVV opcodes in `lmp` | 63,913 (re-measured at 64,750 with broader regex by `verify-rvv-port.sh`) |
| RVV in `PairLJCut::compute(int, int)` | 24 (SLP-vectorized epilogue, NOT inner neighbor-list loop) |
| RVV in `Neighbor::build`, `Verlet::run` | 0 (confirmed scalar) |
| RVV in `PPPM::compute` (long-range, exercised by peptide) | 46 |
| Peptide benchmark KSpace section | 25.01% of loop time |
| `.deb` size | 22 MB compressed, 125 MB installed |
| `.deb` SHA256 | `f97e82e6475d59f96899cd21dd5767e4bf3a616b4f896658ab59fa4ec3ba2ef6` |
 
Ships with `lammps-rvv-demo` (one-command end-to-end simulation + trajectory MP4/GIF) and `lammps-rvv-verify` (5-gate self-test).
 
Files: [`lammps-port/`](lammps-port/) · `.deb`: [`lammps-port/dist/`](lammps-port/dist/) · Visualization output: [`lammps-port/run-melt/melt.gif`](lammps-port/run-melt/melt.gif)
 
A correction was posted on #30 after `verify-rvv-port.sh` caught a previously-published "0" that was actually "24"; the corrected number is locked at `=24` in [`ports/lammps.conf`](ports/lammps.conf) so any future toolchain change that drifts it will fail the gate immediately.
 
---
 
### OpenMM 8.5.0
 
Issue: [#29](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/29)
 
Cross-compile of OpenMM 8.5.0 with a 4-hunk upstream-friendly patch (`TargetArch.cmake`, `CMakeLists.txt`, `hardware.h`, `Platform.cpp`). The `CpuNonbondedForceFvec<fvec4>` template specialization auto-vectorizes cleanly under GCC 15.2.
 
Key forensic numbers:
 
| Metric | Value |
|---|---|
| Patch size | 4 hunks, upstream-friendly |
| Total RVV opcodes in `libOpenMMCPU.so` | 7,609 |
| RVV in `CpuNonbondedForceFvec<fvec4>::calculateBlockIxn` | 861 |
| Arith/setup ratio | 406% (deeply vectorized inner kernel) |
| Indexed gathers (`vluxei*`/`vsuxei*`) library-wide | 61 |
| Platform tests | 12/12 PASS under qemu |
| `.deb` SHA256 (runtime) | `371ed1cc…` |
 
The 61 indexed-gather instructions are the smoking-gun signal that the inner loop is genuinely vectorized (vs. LAMMPS, which has zero). Distinguishes OpenMM from LAMMPS at the implementation level.
 
Files: [`openmm-port/`](openmm-port/) · Patch: [`openmm-port/openmm-riscv64-3patches.diff`](openmm-port/openmm-riscv64-3patches.diff)
 
A substantive community comment on #29 from @Ramrajnagar discusses extending this to a hand-written LMUL=4 e64,m4 path for better f64 throughput on K1/P550-class hardware. Phase 2 work; documented in the thread.
 
---
 
### TensorFlow Lite v2.17.0 (plug-and-play)
 
Issue: [#27](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/27)  
Initial library build: [#17](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/17)
 
The matured version of [#17](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/17)'s initial `libtensorflow-lite.a` build, packaged as a plug-and-play `.deb` with INT8 CNN inference on a real model (groundnut leaf disease, 6 classes, 59.9 MB INT8 quantized).
 
| Metric | Value |
|---|---|
| Library | `libtensorflow-lite.a` (21 MB, 243 objects, `elf64-littleriscv`) |
| Inference (qemu user-mode) | 781s avg, 100.7 MB memory footprint |
| XNNPACK / Ruy | Disabled (no riscv64 fast path on base RV64GC) |
| Model | `groundnut_cnn.tflite` (INT8 quantized, 59.9 MB) |
 
QEMU latency reflects instruction-level emulation, not hardware throughput.
 
Files: [`tflite/`](tflite/)
 
---
 
### f64 HAL SIMD shim
 
Issue: [#26](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/26)
 
A portable SIMD abstraction layer eliminating `#ifdef` chains at call sites. The core mechanism for porting x86 intrinsic-heavy HPC codes to RISC-V.
 
| Backend | Condition | Representative op |
|---|---|---|
| RISC-V RVV 1.0 (LMUL=4 f64) | `__riscv && __riscv_v` | `vfmacc_vv_f64m4`, `vle64_v_f64m4` |
| x86 AVX2 + FMA | `__AVX2__ && __FMA__` | `_mm256_fmadd_pd`, `_mm256_loadu_pd` |
| x86 SSE2 | `__SSE2__` | `_mm_mul_pd`, `_mm_add_pd` (4-wide via two `__m128d`) |
| Scalar | any ISA | plain C loops, bit-identical output |
 
20/20 bit-identical tests under qemu-riscv64 on the RVV backend, 596 RVV opcodes in the RVV binary, 0 in the scalar binary. Higher-level operations (`hal_dot4`, `hal_matvec_row`, `hal_axpy4`) build on the SIMD primitives and are directly usable in TF Lite dense-layer paths.
 
Files: [`hal/`](hal/) · Test harness: [`hal/test_hal.c`](hal/test_hal.c) · Results: [`hal/test_hal_results.txt`](hal/test_hal_results.txt)
 
---
 
### OpenBLAS 0.3.33 ZVL128B forensic
 
Issue: [#25](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/25)  
Upstream PR: [OpenMathLib/OpenBLAS#5819](https://github.com/OpenMathLib/OpenBLAS/pull/5819)
 
Full BLAS + CBLAS + LAPACK + LAPACKE built for `TARGET=RISCV64_ZVL128B` (the documented RVV-1.0 build target). The deeper forensic version of the earlier `RISCV64_GENERIC` build.
 
| Metric | Value |
|---|---|
| Total RVV instructions in library | 14,355 |
| RVV in `dgemm_kernel` | 75 (re-measured at 91 with broader regex by `verify-rvv-port.sh`) |
| DGEMM tests passing | 11/12 under Higham 2002 §3.5 eq. 3.13 bounds |
| Reproducibility | 10/10 identical opcode counts and QEMU result hashes |
| Hand-written assembly | Yes (`vsetivli` immediate-VL, not `vsetvli`) |
 
The single DGEMM test failure at N=8 is documented honestly in the issue rather than tuned away; it reflects the block-accumulation order in OpenBLAS's hand-asm kernel vs. the naive ijk reference, not a numerical bug.
 
Files: [`openblas/`](openblas/) · Build script: [`openblas/zvl128b_rvv_build/build_command.sh`](openblas/zvl128b_rvv_build/build_command.sh) · Reproduce: [`openblas/zvl128b_rvv_build/reproduce.sh`](openblas/zvl128b_rvv_build/reproduce.sh)
 
The OpenBLAS PR [#5819](https://github.com/OpenMathLib/OpenBLAS/pull/5819) surfaces the `RISCV64_ZVL128B` target in upstream documentation so future RISC-V cross-compilers don't end up at the silently-scalar `RISCV64_GENERIC` target by default.
 
---
 
### Chocolate Doom 3.0.0
 
Issue: [#20](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/20)
 
A well-known end-to-end test of whether real graphical software runs on a new architecture. Ported and running on riscv64 with full graphical UI under `qemu-system-riscv64`.
 
| Component | Value |
|---|---|
| Engine | Chocolate Doom 3.0.0 |
| WAD | `doom1.wad` (id Software shareware, Episode 1) |
| SDL2 | 2.30.0 (riscv64) |
| OS | Ubuntu 24.04.4 riscv64 |
| Emulator | `qemu-system-riscv64 10.2.1` (full machine emulation) |
 
**Timedemo result (demo3):**
 
| Metric | Value |
|---|---|
| Gametics rendered | 2134 (identical to x86 reference) |
| Realtics elapsed | 59393 |
| FPS (qemu-system) | 1.257556 |
| Expected FPS on hardware | ~35 (Doom's native target) |
 
FPS reflects full-machine emulation overhead. The 2134 gametics rendered deterministically and produce output identical to x86, confirming functional correctness.
 
Files: [`doom/`](doom/) · Timedemo log: [`doom/results/doom_timedemo_results.txt`](doom/results/doom_timedemo_results.txt)
 
---
 
## Earlier demonstrations
 
These earlier pieces demonstrate baseline cross-compilation and verification capability. They are retained for context; the forensic depth shifted into the core ports above.
 
### Numerical methods
 
Three foundational algorithms (Bisection, RK4, LU decomposition) ported to riscv64 and verified under qemu-riscv64. The numerical backbone of many HPC codes (PETSc, OpenFOAM, LAPACK-dependent codes).
 
| Algorithm | Result | Metric |
|---|---|---|
| Bisection root finder | PASS | Residual 1.40e-10 |
| Runge-Kutta 4th order ODE solver | PASS | Max error 4.90e-10 |
| LU decomposition (Doolittle) | PASS | Reconstruction residual 0.00e+00 |
 
Full output: [`numerical/results/numerical_demo_output.txt`](numerical/results/numerical_demo_output.txt)
 
### Eigen 5.0.1
 
CMake cross-compiled and run under qemu-riscv64, 42 tests, zero failures.
 
```bash
cmake .. -DCMAKE_SYSTEM_NAME=Linux \
         -DCMAKE_SYSTEM_PROCESSOR=riscv64 \
         -DCMAKE_C_COMPILER=riscv64-linux-gnu-gcc \
         -DCMAKE_CXX_COMPILER=riscv64-linux-gnu-g++ \
         -DEIGEN_TEST_NOQT=ON
QEMU_LD_PREFIX=/usr/riscv64-linux-gnu ctest
```
 
| Test group | Count | Result |
|---|---|---|
| `clz_1-4`, `rand_1-15`, `realview_1-12` | 31 | PASS |
| `basicstuff`, `meta`, `numext`, `dynalloc`, `nomalloc`, utility | 11 | PASS |
| **Total** | **42** | **42/42 PASS** |
 
Compiled binaries: [`eigen/bin/`](eigen/bin/) · Full output: [`eigen/results/eigen_results.txt`](eigen/results/eigen_results.txt)
 
---
 
## Methodology
 
The forensic methodology that emerged from this work is distilled in the [closing statement (#32)](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/32) as five principles:
 
1. **Function-scoped attribution over aggregate counts.** A binary with 64,750 RVV opcodes whose hot path has 24 is not the same as one with 7,609 RVV opcodes whose hot path has 861.
2. **Backend-selection verification.** Always confirm via a backend-specific opcode that the intended backend was compiled in.
3. **Arith/setup ratio as a silent-fallback detector.** Catches the GCC 13.x silent-scalar-emission pattern.
4. **QEMU exposes correctness bugs, not emulator artifacts.** Failed numerical tests under QEMU are source-level bugs, not reasons to defer to hardware.
5. **Document honestly when a number was wrong.** Silent edits hide the methodology working; posted corrections demonstrate it.
The verify tool encodes these principles as runnable gates; the per-port configs lock the documented numbers exactly so future regressions are visible.
 
---
 
## Repository Structure
 
```
riscv-hpc-port/
├── README.md                           # this file
├── setup_toolchain.sh                  # full cross-compilation environment
├── scripts/
│   └── verify-rvv-port.sh              # 5-gate forensic verifier (issue #31)
├── ports/
│   ├── lammps.conf                     # LAMMPS verification config
│   ├── openmm.conf                     # OpenMM CPU plugin verification config
│   └── openblas.conf                   # OpenBLAS dgemm_kernel verification config
├── lammps-port/                        # issue #30
│   ├── README.md
│   ├── lammps-phase1-bootstrap.sh
│   ├── lammps-phase1b-verify.sh
│   ├── riscv64-rvv-toolchain.cmake
│   ├── scripts/
│   │   ├── visualize_dump.py           # trajectory MP4/GIF renderer
│   │   └── package-deb.sh              # plug-and-play .deb builder
│   ├── dist/
│   │   └── lammps-riscv64-rvv_*.deb    # 22 MB compressed
│   ├── run-melt/
│   │   ├── in.melt                     # bundled example (dump enabled)
│   │   ├── dump.melt                   # reference trajectory
│   │   ├── melt.gif                    # visualization (1.2 MB)
│   │   └── melt.mp4                    # higher-quality (991 KB)
│   └── logs/
│       └── peptide/peptide.log         # 25.01% KSpace evidence
├── openmm-port/                        # issue #29
│   ├── openmm-phase1-bootstrap.sh
│   ├── openmm-phase1b-verify.sh
│   ├── openmm-riscv64-3patches.diff    # 4-hunk patch
│   ├── package-deb.sh
│   ├── phase1c-cputests.sh
│   ├── phase1d-plug-and-play-rebuild.sh
│   ├── riscv64-rvv-toolchain.cmake
│   ├── install-riscv64/                # built libraries + plugins
│   └── dist/
│       └── openmm-riscv64-rvv_*.deb
├── openblas/                           # issue #25
│   ├── NOTES.md                        # progression: scalar to ZVL128B-RVV
│   ├── generic_scalar_build_may21/     # initial scalar baseline
│   └── zvl128b_rvv_build/              # forensic RVV build
│       ├── build_command.sh
│       ├── reproduce.sh
│       ├── dgemm_validate.c            # Higham bounds test harness
│       ├── findings_summary.txt
│       └── ARTIFACT_LOCATION.md
├── tflite/                             # issues #17 (initial), #27 (.deb)
│   ├── toolchain/
│   ├── bin/benchmark_model
│   ├── groundnut_cnn.tflite            # INT8 quantized
│   └── results/
├── hal/                                # issue #26
│   ├── simd.h                          # SIMD abstraction (4 backends)
│   ├── test_hal.c                      # 20-case validation
│   ├── test_hal_riscv64_rvv            # 596 RVV opcodes
│   ├── test_hal_riscv64_scalar         # 0 RVV opcodes
│   └── test_hal_results*.txt
├── doom/                               # issue #20
│   ├── chocolate-doom                  # riscv64 ELF
│   └── results/                        # timedemo + screenshots
├── eigen/                              # earlier demonstration
│   ├── src/eigen_validate.cpp
│   ├── bin/                            # 42 riscv64 ELF test binaries
│   ├── toolchain/
│   └── results/eigen_results.txt
├── numerical/                          # earlier demonstration
│   ├── src/numerical_demo.c
│   └── results/numerical_demo_output.txt
└── coding-challenge/
    └── tower_of_hanoi.py
```
 
---
 
## Related issues and PRs
 
**Portfolio (chronological):**
 
- [#13](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/13): 12-week implementation plan and initial proposal
- [#14](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/14): ML/AI porting subdirectory structure RFC
- [#17](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/17): TensorFlow Lite v2.17.0 cross-compilation
- [#20](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/20): Chocolate Doom 3.0.0 on riscv64
- [#25](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/25): OpenBLAS 0.3.33 ZVL128B forensic + Higham bounds
- [#26](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/26): f64 HAL SIMD shim with 4 backends
- [#27](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/27): TensorFlow Lite v2.17.0 plug-and-play `.deb`
- [OpenMathLib/OpenBLAS#5819](https://github.com/OpenMathLib/OpenBLAS/pull/5819): upstream documentation PR
- [#29](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/29): OpenMM 8.5.0 with explicit RVV intrinsics
- [#30](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/30): LAMMPS 30 Mar 2026 with zero patches
- [#31](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/31): `verify-rvv-port.sh` tool and 3-port compliance matrix
- [#32](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/32): Closing statement and methodology distillation
**Background:**
 
- [Groundnut leaf disease CNN](https://github.com/trg-rgb/Pretrained-CNN-with-6-class-image-classification): Gold Medal, Sci Quest 2025
- [Hugging Face deployment](https://huggingface.co/spaces/tanmaytrg/Pretrained_CNN_6_class_image_classification): 6-class image classification
---
 
This work began as preparation for an LFX Mentorship 2026 application ([#13](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/13)) and has continued as an independent portfolio.
