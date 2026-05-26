#!/usr/bin/env bash
# package-deb.sh — Build a plug-and-play .deb for LAMMPS riscv64 with RVV.
#
# v2 (2026-05-27):
#   * Strip binary (eliminates E: unstripped-binary-or-object)
#   * Drop ldconfig maintainer scripts (we ship no .so)
#   * Exclude .gitignore from potentials dir
#   * Replace head -30 with awk to avoid SIGPIPE under set -o pipefail
#   * Bundle modified in.melt with dump command enabled so the demo
#     command actually produces a trajectory
#
# Produces a single .deb that includes:
#   * lmp riscv64 binary + auto-discover-potentials wrapper
#   * liblammps.a for downstream linking
#   * 261 force-field potential files
#   * Demo melt input (with dump enabled) + trajectory visualization script
#   * Demo command (lammps-rvv-demo) — runs sim + generates GIF/MP4
#   * Self-test command (lammps-rvv-verify) — 5-gate forensic check
#
# Verifies the .deb with three independent methods:
#   1. dpkg-deb -I / -c (Debian metadata + contents)
#   2. lintian (Debian-policy linter)
#   3. qemu-riscv64 extraction + run test (binary actually works)
#
# Usage:
#   ./package-deb.sh                  # default version 30Mar26-1
#   ./package-deb.sh 30Mar26-2        # custom revision

set -euo pipefail

# ============================================================
# Paths
# ============================================================
PROJECT_ROOT="${PROJECT_ROOT:-$HOME/riscv-hpc-port/lammps-port}"
BUILD_DIR="$PROJECT_ROOT/build-riscv64"
LAMMPS_SRC="$PROJECT_ROOT/lammps"
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
DIST_DIR="$PROJECT_ROOT/dist"

LMP_BIN="$BUILD_DIR/lmp"
LMP_LIB="$BUILD_DIR/liblammps.a"
POTENTIALS_DIR="$LAMMPS_SRC/potentials"
MELT_INPUT="$LAMMPS_SRC/examples/melt/in.melt"
VIZ_SCRIPT="$SCRIPTS_DIR/visualize_dump.py"

PKG_NAME="lammps-riscv64-rvv"
PKG_VERSION="${1:-30Mar26-1}"
PKG_ARCH="riscv64"
PKG_BASENAME="${PKG_NAME}_${PKG_VERSION}_${PKG_ARCH}"

STAGE="/tmp/${PKG_BASENAME}"
DEB_OUT="$DIST_DIR/${PKG_BASENAME}.deb"

STRIP="${STRIP:-riscv64-linux-gnu-strip}"

# ============================================================
# Preflight
# ============================================================
echo "=== Preflight ==="
for f in "$LMP_BIN" "$LMP_LIB" "$MELT_INPUT" "$VIZ_SCRIPT"; do
    [ -e "$f" ] || { echo "✗ Missing required file: $f"; exit 1; }
done
[ -d "$POTENTIALS_DIR" ] || { echo "✗ Missing potentials dir: $POTENTIALS_DIR"; exit 1; }

for cmd in dpkg-deb fakeroot file "$STRIP"; do
    command -v "$cmd" >/dev/null || { echo "✗ Missing tool: $cmd"; exit 1; }
done

# Confirm binary is actually riscv64
if ! file "$LMP_BIN" | grep -q "UCB RISC-V"; then
    echo "✗ $LMP_BIN is not a RISC-V binary; aborting"
    exit 1
fi

mkdir -p "$DIST_DIR"
echo "  ✓ All inputs present"
echo "  ✓ Binary architecture: RISC-V"
echo

# ============================================================
# Stage directory tree
# ============================================================
echo "=== Staging directory tree at $STAGE ==="
rm -rf "$STAGE"
mkdir -p \
    "$STAGE/DEBIAN" \
    "$STAGE/usr/bin" \
    "$STAGE/usr/libexec/lammps" \
    "$STAGE/usr/lib/riscv64-linux-gnu" \
    "$STAGE/usr/share/lammps/potentials" \
    "$STAGE/usr/share/lammps/examples/melt" \
    "$STAGE/usr/share/lammps/scripts" \
    "$STAGE/usr/share/doc/$PKG_NAME" \
    "$STAGE/usr/share/man/man1"

