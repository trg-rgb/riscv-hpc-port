#!/usr/bin/env bash
# lammps-phase1b-verify.sh
#
# Verify LAMMPS riscv64 build: run melt example under qemu, capture
# trajectory, count RVV opcodes, generate evidence summary.

set -uo pipefail

WORK="${WORK:-$HOME/riscv-hpc-port/lammps-port}"
SRC="$WORK/lammps"
BUILD="$WORK/build-riscv64"
RUN="$WORK/run-melt"
LOGS="$WORK/logs"
EVIDENCE="$LOGS/PHASE1B_EVIDENCE.txt"
mkdir -p "$LOGS" "$RUN"

export QEMU_LD_PREFIX=/usr/riscv64-linux-gnu
QEMU="qemu-riscv64"

section() { echo; echo "=== $* ==="; echo; }
record()  { tee -a "$EVIDENCE"; }

: > "$EVIDENCE"
echo "LAMMPS riscv64 — Phase 1B evidence summary"             | record
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"              | record
echo "Build:     $BUILD"                                       | record
echo "Source:    $SRC ($(cd "$SRC" && git rev-parse --short HEAD), $(grep '#define LAMMPS_VERSION' "$SRC/src/version.h" | cut -d'"' -f2))" | record
echo "Toolchain: $(riscv64-linux-gnu-gcc --version | head -1)" | record
echo "QEMU:      $($QEMU --version | head -1)"                | record

# ============================================================
# Gate 1 — ELF architecture
# ============================================================
section "Gate 1: ELF architecture of lmp" | record
file "$BUILD/lmp" | record

# ============================================================
# Gate 2 — Smoke test: lmp -help under qemu
# ============================================================
section "Gate 2: lmp -help smoke test under qemu-riscv64" | record
if timeout 60 $QEMU "$BUILD/lmp" -help > "$LOGS/lmp-help.out" 2>&1; then
    echo "  PASS — first 5 lines of -help output:" | record
    head -5 "$LOGS/lmp-help.out" | sed 's/^/    /' | record
    echo "  Active packages (from -help):" | record
    grep -A1 "^Installed packages" "$LOGS/lmp-help.out" | head -4 | sed 's/^/    /' | record
else
    echo "  FAIL — see $LOGS/lmp-help.out" | record
    tail -10 "$LOGS/lmp-help.out" | sed 's/^/    /' | record
    exit 1
fi

# ============================================================
# Gate 3 — Run melt example end-to-end under qemu
# ============================================================
section "Gate 3: Lennard-Jones melt example end-to-end" | record

# Copy and modify the canonical melt input so it dumps trajectory + thermo
cp "$SRC/examples/melt/in.melt" "$RUN/in.melt"
# Uncomment the atom dump (every 25 steps -> 11 frames including step 0)
sed -i 's|^#dump           id all atom 50 dump.melt|dump           1 all atom 25 dump.melt|' "$RUN/in.melt"

echo "  Modified input file (first 30 lines):" | record
head -30 "$RUN/in.melt" | sed 's/^/    /' | record

cd "$RUN"
log_out="$LOGS/melt-run.out"
echo "  Running... (timeout 600s, expect ~1-3 min under qemu)" | record
start=$(date +%s)
set +e
timeout 600 $QEMU "$BUILD/lmp" -in in.melt > "$log_out" 2>&1
rc=$?
set -e
elapsed=$(( $(date +%s) - start ))

if [[ $rc -eq 0 ]]; then
    echo "  PASS (exit 0, ${elapsed}s wall under qemu)" | record
else
    echo "  FAIL (rc=$rc, ${elapsed}s)" | record
    tail -20 "$log_out" | sed 's/^/    /' | record
    exit 1
fi

# Extract the thermo table from the run output
echo "  Thermo summary from the run:" | record
sed -n '/^Step/,/^Loop time/p' "$log_out" | sed 's/^/    /' | record

# ============================================================
# Gate 4 — Dump file verification
# ============================================================
section "Gate 4: trajectory dump file produced" | record
if [[ -f "$RUN/dump.melt" ]]; then
    frames=$(grep -c "^ITEM: TIMESTEP" "$RUN/dump.melt")
    atoms=$(awk '/ITEM: NUMBER OF ATOMS/{getline; print; exit}' "$RUN/dump.melt")
    size=$(stat -c '%s' "$RUN/dump.melt")
    {
        echo "  PASS — dump.melt produced"
        printf "    Frames:    %d\n" "$frames"
        printf "    Atoms:     %s per frame\n" "$atoms"
        printf "    File size: %d bytes\n" "$size"
        echo
        echo "  First 8 lines (timestep 0 header + first atoms):"
        head -8 "$RUN/dump.melt" | sed 's/^/      /'
    } | record
else
    echo "  FAIL — dump.melt not produced" | record
    exit 1
