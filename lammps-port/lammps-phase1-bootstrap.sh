#!/usr/bin/env bash
# lammps-phase1-bootstrap.sh
#
# LAMMPS riscv64 port (LFX Summer 2026, #25 standard).
# Idempotent — safe to re-run. NO PATCHES NEEDED — LAMMPS' core is arch-agnostic.
#
# Requires:
#   riscv64-linux-gnu-gcc, riscv64-linux-gnu-g++ (GCC 15.2.0 verified)
#   qemu-riscv64 (10.2.1 verified)
#   cmake (>= 3.20), ninja, git, python3
#
# Expects in this directory:
#   riscv64-rvv-toolchain.cmake        (the toolchain file from OpenMM)
#
# Phase 1A: clone, configure, build.
# Phase 1B (separate script): run melt example, RVV opcode forensics, .deb.

set -euo pipefail

# ---------- config ----------
WORK="${WORK:-$HOME/riscv-hpc-port/lammps-port}"
SRC_DIR="$WORK/lammps"
BUILD_DIR="$WORK/build-riscv64"
INSTALL_DIR="$WORK/install-riscv64"
LOG_DIR="$WORK/logs"
JOBS="${JOBS:-6}"
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$WORK" "$LOG_DIR"
cd "$WORK"

log() { printf '\n=== %s ===\n' "$*"; }

# ---------- 1. clone ----------
if [[ ! -d "$SRC_DIR/.git" ]]; then
    log "Cloning LAMMPS (shallow, no submodules)"
    git clone --depth=1 --no-recurse-submodules \
        https://github.com/lammps/lammps.git "$SRC_DIR"
else
    log "LAMMPS source already cloned — skipping"
fi

cd "$SRC_DIR"
COMMIT=$(git rev-parse --short HEAD)
VER=$(grep '#define LAMMPS_VERSION' src/version.h | cut -d'"' -f2)
log "LAMMPS commit: $COMMIT, version: \"$VER\""

# ---------- 2. configure ----------
TOOLCHAIN="$HERE/riscv64-rvv-toolchain.cmake"
[[ -f "$TOOLCHAIN" ]] || { echo "ERROR: toolchain file not found at $TOOLCHAIN"; exit 1; }

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd       "$BUILD_DIR"

log "Configuring CMake (riscv64, Release, no MPI, no OpenMP, basic packages minus GRAPHICS)"
cmake "$SRC_DIR/cmake" \
    -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DBUILD_MPI=OFF \
    -DBUILD_OMP=OFF \
    -DBUILD_TOOLS=OFF \
    -DBUILD_DOC=OFF \
    -DBUILD_LAMMPS_SHELL=OFF \
    -DPKG_KSPACE=ON \
    -DPKG_MANYBODY=ON \
    -DPKG_MOLECULE=ON \
    -DPKG_RIGID=ON \
    -DLAMMPS_EXCEPTIONS=ON \
    2>&1 | tee "$LOG_DIR/01-configure.log" | tail -25

# ---------- 3. build ----------
log "Building (ninja -j$JOBS)"
ninja -j"$JOBS" 2>&1 | tee "$LOG_DIR/02-build.log" | tail -15

# ---------- 4. inventory ----------
log "Built executables and libraries:"
find . -maxdepth 2 -type f \( -name "lmp" -o -name "*.so*" -o -name "liblammps*" \) | sort

log "Verify riscv64 ELF:"
file ./lmp 2>/dev/null || echo "  lmp binary not found at $(pwd)/lmp — investigate"

log "Phase 1A complete. Run lammps-phase1b-verify.sh next."
log "Logs: $LOG_DIR"