# Real binary lives in /usr/libexec/lammps (Debian convention for
# "internal" binaries not directly user-invoked).
install -m 0755 "$LMP_BIN" "$STAGE/usr/libexec/lammps/lmp"
install -m 0644 "$LMP_LIB" "$STAGE/usr/lib/riscv64-linux-gnu/liblammps.a"
install -m 0755 "$VIZ_SCRIPT" "$STAGE/usr/share/lammps/scripts/visualize_dump.py"

# Strip binary — eliminates E: unstripped-binary-or-object. RVV opcode
# count is unchanged (strip removes symbols/debuginfo, not code).
echo "  Stripping binary..."
SIZE_PRE=$(stat -c %s "$STAGE/usr/libexec/lammps/lmp")
"$STRIP" --strip-unneeded "$STAGE/usr/libexec/lammps/lmp"
SIZE_POST=$(stat -c %s "$STAGE/usr/libexec/lammps/lmp")
echo "  ✓ Binary: $((SIZE_PRE/1024)) KB → $((SIZE_POST/1024)) KB"

# ============================================================
# Bundle a *modified* in.melt with dump enabled.
# Upstream comments out the dump line; for a self-contained demo
# command we need the trajectory to actually be written.
# ============================================================
cat > "$STAGE/usr/share/lammps/examples/melt/in.melt" << 'EOF'
# 3d Lennard-Jones melt
# Modified from upstream LAMMPS examples/melt/in.melt:
#   * dump command enabled (every 25 timesteps → 11 frames for 250-step run)
#   * Original (with dump commented) is at examples/melt/in.melt in the
#     LAMMPS source tree at https://github.com/lammps/lammps
units           lj
atom_style      atomic
lattice         fcc 0.8442
region          box block 0 10 0 10 0 10
create_box      1 box
create_atoms    1 box
mass            1 1.0
velocity        all create 3.0 87287 loop geom
pair_style      lj/cut 2.5
pair_coeff      1 1 1.0 1.0 2.5
neighbor        0.3 bin
neigh_modify    every 20 delay 0 check no
fix             1 all nve
dump            1 all atom 25 dump.melt
thermo          50
run             250
EOF
chmod 0644 "$STAGE/usr/share/lammps/examples/melt/in.melt"

echo "  Copying potentials (this is the bulk, ~56 MB)..."
cp -r "$POTENTIALS_DIR/." "$STAGE/usr/share/lammps/potentials/"
# Drop VCS control files lintian flags
find "$STAGE/usr/share/lammps/potentials/" -name '.gitignore' -delete
chmod 0644 "$STAGE/usr/share/lammps/potentials/"*  2>/dev/null || true
echo "  ✓ $(ls "$STAGE/usr/share/lammps/potentials/" | wc -l) potential files installed"

# ============================================================
# /usr/bin/lmp wrapper: auto-exports LAMMPS_POTENTIALS, exec real binary
# ============================================================
cat > "$STAGE/usr/bin/lmp" << 'EOF'
#!/bin/bash
# lmp wrapper — auto-discovers bundled potentials directory.
# Override LAMMPS_POTENTIALS in env to use a different path.
export LAMMPS_POTENTIALS="${LAMMPS_POTENTIALS:-/usr/share/lammps/potentials}"
exec /usr/libexec/lammps/lmp "$@"
EOF
chmod 0755 "$STAGE/usr/bin/lmp"

ln -sf lmp "$STAGE/usr/bin/lammps"

# ============================================================
# /usr/bin/lammps-rvv-demo: end-to-end demo with viz
# ============================================================
cat > "$STAGE/usr/bin/lammps-rvv-demo" << 'EOF'
#!/bin/bash
# lammps-rvv-demo — run the bundled LJ melt example end-to-end and
# generate a trajectory MP4 + GIF. Outputs land in $OUTDIR (default
# ~/lammps-demo-output).
set -euo pipefail

