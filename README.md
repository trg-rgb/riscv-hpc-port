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
![eigen](https://img.shields.io/badge/Eigen_5.0.1-3%2F3_tests_PASS-brightgreen)
![openblas](https://img.shields.io/badge/OpenBLAS_0.3.33-DGEMM_exact-brightgreen)
 
---
 
## What This Repo Contains
 
Cross-compilation and QEMU validation of HPC and numerical libraries for RISC-V, built as part of the LFX Mentorship 2026 application. All binaries are compiled on x86_64 and verified under `qemu-riscv64`.
 
| Library | Version | Status | Evidence |
|---|---|---|---|
| Numerical methods (Bisection, RK4, LU) | — | ✅ PASS | `numerical/results/` |
| Eigen | 5.0.1 | ✅ 3/3 tests PASS | `eigen/results/` |
| OpenBLAS | 0.3.33 | ✅ DGEMM exact | `openblas/results/` |
 
---
 
## Toolchain
 
| Component | Value |
|---|---|
| C/C++ cross-compiler | `riscv64-linux-gnu-gcc 15.2.0` |
| Fortran cross-compiler | `riscv64-linux-gnu-gfortran 15.2.0` |
| Target architecture | `RV64GC` |
| Emulator | `qemu-riscv64` |
| Host | Ubuntu WSL2 on x86_64 |
 
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
 
CMake cross-compiled using a RISC-V toolchain file. Three tests run under `qemu-riscv64`, 10 repetitions each.
 
```
cmake .. -DCMAKE_SYSTEM_NAME=Linux \
         -DCMAKE_SYSTEM_PROCESSOR=riscv64 \
         -DCMAKE_C_COMPILER=riscv64-linux-gnu-gcc \
         -DCMAKE_CXX_COMPILER=riscv64-linux-gnu-g++ \
         -DEIGEN_TEST_NOQT=ON
```
 
| Test | Repetitions | Result |
|---|---|---|
| `clz_3` | 10 | ✅ PASS |
| `basicstuff_1` | 10 | ✅ PASS |
| `basicstuff_2` | 10 | ✅ PASS |
 
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
 
## Repository Structure
 
```
riscv-hpc-port/
├── numerical/
│   ├── src/numerical_demo.c        # Bisection, RK4, LU — portable C, zero deps
│   └── results/numerical_demo_output.txt
├── eigen/
│   ├── src/eigen_validate.cpp      # Eigen test harness
│   ├── toolchain/
│   │   ├── riscv64-toolchain.cmake # CMake cross-compile toolchain file
│   │   ├── build_eigen.sh          # Full build script
│   │   └── run_validation.sh       # Run tests under qemu-riscv64
│   └── results/eigen_results.txt
├── openblas/
│   └── results/openblas_results.txt
├── coding-challenge/
│   └── tower_of_hanoi.py           # LFX coding challenge submission
└── toolchain/
    └── setup.sh                    # Toolchain installation script
```
 
---
 
## Related
 
- [LFX application issue #13](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/13) — 12-week implementation plan
- [LFX application issue #14](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues/14) — ML/AI porting subdirectory RFC
- [Groundnut leaf disease CNN](https://github.com/trg-rgb/Pretrained-CNN-with-6-class-image-classification) — Gold Medal, Sci Quest 2025
- [Deployed Hugging Face app](https://huggingface.co/spaces/tanmaytrg/Pretrained_CNN_6_class_image_classification)
