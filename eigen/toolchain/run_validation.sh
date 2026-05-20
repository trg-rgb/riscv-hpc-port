#!/bin/bash
# run_validation.sh
# Cross-compile and run Eigen 5.0.1 numerical validation for RISC-V64.
# Requires: riscv64-linux-gnu-gcc, cmake, qemu-riscv64
# Usage: bash toolchain/run_validation.sh
# Tanmay Gulhane — LFX Mentorship Summer 2026

set -e

EIGEN_DIR="$(pwd)/eigen"
BUILD_DIR="$(pwd)/build-riscv-validate"
SRC="$(pwd)/src/eigen_validate.cpp"
BINARY="$BUILD_DIR/eigen_validate"

echo "============================================================"
echo "  Eigen 5.0.1 RISC-V64 Validation — Build + Run"
echo "============================================================"

# Step 1: Clone Eigen if not present
if [ ! -d "$EIGEN_DIR" ]; then
    echo "[1/4] Cloning Eigen 5.0.1..."
    git clone --depth=1 https://gitlab.com/libeigen/eigen.git "$EIGEN_DIR"
else
    echo "[1/4] Eigen already cloned, skipping."
fi

# Step 2: Compile validation program
echo "[2/4] Cross-compiling for RV64GC..."
mkdir -p "$BUILD_DIR"
riscv64-linux-gnu-g++ \
    -O2 \
    -march=rv64gc \
    -static \
    -I"$EIGEN_DIR" \
    -o "$BINARY" \
    "$SRC"

echo "      Binary: $BINARY"
file "$BINARY"

# Step 3: Run under QEMU
echo "[3/4] Running under qemu-riscv64..."
echo ""
qemu-riscv64 "$BINARY"

# Step 4: Save results
echo ""
echo "[4/4] Saving results to results/eigen_validate_output.txt..."
mkdir -p results
qemu-riscv64 "$BINARY" > results/eigen_validate_output.txt 2>&1
echo "      Done."
echo ""
echo "To reproduce: bash toolchain/run_validation.sh"