OUTDIR="${OUTDIR:-$HOME/lammps-demo-output}"
WORKDIR=$(mktemp -d)
trap "rm -rf $WORKDIR" EXIT

mkdir -p "$OUTDIR"
cp /usr/share/lammps/examples/melt/in.melt "$WORKDIR/"
cd "$WORKDIR"

echo "[1/3] Running LAMMPS melt example (4000 atoms, 250 timesteps)..."
echo "      (~10 s on native riscv64 hardware; longer under emulation)"
lmp -in in.melt -log "$OUTDIR/melt.lammps.log"

if [ ! -f dump.melt ]; then
    echo "✗ No trajectory dump produced; check $OUTDIR/melt.lammps.log"
    exit 1
fi

FRAMES=$(grep -c "ITEM: TIMESTEP" dump.melt)
echo "      ✓ Simulation complete, $FRAMES trajectory frames"

cp dump.melt "$OUTDIR/dump.melt"

if ! command -v python3 >/dev/null || \
   ! python3 -c "import numpy, matplotlib" 2>/dev/null || \
   ! command -v ffmpeg >/dev/null; then
    echo "[2/3] Visualization deps missing; install with:"
    echo "      sudo apt install python3-numpy python3-matplotlib ffmpeg"
    echo "      Then re-run:"
    echo "      python3 /usr/share/lammps/scripts/visualize_dump.py $OUTDIR/dump.melt --out $OUTDIR/melt"
    echo "[3/3] Skipping visualization."
    exit 0
fi

echo "[2/3] Generating trajectory MP4 + GIF..."
python3 /usr/share/lammps/scripts/visualize_dump.py \
    "$OUTDIR/dump.melt" --out "$OUTDIR/melt" --fps 4 2>&1 | tail -5

echo "[3/3] Done. Files at:"
ls -lh "$OUTDIR/"melt.{mp4,gif} 2>/dev/null
echo
echo "Open $OUTDIR/melt.gif in any image viewer to see the trajectory."
EOF
chmod 0755 "$STAGE/usr/bin/lammps-rvv-demo"

# ============================================================
# /usr/bin/lammps-rvv-verify: forensic self-test
# ============================================================
cat > "$STAGE/usr/bin/lammps-rvv-verify" << 'EOF'
#!/bin/bash
# lammps-rvv-verify — five-gate forensic self-test for the installed package.
set -euo pipefail

PASS=0
FAIL=0
check() {
    if [ "$1" -eq 0 ]; then
        echo "  ✓ $2"
        PASS=$((PASS + 1))
    else
        echo "  ✗ $2"
        FAIL=$((FAIL + 1))
    fi
}

echo "[1/5] Binary in PATH"
LMP_REAL=/usr/libexec/lammps/lmp
[ -x "$LMP_REAL" ]
check $? "lmp executable found at $LMP_REAL"

echo "[2/5] Architecture"
ARCH=$(file -b "$LMP_REAL" | grep -oE 'UCB RISC-V' || echo "")
[ "$ARCH" = "UCB RISC-V" ]
check $? "ELF is UCB RISC-V"

echo "[3/5] RVV opcode count"
OBJDUMP=""
for c in riscv64-linux-gnu-objdump objdump; do
    if command -v "$c" >/dev/null; then OBJDUMP="$c"; break; fi
done
if [ -z "$OBJDUMP" ]; then
    echo "  ⚠ no objdump available — install binutils-riscv64-linux-gnu to verify"
else
    COUNT=$("$OBJDUMP" -d "$LMP_REAL" 2>/dev/null \
            | grep -cE '\<v(setvli|fmacc|fmul|fadd|fsub|le[0-9]+|se[0-9]+|fred)' || true)
    echo "      RVV opcodes in binary: $COUNT"
    [ "$COUNT" -gt 10000 ]
    check $? "RVV opcode count > 10,000 (expected ~63,000)"
