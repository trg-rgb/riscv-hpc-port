# riscv-hpc-port

<div align="center">

**LFX Mentorship 2026 — Broadening the RISC-V High Precision Code Base and Reach**

**Applicant:** Tanmay Gulhane · MIT World Peace University, Pune
**Mentor:** Kurt Keville (MIT)

![arch](https://img.shields.io/badge/arch-riscv64-blue)
![gcc](https://img.shields.io/badge/gcc-15.2.0_cross-orange)
![bisection](https://img.shields.io/badge/bisection-PASS_1.40e--10-brightgreen)
![rk4](https://img.shields.io/badge/RK4-PASS_4.90e--10-brightgreen)
![lu](https://img.shields.io/badge/LU_residual-PASS_0.00e+00-brightgreen)
![qemu](https://img.shields.io/badge/qemu--riscv64-verified-purple)

</div>

---

## What This Repo Proves

A working, verified cross-compilation pipeline built as part of the LFX 2026 application:

| Step | What happens | Evidence |
|------|-------------|---------|
| **1. Cross-compile** | x86 host to RV64GC binary via GCC 15.2.0 | `riscv64-linux-gnu-gcc -march=rv64gc` |
| **2. Execute** | Binary runs on emulated RISC-V CPU | `qemu-riscv64 numerical_demo` |
| **3. Verify** | Outputs match analytical solutions | `results/numerical_demo_output.txt` |

---

## Algorithms Ported

Three foundational algorithms from Numerical Recipes: The Art of Scientific Computing, the reference text for this LFX project. Implemented in portable C with zero external dependencies, verified correct on RISC-V.

### 1. Bisection Root Finder
- Target: f(x) = x^3 - x - 2
- Converges to root x = 1.5213797068 in 34 iterations
- Final residual: 1.40e-10

### 2. Runge-Kutta 4th Order ODE Solver
- Solves dy/dx = -y, y(0) = 1, exact solution y = e^(-x)
- Matches analytical solution to less than 5e-10 across domain [0, 2]
- 100 steps, step size h = 0.02

### 3. LU Decomposition (Doolittle Algorithm)
- 4x4 matrix decomposed as A = L x U
- Reconstruction residual: 0.00e+00 (exact)
- Foundation of LAPACK and linear algebra solvers targeted by this program

---

## Why These Algorithms

The LFX program targets porting HPC and AI/ML codes to RISC-V. These three are the numerical backbone of that entire category:

- **Bisection**: root finding underlies optimisation solvers throughout HPC codes like PETSc, SciPy, LAPACK
- **RK4**: ODE integration is core to OpenFOAM, LAMMPS, GROMACS
- **LU Decomposition**: matrix factorisation is the inner loop of every linear algebra-heavy code in the porting list

---

## Build and Run

```bash
# Install toolchain
sudo apt install gcc-riscv64-linux-gnu qemu-user-binfmt

# Cross-compile for RISC-V
make

# Run on emulated RISC-V
make run
```

---

## Verified Output

Full output saved in `results/numerical_demo_output.txt`

---

## Toolchain

| Component | Version |
|-----------|---------|
| Cross-compiler | GCC 15.2.0 riscv64-linux-gnu |
| Target architecture | RV64GC |
| Emulator | qemu-riscv64 |
| Host | Ubuntu 25.04 WSL2 on x86_64 |
| Optimisation | -O2 -march=rv64gc -static |