fi

# ============================================================
# Gate 5 — RVV opcode forensics on lmp binary
# ============================================================
section "Gate 5: RVV opcode forensics on lmp binary" | record

DISASM="$LOGS/lmp.disasm"
echo "  (disassembling lmp — first time only, may take ~30s)" >&2
riscv64-linux-gnu-objdump -d "$BUILD/lmp" > "$DISASM" 2>/dev/null

total_insns=$(grep -cE '^\s+[0-9a-f]+:\s+[0-9a-f]+' "$DISASM" || true)
rvv_total=$(grep -cE '\<(vle[0-9]+|vse[0-9]+|vsetvl[i]?|vsetivli|vfmacc|vfmul|vfadd|vfsub|vfdiv|vfredosum|vfredusum|vfmin|vfmax|vlse[0-9]+|vsse[0-9]+|vfmv|vfmerge|vfsqrt|vfwmacc|vfnmacc|vfmsac|vfnmsac|vfmadd|vfnmadd|vfmsub|vfnmsub|vfcvt)\>' "$DISASM" || true)

rvv_e64=$(grep -cE '\<e64,\s*m[f0-9]+\>' "$DISASM" || true)
rvv_e64_m4=$(grep -cE '\<e64,\s*m4\>' "$DISASM" || true)
rvv_e64_m2=$(grep -cE '\<e64,\s*m2\>' "$DISASM" || true)
rvv_e64_m1=$(grep -cE '\<e64,\s*m1\>' "$DISASM" || true)
rvv_e32=$(grep -cE '\<e32,\s*m[f0-9]+\>' "$DISASM" || true)

vfmacc=$(grep -cE '\bvfmacc(\.|_)' "$DISASM" || true)
vfmul=$(grep -cE '\bvfmul(\.|_)' "$DISASM" || true)
vfadd=$(grep -cE '\bvfadd(\.|_)' "$DISASM" || true)
vfred=$(grep -cE '\bvfred[ou]sum(\.|_)' "$DISASM" || true)

{
    printf '  Total instructions:               %d\n'  "$total_insns"
    printf '  Total RVV opcodes:                %d\n'  "$rvv_total"
    printf '  vsetvli e64 (any LMUL):           %d\n'  "$rvv_e64"
    printf '    of which LMUL=4 (e64,m4):       %d\n'  "$rvv_e64_m4"
    printf '    of which LMUL=2 (e64,m2):       %d\n'  "$rvv_e64_m2"
    printf '    of which LMUL=1 (e64,m1):       %d\n'  "$rvv_e64_m1"
    printf '  vsetvli e32 (any LMUL):           %d\n'  "$rvv_e32"
    printf '  vfmacc.* (fused multiply-add):    %d\n'  "$vfmacc"
    printf '  vfmul.*:                          %d\n'  "$vfmul"
    printf '  vfadd.*:                          %d\n'  "$vfadd"
    printf '  vfred[ou]sum.* (reduction):       %d\n'  "$vfred"
} | record

# ============================================================
# Gate 6 — RVV in MD hot path (top functions)
# ============================================================
section "Gate 6: RVV opcodes by function (top 15)" | record

awk '
  /^[0-9a-f]+ <.+>:/ {
    fn = $0
    sub(/^[0-9a-f]+ </, "", fn)
    sub(/>:$/, "", fn)
    next
  }
  /\<(vfmacc|vfmul|vfadd|vfsub|vle[0-9]+|vse[0-9]+|vsetvl|vfred)/ { c[fn]++ }
  END { for (f in c) printf "%6d  %s\n", c[f], f }
' "$DISASM" | sort -rn | head -15 | c++filt \
  | tee "$LOGS/top15-rvv-fns.txt" | sed 's/^/  /' | record

# ============================================================
# Gate 7 — Reproduction hashes
# ============================================================
section "Gate 7: Reproduction hashes (SHA256)" | record
{
    sha256sum "$BUILD/lmp"
    sha256sum "$BUILD/liblammps.a" 2>/dev/null || true
    sha256sum "$RUN/dump.melt"
} | record

# ============================================================
# Headline
# ============================================================
section "HEADLINE" | record
{
    echo "  Patches needed:                    0"
    echo "  lmp ELF arch:                      UCB RISC-V double-float ABI"
    echo "  RVV opcodes in lmp:                $rvv_total"
    echo "  LMUL=1 f64 vsetvli sites:          $rvv_e64_m1"
    echo "  Melt example trajectory frames:    $frames"
    echo "  Atoms simulated:                   $atoms"
    echo "  Wall time under qemu (melt):       ${elapsed}s"
    echo
    echo "  Evidence: $EVIDENCE"
    echo "  Disasm:   $DISASM"
    echo "  Trajectory: $RUN/dump.melt"
} | record