fi

echo "[4/5] Smoke test (LJ melt)"
WORKDIR=$(mktemp -d)
trap "rm -rf $WORKDIR" EXIT
cp /usr/share/lammps/examples/melt/in.melt "$WORKDIR/"
cd "$WORKDIR"
if lmp -in in.melt -log none > smoke.log 2>&1; then
    check 0 "Simulation completed (exit 0)"
else
    check 1 "Simulation failed; tail of log:"
    tail -10 smoke.log
fi

echo "[5/5] Trajectory dump"
if [ -f dump.melt ]; then
    FRAMES=$(grep -c "ITEM: TIMESTEP" dump.melt)
    echo "      Frames produced: $FRAMES"
    [ "$FRAMES" -ge 10 ]
    check $? "≥ 10 trajectory frames"
else
    check 1 "No dump.melt produced"
fi

echo
echo "=== Result: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
EOF
chmod 0755 "$STAGE/usr/bin/lammps-rvv-verify"

# ============================================================
# Documentation
# ============================================================
cat > "$STAGE/usr/share/doc/$PKG_NAME/README.md" << EOF
# lammps-riscv64-rvv

LAMMPS molecular dynamics simulator for riscv64 with GCC 15.2.0
auto-vectorized RVV instructions.

## Quickstart

\`\`\`bash
sudo dpkg -i ${PKG_BASENAME}.deb
sudo apt install -f                      # pull in Recommends (matplotlib, ffmpeg)
lammps-rvv-verify                        # confirm install works
lammps-rvv-demo                          # run melt example, generate trajectory MP4+GIF
\`\`\`

Output lands in \`~/lammps-demo-output/\`.

## Contents

| Path | Purpose |
|---|---|
| \`/usr/bin/lmp\` | Wrapper that auto-sets \`LAMMPS_POTENTIALS\` |
| \`/usr/bin/lammps-rvv-demo\` | End-to-end demo: simulation + visualization |
| \`/usr/bin/lammps-rvv-verify\` | 5-gate forensic self-test |
| \`/usr/libexec/lammps/lmp\` | Real riscv64 binary (stripped) |
| \`/usr/lib/riscv64-linux-gnu/liblammps.a\` | Static library for downstream linking |
| \`/usr/share/lammps/potentials/\` | 261 force-field files (~56 MB) |
| \`/usr/share/lammps/examples/melt/in.melt\` | Modified LJ melt input (dump enabled) |
| \`/usr/share/lammps/scripts/visualize_dump.py\` | Trajectory → MP4/GIF renderer |

## Build provenance

* Upstream: LAMMPS development tip (commit 7f680de, dated 30 March 2026)
* Toolchain: riscv64-linux-gnu-gcc 15.2.0
* Target: rv64gcv_zba_zbb_zfh
* Packages enabled: KSPACE, MANYBODY, MOLECULE, RIGID
* Patches required: zero
* RVV opcodes in binary: ~63,000 (concentrated in long-range solvers
  and setup; PairLJCut::compute hot path remains scalar due to
  neighbor-list indirection)

See <https://github.com/trg-rgb/riscv-hpc-port> for the full forensic
writeup.
EOF

cat > "$STAGE/usr/share/doc/$PKG_NAME/copyright" << EOF
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: LAMMPS
Upstream-Contact: developers@lammps.org
Source: https://github.com/lammps/lammps

Files: *
Copyright: 1995-2026 Sandia Corporation and LAMMPS developers
License: GPL-2

Files: usr/bin/lmp
       usr/bin/lammps-rvv-demo
       usr/bin/lammps-rvv-verify
       usr/share/lammps/scripts/visualize_dump.py
Copyright: 2026 Tanmay Gulhane <tanmaygulhane12@gmail.com>
License: GPL-2

License: GPL-2
 This program is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; version 2 of the License.
 .
 This program is distributed in the hope that it will be useful, but
 WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 General Public License for more details.
 .
 On Debian systems, the complete text of the GNU General Public
 License version 2 can be found in "/usr/share/common-licenses/GPL-2".
EOF

# Changelog (gzipped per Debian policy)
TIMESTAMP=$(date -R)
cat > "$STAGE/usr/share/doc/$PKG_NAME/changelog.Debian" << EOF
$PKG_NAME ($PKG_VERSION) unstable; urgency=low

  * Initial riscv64 packaging of LAMMPS upstream tip (commit 7f680de,
    dated 30 March 2026).
  * Built with riscv64-linux-gnu-gcc 15.2.0 targeting rv64gcv_zba_zbb_zfh.
  * Packages enabled: KSPACE, MANYBODY, MOLECULE, RIGID.
  * Includes bundled trajectory visualization pipeline.
  * Zero upstream patches required.

 -- tanmay <tanmaygulhane12@gmail.com>  $TIMESTAMP
EOF
gzip -9n "$STAGE/usr/share/doc/$PKG_NAME/changelog.Debian"

# Minimal man page
cat > "$STAGE/usr/share/man/man1/lmp.1" << 'EOF'
.TH LMP 1 "May 2026" "LAMMPS riscv64-rvv" "User Commands"
.SH NAME
lmp \- LAMMPS molecular dynamics simulator (riscv64-rvv build)
.SH SYNOPSIS
.B lmp
[\fB\-in\fR \fIinput-file\fR] [\fB\-log\fR \fIlog-file\fR] [\fIoptions\fR]
.SH DESCRIPTION
\fBlmp\fR is a wrapper around the real LAMMPS binary at
\fI/usr/libexec/lammps/lmp\fR that auto-exports \fBLAMMPS_POTENTIALS\fR
pointing to the bundled potentials directory at
\fI/usr/share/lammps/potentials\fR.
.SH RELATED COMMANDS
.TP
.B lammps-rvv-demo
Run the bundled melt example end-to-end with visualization.
.TP
.B lammps-rvv-verify
Five-gate forensic self-test of the installed package.
.SH SEE ALSO
LAMMPS manual: https://docs.lammps.org/
EOF
gzip -9n "$STAGE/usr/share/man/man1/lmp.1"

# ============================================================
# DEBIAN/control (no maintainer scripts — we ship only static libs,
# so ldconfig is unnecessary, which silences W: maintscript-calls-ldconfig)
# ============================================================
INSTALLED_SIZE=$(du -sk "$STAGE" --exclude=DEBIAN | awk '{print $1}')

cat > "$STAGE/DEBIAN/control" << EOF
Package: $PKG_NAME
Version: $PKG_VERSION
Architecture: $PKG_ARCH
Maintainer: tanmay <tanmaygulhane12@gmail.com>
Installed-Size: $INSTALLED_SIZE
Section: science
Priority: optional
Depends: libc6 (>= 2.34), libstdc++6 (>= 13)
Recommends: python3 (>= 3.10), python3-numpy, python3-matplotlib, ffmpeg
Suggests: binutils-riscv64-linux-gnu
Homepage: https://github.com/trg-rgb/riscv-hpc-port
Description: LAMMPS molecular dynamics simulator for RISC-V with RVV
 LAMMPS (Large-scale Atomic/Molecular Massively Parallel Simulator) is a
 classical molecular dynamics simulation code.
 .
 This package provides a riscv64 build of LAMMPS 30Mar2026 with GCC 15.2.0
 auto-vectorized RVV instructions (~63,000 RVV opcodes in the binary,
 concentrated in long-range solver and setup paths; the per-timestep MD
 hot path PairLJCut::compute remains scalar due to neighbor-list
 indirection — see /usr/share/doc/$PKG_NAME/README.md for the forensic
 breakdown).
 .
 Includes:
  * lmp binary with bundled KISS FFT (no external FFTW3 dependency)
  * Static library liblammps.a for downstream linking
  * 261 force-field potential files (~56 MB)
  * Working LJ melt example with trajectory MP4/GIF visualization
  * Self-test command (lammps-rvv-verify)
  * End-to-end demo command (lammps-rvv-demo)
 .
 Plug-and-play: dpkg -i installs everything; lammps-rvv-demo runs an
 end-to-end simulation and visualization with no setup required.
EOF

echo "  ✓ Stage tree built ($(du -sh "$STAGE" | awk '{print $1}'))"
echo

# ============================================================
# Build the .deb
# ============================================================
echo "=== Building .deb ==="
rm -f "$DEB_OUT"
fakeroot dpkg-deb --build -Zzstd -z19 "$STAGE" "$DEB_OUT"
echo "  ✓ Wrote $DEB_OUT ($(du -sh "$DEB_OUT" | awk '{print $1}'))"
echo

# ============================================================
# Verification — three independent methods
# ============================================================
echo "=== Verification: dpkg-deb -I ==="
dpkg-deb -I "$DEB_OUT"
echo

echo "=== Verification: dpkg-deb -c (top 30 entries; awk avoids SIGPIPE) ==="
dpkg-deb -c "$DEB_OUT" > /tmp/deb-contents.txt
awk 'NR<=30' /tmp/deb-contents.txt
echo "  (+ $(wc -l < /tmp/deb-contents.txt) total entries)"
echo

echo "=== Verification: lintian ==="
if command -v lintian >/dev/null; then
    # Suppress tags we deliberately accept:
    # * no-manual-page: viz script + demo/verify wrappers have no man page
    # * binary-without-manpage: same
    # * new-package-should-close-itp-bug: not in Debian archive
    lintian \
        --suppress-tags no-manual-page,binary-without-manpage,new-package-should-close-itp-bug \
        "$DEB_OUT" || true
else
    echo "  (lintian not installed; skip)"
fi
echo

echo "=== Verification: extract + qemu run ==="
EXTRACT_DIR=$(mktemp -d)
dpkg-deb -x "$DEB_OUT" "$EXTRACT_DIR"
echo "  Extracted to $EXTRACT_DIR"

if command -v qemu-riscv64 >/dev/null; then
    SMOKE_WORK=$(mktemp -d)
    cp "$EXTRACT_DIR/usr/share/lammps/examples/melt/in.melt" "$SMOKE_WORK/"
    cd "$SMOKE_WORK"
    echo "  Running melt example via qemu (~10–15 s)..."
    if qemu-riscv64 -L /usr/riscv64-linux-gnu \
            -E LAMMPS_POTENTIALS="$EXTRACT_DIR/usr/share/lammps/potentials" \
            "$EXTRACT_DIR/usr/libexec/lammps/lmp" \
            -in in.melt -log none > qemu-smoke.log 2>&1; then
        if [ -f dump.melt ]; then
            FRAMES=$(grep -c "ITEM: TIMESTEP" dump.melt)
            echo "  ✓ qemu smoke test passed (exit 0, $FRAMES dump frames)"
            if [ "$FRAMES" -lt 10 ]; then
                echo "  ⚠ Expected ≥10 frames; got $FRAMES — investigate"
                exit 1
            fi
        else
            echo "  ✗ qemu run exited 0 but no dump.melt produced"
            tail -20 qemu-smoke.log
            exit 1
        fi
    else
        echo "  ✗ qemu smoke test FAILED; tail of log:"
        tail -20 qemu-smoke.log
        exit 1
    fi
    rm -rf "$SMOKE_WORK"
else
    echo "  (qemu-riscv64 not in PATH; skip runtime verification)"
fi
rm -rf "$EXTRACT_DIR"
echo

# ============================================================
# Final summary
# ============================================================
SHA256=$(sha256sum "$DEB_OUT" | awk '{print $1}')
echo "============================================================"
echo "Package: $DEB_OUT"
echo "Size:    $(du -sh "$DEB_OUT" | awk '{print $1}') compressed, ${INSTALLED_SIZE} KB installed"
echo "SHA256:  $SHA256"
echo "============================================================"
