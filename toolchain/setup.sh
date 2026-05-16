#!/bin/bash
# RISC-V Cross-Compilation Toolchain Setup
# LFX 2026 - Broadening the RISC-V High Precision Code Base
# Author: Tanmay Gulhane, MIT-WPU Pune

set -e

echo "Installing RISC-V cross-compiler and QEMU..."
sudo apt update
sudo apt install -y \
    gcc-riscv64-linux-gnu \
    g++-riscv64-linux-gnu \
    gfortran-riscv64-linux-gnu \
    qemu-user-binfmt \
    binutils-riscv64-linux-gnu

echo ""
echo "Verifying installation..."
riscv64-linux-gnu-gcc --version
qemu-riscv64 --version

echo ""
echo "Toolchain ready."
echo "Compile: riscv64-linux-gnu-gcc -O2 -march=rv64gc -static -o output input.c -lm"
echo "Run:     qemu-riscv64 output"
