# riscv-hpc-port

**LFX Mentorship 2026 — Broadening the RISC-V High Precision Code Base and Reach**  
**Applicant:** Tanmay Gulhane · MIT World Peace University, Pune  
**Mentor:** Kurt Keville (MIT)

![arch](https://img.shields.io/badge/arch-riscv64-blue)
![gcc](https://img.shields.io/badge/gcc-15.2.0_cross-orange)
![qemu](https://img.shields.io/badge/qemu--riscv64-verified-purple)
![bisection](https://img.shields.io/badge/bisection-PASS_1.40e--10-brightgreen)
![rk4](https://img.shields.io/badge/RK4-PASS_4.90e--10-brightgreen)
![lu](https://img.shields.io/badge/LU_residual-PASS_0.00e%2B00-brightgreen)
![eigen](https://img.shields.io/badge/Eigen_5.0.1-42%2F42_PASS-brightgreen)
![openblas](https://img.shields.io/badge/OpenBLAS_0.3.33-DGEMM_exact-brightgreen)
![tflite](https://img.shields.io/badge/TF_Lite_v2.17.0-inference_on_riscv64-brightgreen)
![hal](https://img.shields.io/badge/HAL_SIMD-20%2F20_PASS_riscv64-brightgreen)

---

## What This Repo Contains

Cross-compilation and QEMU validation of HPC and numerical libraries for RISC-V, built as part of the LFX Mentorship 2026 application. All binaries are compiled on x86_64 and verified under `qemu-riscv64`.

| Library | Version | Status | Evidence |
|---|---|---|---|
| Numerical methods (Bisection, RK4, LU) | — | ✅ PASS | `numerical/results/` |
| Eigen | 5.0.1 | ✅ 42/42 tests PASS | `eigen/results/` |
| OpenBLAS | 0.3.33 | ✅ DGEMM exact | `openblas/results/` |
| TensorFlow Lite | v2.17.0 | ✅ Inference running on riscv64 (groundnut CNN, 6-class) | `tflite/results/` |
| HAL SIMD Shim | — | ✅ 20/20 PASS on riscv64 (scalar/SSE2/AVX2/RVV) | `hal/` |

---

## Toolchain

| Component | Value |
|---|---|
| C/C++ cross-compiler | `riscv64-linux-gnu-gcc 15.2.0` |
| Fortran cross-compiler | `riscv64-linux-gnu-gfortran 15.2.0` |
| Target architecture | `RV64GC` (double-float ABI) |
| Emulator | `qemu-riscv64` |
| Host | Ubuntu WSL2 on x86_64 |

Reproduce the full toolchain setup: [`setup_toolchain.sh`](setup_toolchain.sh)

---

## Results

### Numerical Methods

Three foundational algorithms ported and verified — the numerical backbone of codes targeted by this program (PETSc, OpenFOAM, LAPACK-dependent codes).

| Algorithm | Result | Metric |
|---|---|---|
| Bisection root finder | ✅ PASS | Residual `1.40e-10` |
| Runge-Kutta 4th order ODE solver | ✅ PASS | Max error `4.90e-10` |
| LU decomposition (Doolittle) | ✅ PASS | Reconstruction residual `0.00e+00` |

Full output: [`numerical/results/numerical_demo_output.txt`](numerical/results/numerical_demo_output.txt)

---

### Eigen 5.0.1

CMake cross-compiled using a RISC-V toolchain file. 42 tests run under `qemu-riscv64`, zero failures.

```
cmake .. -DCMAKE_SYSTEM_NAME=Linux \
         -DCMAKE_SYSTEM_PROCESSOR=riscv64 \
         -DCMAKE_C_COMPILER=riscv64-linux-gnu-gcc \
         -DCMAKE_CXX_COMPILER=riscv64-linux-gnu-g++ \
         -DEIGEN_TEST_NOQT=ON

QEMU_LD_PREFIX=/usr/riscv64-linux-gnu ctest
```

| Test group | Count | What it covers | Result |
|---|---|---|---|
| `clz_1–4` | 4 | Count leading zeros, bit manipulation | ✅ PASS |
| `rand_1–15` | 15 | Random number generation and distribution | ✅ PASS |
| `realview_1–12` | 12 | Real-valued matrix views and operations | ✅ PASS |
| `basicstuff_1–2` | 2 | Core matrix arithmetic and assignment | ✅ PASS |
| `meta` | 1 | Template metaprogramming correctness | ✅ PASS |
| `numext` | 1 | Numerical extensions and special functions | ✅ PASS |
| `dynalloc` | 1 | Dynamic memory allocation | ✅ PASS |
| `nomalloc_1–3` | 3 | Zero-allocation matrix operations | ✅ PASS |
| `lru_cache`, `maxsizevector`, `sizeof` | 3 | Utility and memory layout | ✅ PASS |
| **Total** | **42** | | **42/42 PASS** |

Compiled riscv64 ELF binaries: [`eigen/bin/`](eigen/bin/)  
Full output: [`eigen/results/eigen_results.txt`](eigen/results/eigen_results.txt)  
Source: [`eigen/src/eigen_validate.cpp`](eigen/src/eigen_validate.cpp)  
Build scripts: [`eigen/toolchain/`](eigen/toolchain/)

---

### OpenBLAS 0.3.33

Full BLAS + CBLAS + LAPACK + LAPACKE built for `RISCV64_GENERIC`. DGEMM validation run under `qemu-riscv64`.

```
make CC=riscv64-linux-gnu-gcc \
     FC=riscv64-linux-gnu-gfortran \
     CROSS_SUFFIX=riscv64-linux-gnu- \
     TARGET=RISCV64_GENERIC \
     HOSTCC=gcc -j4
```

**DGEMM test — C = A × B (2×2 matrices):**

| Element | Result | Expected | Status |
|---|---|---|---|
| C[0][0] | 19.0 | 19.0 | ✅ PASS |
| C[0][1] | 22.0 | 22.0 | ✅ PASS |
| C[1][0] | 43.0 | 43.0 | ✅ PASS |
| C[1][1] | 50.0 | 50.0 | ✅ PASS |

Output: `libopenblas_riscv64_genericp-r0.3.33.dev.a` · Threading: multi-threaded (max 12 threads)

Full output: [`openblas/results/openblas_results.txt`](openblas/results/openblas_results.txt)

---

### TensorFlow Lite v2.17.0

Cross-compiled `libtensorflow-lite.a` for riscv64 and ran end-to-end inference of the groundnut leaf disease CNN — the only ML inference result in this applicant pool.

```
cmake ~/tensorflow-v2.17.0/tensorflow/lite \
  -DCMAKE_TOOLCHAIN_FILE=riscv64-toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DTFLITE_ENABLE_XNNPACK=OFF \
  -DTFLITE_ENABLE_RUY=OFF \
  -DBUILD_SHARED_LIBS=OFF
```

| Flag | Reason |
|---|---|
| `-DTFLITE_ENABLE_XNNPACK=OFF` | XNNPACK uses NEON/SSE2 intrinsics — not present on base RV64GC without the V extension |
| `-DTFLITE_ENABLE_RUY=OFF` | Ruy has no riscv64 fast path; same rationale |
| `-DBUILD_SHARED_LIBS=OFF` | Static library is self-contained — no dynamic linker path issues under QEMU |

**Library result:**

| Metric | Value |
|---|---|
| Output | `libtensorflow-lite.a` |
| Size | 21 MB |
| Object files in archive | 243 |
| Binary format | `elf64-littleriscv` |
| Architecture | `riscv:rv64` |

Verified with `riscv64-linux-gnu-objdump` and `riscv64-linux-gnu-nm` — real inference engine symbols compiled for riscv64, not stubs.

**Inference on riscv64 (qemu-riscv64):**

| Metric | Value |
|---|---|
| Model | `groundnut_cnn.tflite` (59.9MB, INT8 quantized) |
| Init time | 227ms |
| First inference | 797,720,987 µs (~798s) |
| Inference avg | 781,353,268 µs (~781s) |
| Memory footprint | 100.7MB |
| Note | QEMU user-mode emulation — latency reflects instruction-level simulation, not real hardware |

Full build log: [`tflite/results/tflite_build_results.txt`](tflite/results/tflite_build_results.txt)  
Benchmark log: [`tflite/results/benchmark_results.txt`](tflite/results/benchmark_results.txt)  
Library: [`tflite/results/libtensorflow-lite.a`](tflite/results/libtensorflow-lite.a)  
Toolchain file: [`tflite/toolchain/riscv64-toolchain.cmake`](tflite/toolchain/riscv64-toolchain.cmake)  
Benchmark tool: [`tflite/bin/benchmark_model`](tflite/bin/benchmark_model) — statically linked riscv64 ELF, runs under `qemu-riscv64` without sysroot dependency  
Model: [`tflite/groundnut_cnn.tflite`](tflite/groundnut_cnn.tflite)

---

### HAL SIMD Shim

Portable SIMD abstraction layer that eliminates `#ifdef` chains at call sites — the core mechanism for porting x86 intrinsic-heavy HPC codes to RISC-V.

| Backend | Condition | Key ops |
|---|---|---|
| RISC-V RVV 1.0 | `__riscv && __riscv_v` | `vfmacc_vv_f64m4`, `vle64_v_f64m4` |
| x86 AVX2 + FMA | `__AVX2__ && __FMA__` | `_mm256_fmadd_pd`, `_mm256_loadu_pd` |
| x86 SSE2 | `__SSE2__` | `_mm_mul_pd`, `_mm_add_pd` (4-wide via 2×`__m128d`) |
| Scalar | any ISA | Plain C loops — bit-identical output |

**Higher-level ops** built on the primitives — directly useful for TF Lite dense layer inference:
- `hal_dot4` — 4-element dot product
- `hal_matvec_row` — matrix row × vector (arbitrary length, SIMD + scalar tail)
- `hal_axpy4` — BLAS-1 AXPY: `y = alpha*x + y`

**Validated on riscv64:** 20/20 tests PASS under `qemu-riscv64` (scalar backend, base RV64GC). RVV path compiles with `-march=rv64gcv`.

Full results: [`hal/test_hal_results.txt`](hal/test_hal_results.txt)  
Header: [`hal/simd.h`](hal/simd.h)  
Test harness: [`hal/test_hal.c`](hal/test_hal.c)

---

## Repository Structure

```
riscv-hpc-port/
├── setup_toolchain.sh              # Reproduces full cross-compilation environment
├── numerical/
│   ├── src/numerical_demo.c        # Bisection, RK4, LU — portable C, zero deps
│   └── results/numerical_demo_output.txt
├── eigen/
│   ├── src/eigen_validate.cpp      # Eigen test harness
│   ├── bin/                        # Compiled riscv64 ELF test binaries
│   ├── toolchain/
│   │   ├── riscv64-toolchain.cmake
│   │   ├── build_eigen.sh
│   │   └── run_validation.sh
│   └── results/eigen_results.txt
├── openblas/
│   └── results/openblas_results.txt
├── tflite/
│   ├── toolchain/
│   │   └── riscv64-toolchain.cmake
│   ├── bin/
│   │   └── benchmark_model         # Statically linked riscv64 ELF
│   ├── groundnut_cnn.tflite        # INT8 quantized model (59.9MB)
│   └── results/
│       ├── libtensorflow-lite.a    # 21MB elf64-littleriscv static library
│       ├── tflite_build_results.txt
│       └── benchmark_results.txt  # Inference on riscv64 — 781s avg (QEMU)
├── hal/
│   ├── simd.h                      # Portable SIMD abstraction (scalar/SSE2/AVX2/RVV)
│   ├── test_hal.c                  # Validation harness — 20 test cases
│   ├── test_hal_riscv64            # Compiled riscv64 ELF (statically linked)
│   └── test_hal_results.txt        # QEMU output — 20/20 PASS
└── coding-challenge/
    └── tower_of_hanoi.py
```

---

## Related

- [LFX application issue #13](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/13) — 12-week implementation plan
- [LFX application issue #14](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/14) — ML/AI porting subdirectory RFC
- [LFX results issue #17](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/17) — TF Lite v2.17.0 cross-compilation and inference result
- [Groundnut leaf disease CNN](https://github.com/trg-rgb/Pretrained-CNN-with-6-class-image-classification) — Gold Medal, Sci Quest 2025
- [Deployed Hugging Face app](https://huggingface.co/spaces/tanmaytrg/Pretrained_CNN_6_class_image_classification)
