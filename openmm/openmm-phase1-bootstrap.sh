#!/usr/bin/env bash
# openmm-phase1-bootstrap.sh
#
# Phase 1 of OpenMM 8.5.0 riscv64 port (LFX Summer 2026, #25 standard).
# Run from your work directory. Idempotent — safe to re-run.
#
# Requires in PATH:
#   riscv64-linux-gnu-gcc, riscv64-linux-gnu-g++ (GCC 15.2.0 verified)
#   qemu-riscv64 (10.2.1 verified)
#   cmake (>= 3.22), ninja, git, python3
#
# Expects in this directory:
#   openmm-riscv64-3patches.diff       (the 3-hunk patch)
#   riscv64-rvv-toolchain.cmake        (the toolchain file)
#
# Phase 1 deliverable: Reference + CPU platforms built, Reference tests
# passing under qemu-riscv64, CPU platform RVV opcode count from objdump.

set -euo pipefail

# ---------- config ----------
WORK="${WORK:-$HOME/riscv-hpc-port/openmm-port}"
SRC_DIR="$WORK/openmm"
BUILD_DIR="$WORK/build-riscv64"
INSTALL_DIR="$WORK/install-riscv64"
LOG_DIR="$WORK/logs"
OPENMM_TAG="${OPENMM_TAG:-8.5.0}"     # tip-of-main is 8.5.0 (commit f99249f)
JOBS="${JOBS:-6}"                      # keep headroom under 6.7GB RAM
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$WORK" "$LOG_DIR"
cd "$WORK"

log() { printf '\n=== %s ===\n' "$*"; }

# ---------- 1. clone source ----------
if [[ ! -d "$SRC_DIR/.git" ]]; then
    log "Cloning OpenMM (shallow, no submodules)"
    git clone --depth=1 --no-recurse-submodules \
        https://github.com/openmm/openmm.git "$SRC_DIR"
else
    log "OpenMM source already cloned at $SRC_DIR — skipping clone"
fi

cd "$SRC_DIR"
COMMIT=$(git rev-parse --short HEAD)
log "OpenMM commit: $COMMIT (expected f99249f for 8.5.0 tip)"

# ---------- 2. apply patches (idempotent) ----------
PATCH_FILE="$HERE/openmm-riscv64-3patches.diff"
[[ -f "$PATCH_FILE" ]] || { echo "ERROR: patch not found at $PATCH_FILE"; exit 1; }

# Skip if already applied (check for the riscv64 sentinel in TargetArch.cmake)
if grep -q '__riscv.*__riscv_xlen == 64' cmake_modules/TargetArch.cmake; then
    log "Patches already applied — skipping"
else
    log "Applying 3-hunk riscv64 patch"
    git apply --check "$PATCH_FILE"   # dry run first
    git apply        "$PATCH_FILE"
fi

# Verify all 3 hunks landed
grep -q 'RISCV64 ON'                       CMakeLists.txt                            || { echo "PATCH FAIL: CMakeLists.txt"; exit 1; }
grep -q 'cmake_ARCH riscv64'               cmake_modules/TargetArch.cmake            || { echo "PATCH FAIL: TargetArch"; exit 1; }
grep -q 'defined(__riscv)'                 openmmapi/include/openmm/internal/hardware.h || { echo "PATCH FAIL: hardware.h"; exit 1; }
log "Patches verified."

# ---------- 3. configure (Reference platform + CPU platform; no GPU) ----------
TOOLCHAIN="$HERE/riscv64-rvv-toolchain.cmake"
[[ -f "$TOOLCHAIN" ]] || { echo "ERROR: toolchain file not found"; exit 1; }

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd       "$BUILD_DIR"

log "Configuring CMake (riscv64, Release, CPU+Reference, no GPU, no Python)"
cmake "$SRC_DIR" \
    -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DOPENMM_BUILD_CUDA_LIB=OFF \
    -DOPENMM_BUILD_OPENCL_LIB=OFF \
    -DOPENMM_BUILD_HIP_LIB=OFF \
    -DOPENMM_BUILD_PYTHON_WRAPPERS=OFF \
    -DOPENMM_BUILD_C_AND_FORTRAN_WRAPPERS=OFF \
    -DOPENMM_BUILD_DRUDE_PLUGIN=ON \
    -DOPENMM_BUILD_RPMD_PLUGIN=ON \
    -DOPENMM_BUILD_AMOEBA_PLUGIN=ON \
    2>&1 | tee "$LOG_DIR/01-configure.log"

# Pull the resolved TARGET_ARCH out of the configure log — this is the
# fingerprint that the TargetArch patch worked.
log "TARGET_ARCH detection result:"
grep -E "TARGET_ARCH|Target Arch|riscv|RISCV" "$LOG_DIR/01-configure.log" | head -20 || true

# ---------- 4. build ----------
log "Building (ninja -j$JOBS) — Reference + CPU + plugins"
ninja -j"$JOBS" 2>&1 | tee "$LOG_DIR/02-build.log"

# ---------- 5. inventory the .so files ----------
log "Built libraries:"
find . -name "*.so*" -type f -not -path "*/CMakeFiles/*" | sort | tee "$LOG_DIR/03-libs.txt"

log "Phase 1 build complete. Next: run reference tests under qemu (script 02)."
log "Logs are in: $LOG_DIR"
