#!/usr/bin/env bash
# OpenBLAS 0.3.33 RVV build for RISC-V
# Target: RISCV64_ZVL128B (RVV 1.0, VLEN=128)
# Toolchain: riscv64-linux-gnu-gcc 15.2.0
# No source patches required.
#
# Author: trg-rgb (Tanmay Gulhane)
# Date:   2026-05-24

set -euo pipefail

# Clone if needed
if [ ! -d OpenBLAS ]; then
    git clone https://github.com/OpenMathLib/OpenBLAS.git
fi

cd OpenBLAS
git checkout v0.3.33

# Build
make CC=riscv64-linux-gnu-gcc \
     HOSTCC=gcc \
     TARGET=RISCV64_ZVL128B \
     BINARY=64 \
     NUM_THREADS=1 \
     NO_SHARED=1 \
     NOFORTRAN=1 \
     -j$(nproc)

# Verify the artifact exists
ls -la libopenblas_riscv64_zvl128b-r0.3.33.dev.a

echo "Build complete."
