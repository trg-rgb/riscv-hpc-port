#!/bin/bash
# Eigen 5.0.1 RISC-V Cross-Compilation Script
# LFX 2026 - Broadening the RISC-V High Precision Code Base
# Author: Tanmay Gulhane, MIT-WPU Pune

set -e

echo "Cloning Eigen 5.0.1..."
git clone https://gitlab.com/libeigen/eigen.git
cd eigen
mkdir build-riscv && cd build-riscv

echo "Configuring for RISC-V..."
cmake .. \
  -DCMAKE_SYSTEM_NAME=Linux \
  -DCMAKE_SYSTEM_PROCESSOR=riscv64 \
  -DCMAKE_C_COMPILER=riscv64-linux-gnu-gcc \
  -DCMAKE_CXX_COMPILER=riscv64-linux-gnu-g++ \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DEIGEN_TEST_NOQT=ON

echo "Building and running tests..."
make clz_3 && qemu-riscv64 -L /usr/riscv64-linux-gnu test/clz_3
make basicstuff_1 && qemu-riscv64 -L /usr/riscv64-linux-gnu test/basicstuff_1
make basicstuff_2 && qemu-riscv64 -L /usr/riscv64-linux-gnu test/basicstuff_2

echo "All tests passed. Eigen verified on RISC-V."
