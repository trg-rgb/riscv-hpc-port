#!/usr/bin/env bash
# openmm-phase1b-verify.sh
#
# Phase 1B of OpenMM 8.5.0 riscv64 port (#25 standard).
# Runs the seven evidence gates and produces a one-page summary.
#
# Run from the same dir as the bootstrap script, after that script succeeded.

set -uo pipefail   # NOT -e — we want to continue past individual test failures

WORK="${WORK:-$HOME/riscv-hpc-port/openmm-port}"
BUILD="$WORK/build-riscv64"
SRC="$WORK/openmm"
LOGS="$WORK/logs"
EVIDENCE="$LOGS/PHASE1B_EVIDENCE.txt"
mkdir -p "$LOGS"

# qemu setup — these tests dlopen .so plugins from the cwd, so we need
# LD_LIBRARY_PATH to point at the build dir. Cross-libc lives under
# /usr/riscv64-linux-gnu/lib.
export QEMU_LD_PREFIX=/usr/riscv64-linux-gnu
QEMU="qemu-riscv64"

# Plugin dir is the build dir itself (OpenMM dlopens libOpenMMCPU.so etc by name)
export OPENMM_PLUGIN_DIR="$BUILD"

# Per-test wall-clock budget — qemu is ~50× slower than native; some tests
# will exceed this and that's OK, we just note them as TIMEOUT.
TEST_TIMEOUT="${TEST_TIMEOUT:-180}"

# ---------- helpers ----------
section() { echo; echo "=== $* ==="; echo; }
record()  { tee -a "$EVIDENCE"; }

: > "$EVIDENCE"
echo "OpenMM 8.5.0 riscv64 — Phase 1B evidence summary"      | record
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"             | record
echo "Build dir: $BUILD"                                     | record
echo "Source:    $SRC ($(cd "$SRC" && git rev-parse --short HEAD))" | record
echo "Toolchain: $(riscv64-linux-gnu-gcc --version | head -1)" | record
echo "QEMU:      $($QEMU --version | head -1)"               | record

cd "$BUILD"

# ============================================================
# Gate 1 — ELF architecture verification
# ============================================================
section "Gate 1: ELF architecture (all libraries must be riscv64)" | record
for so in libOpenMM.so libOpenMMCPU.so libOpenMMPME.so \
          libOpenMMAmoeba.so libOpenMMAmoebaReference.so \
          libOpenMMDrude.so libOpenMMDrudeReference.so \
          libOpenMMRPMD.so libOpenMMRPMDReference.so; do
    if [[ -f "$so" ]]; then
        arch=$(file "$so" | grep -oE 'UCB RISC-V[^,]*|x86-64' | head -1)
        size=$(stat -c '%s' "$so")
        printf '  %-35s %s (%d bytes)\n' "$so" "$arch" "$size"
    fi
done | record

# ============================================================
# Gate 2 — RVV opcode forensics on libOpenMMCPU.so
# ============================================================
section "Gate 2: RVV opcode forensics on libOpenMMCPU.so" | record

DISASM="$LOGS/libOpenMMCPU.disasm"
echo "  (disassembling — first time only, may take ~20s)" >&2
riscv64-linux-gnu-objdump -d "$BUILD/libOpenMMCPU.so" > "$DISASM" 2>/dev/null

total_insns=$(grep -cE '^\s+[0-9a-f]+:\s+[0-9a-f]+' "$DISASM")

# Broad RVV count: any vector instruction
rvv_total=$(grep -cE '^\s+[0-9a-f]+:.*\b(vle[0-9]+|vse[0-9]+|vl[0-9]+r|vs[0-9]+r|vsetvl[i]?|vsetivli|vfmacc|vfmul|vfadd|vfsub|vfdiv|vfredosum|vfredusum|vfmin|vfmax|vle[0-9]+ff|vluxei|vsuxei|vlse[0-9]+|vsse[0-9]+|vfmv|vfmerge|vfsqrt|vrgather|vid|vmv|vand|vor|vxor|vsll|vsrl|vsra|vadd|vsub|vmul|vdiv|vredsum|vredmax|vredmin|vfwmacc|vfnmacc|vfmsac|vfnmsac|vfmadd|vfnmadd|vfmsub|vfnmsub|vfcvt|vfwcvt|vfncvt|vmseq|vmsne|vmslt|vmsle|vmsgt|vmflt|vmfle|vmfeq|vmfne)\b' "$DISASM" || true)

# f64-specific (e64) and LMUL=4 narrowing
rvv_e64=$(grep -cE 'vsetvli.*e64' "$DISASM" || true)
rvv_e64_m4=$(grep -cE 'vsetvli.*e64,\s*m4' "$DISASM" || true)
rvv_e64_m2=$(grep -cE 'vsetvli.*e64,\s*m2' "$DISASM" || true)
rvv_e64_m1=$(grep -cE 'vsetvli.*e64,\s*m1' "$DISASM" || true)

# Headline ops
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
    printf '  vfmacc.* (fused multiply-add):    %d\n'  "$vfmacc"
    printf '  vfmul.*  (multiply):              %d\n'  "$vfmul"
    printf '  vfadd.*  (add):                   %d\n'  "$vfadd"
    printf '  vfred[ou]sum.* (reduction):       %d\n'  "$vfred"
} | record

# ============================================================
# Gate 3 — Function-scoped RVV count in the Fvec hot path
# ============================================================
section "Gate 3: Function-scoped RVV opcodes in CpuNonbondedForceFvec" | record

# Use awk to extract opcodes between function-start markers, filter by symbol
fvec_rvv=$(awk '
    /^[0-9a-f]+ <.*CpuNonbondedForceFvec.*>:/   { inside=1; next }
    /^[0-9a-f]+ <.*>:/                           { inside=0 }
    inside && /\b(vfmacc|vfmul|vfadd|vfsub|vle[0-9]+|vse[0-9]+|vsetvl|vfred)/ { c++ }
    END { print c+0 }
' "$DISASM")

# Same for the customnonbonded path
custfvec_rvv=$(awk '
    /^[0-9a-f]+ <.*CpuCustomNonbondedForceFvec.*>:/   { inside=1; next }
    /^[0-9a-f]+ <.*>:/                                 { inside=0 }
    inside && /\b(vfmacc|vfmul|vfadd|vfsub|vle[0-9]+|vse[0-9]+|vsetvl|vfred)/ { c++ }
    END { print c+0 }
' "$DISASM")

# Pme kernel (uses fvec4 too)
pme_rvv=$(awk '
    /^[0-9a-f]+ <.*CpuPme.*>:/                  { inside=1; next }
    /^[0-9a-f]+ <.*>:/                           { inside=0 }
    inside && /\b(vfmacc|vfmul|vfadd|vfsub|vle[0-9]+|vse[0-9]+|vsetvl|vfred)/ { c++ }
    END { print c+0 }
' "$DISASM")

{
    printf '  CpuNonbondedForceFvec symbols:        %d RVV opcodes\n'  "$fvec_rvv"
    printf '  CpuCustomNonbondedForceFvec symbols:  %d RVV opcodes\n'  "$custfvec_rvv"
    printf '  CpuPme* symbols:                      %d RVV opcodes\n'  "$pme_rvv"
} | record

# ============================================================
# Gate 4 — HelloArgon smoke test under qemu
# ============================================================
section "Gate 4: HelloArgon smoke test under qemu-riscv64" | record

if [[ -x "./HelloArgon" ]]; then
    echo "  Running HelloArgon (timeout ${TEST_TIMEOUT}s)..." | record
    set +e
    timeout "$TEST_TIMEOUT" $QEMU -E LD_LIBRARY_PATH="$BUILD" ./HelloArgon \
        > "$LOGS/HelloArgon.out" 2>&1
    rc=$?
    set -e
    if [[ $rc -eq 0 ]]; then
        echo "  PASS (exit 0)" | record
        echo "  First 3 lines of output:" | record
        head -3 "$LOGS/HelloArgon.out" | sed 's/^/    /' | record
        echo "  Last 3 lines of output:" | record
        tail -3 "$LOGS/HelloArgon.out" | sed 's/^/    /' | record
    elif [[ $rc -eq 124 ]]; then
        echo "  TIMEOUT after ${TEST_TIMEOUT}s — investigate separately" | record
    else
        echo "  FAIL (exit $rc) — see $LOGS/HelloArgon.out" | record
        tail -10 "$LOGS/HelloArgon.out" | sed 's/^/    /' | record
    fi
else
    echo "  HelloArgon binary missing — skipped" | record
fi

# ============================================================
# Gate 5 — Sample of Reference platform tests under qemu
# ============================================================
section "Gate 5: Reference platform tests (subset) under qemu-riscv64" | record

# Pick a small, fast subset — kinetic energy, harmonic bond, CM motion.
# These do NOT need RVV — they're Reference-only — but they validate that
# the cross-compile produced executable test binaries and the runtime works.
REF_TESTS=(
    TestReferenceCMMotionRemover
    TestReferenceHarmonicBondForce
    TestReferenceHarmonicAngleForce
)

ref_pass=0; ref_fail=0; ref_timeout=0
for t in "${REF_TESTS[@]}"; do
    bin=$(find "$BUILD" -maxdepth 4 -type f -executable -name "$t" 2>/dev/null | head -1)
    if [[ -z "$bin" ]]; then
        printf '  %-45s NOT BUILT\n' "$t" | record
        continue
    fi
    cd "$(dirname "$bin")"
    set +e
    timeout "$TEST_TIMEOUT" $QEMU -E LD_LIBRARY_PATH="$BUILD" "./$t" \
        > "$LOGS/$t.out" 2>&1
    rc=$?
    set -e
    cd "$BUILD"
    if   [[ $rc -eq 0   ]]; then printf '  %-45s PASS\n'    "$t" | record; ref_pass=$((ref_pass+1))
    elif [[ $rc -eq 124 ]]; then printf '  %-45s TIMEOUT\n' "$t" | record; ref_timeout=$((ref_timeout+1))
    else                         printf '  %-45s FAIL (rc=%d)\n' "$t" "$rc" | record; ref_fail=$((ref_fail+1))
    fi
done

printf '  Reference summary: %d PASS, %d FAIL, %d TIMEOUT\n' \
    "$ref_pass" "$ref_fail" "$ref_timeout" | record

# ============================================================
# Gate 6 — Sample of CPU platform tests (these compare CPU vs Reference internally)
# ============================================================
section "Gate 6: CPU platform tests (bit-exact gate — internally compares CPU vs Reference)" | record

CPU_TESTS=(
    TestCpuHarmonicBondForce
    TestCpuHarmonicAngleForce
    TestCpuNonbondedForce
)

cpu_pass=0; cpu_fail=0; cpu_timeout=0
for t in "${CPU_TESTS[@]}"; do
    bin=$(find "$BUILD" -maxdepth 4 -type f -executable -name "$t" 2>/dev/null | head -1)
    if [[ -z "$bin" ]]; then
        printf '  %-45s NOT BUILT\n' "$t" | record
        continue
    fi
    cd "$(dirname "$bin")"
    set +e
    timeout "$TEST_TIMEOUT" $QEMU -E LD_LIBRARY_PATH="$BUILD" "./$t" \
        > "$LOGS/$t.out" 2>&1
    rc=$?
    set -e
    cd "$BUILD"
    if   [[ $rc -eq 0   ]]; then printf '  %-45s PASS\n'    "$t" | record; cpu_pass=$((cpu_pass+1))
    elif [[ $rc -eq 124 ]]; then printf '  %-45s TIMEOUT\n' "$t" | record; cpu_timeout=$((cpu_timeout+1))
    else                         printf '  %-45s FAIL (rc=%d)\n' "$t" "$rc" | record; cpu_fail=$((cpu_fail+1))
    fi
done

printf '  CPU summary: %d PASS, %d FAIL, %d TIMEOUT\n' \
    "$cpu_pass" "$cpu_fail" "$cpu_timeout" | record

# ============================================================
# Gate 7 — Reproduction hash
# ============================================================
section "Gate 7: Reproduction hashes (SHA256)" | record
{
    for so in libOpenMM.so libOpenMMCPU.so libOpenMMPME.so; do
        if [[ -f "$BUILD/$so" ]]; then
            sha256sum "$BUILD/$so"
        fi
    done
} | record

# ============================================================
# Headline
# ============================================================
section "HEADLINE" | record
{
    echo "  RVV opcodes in libOpenMMCPU.so:    $rvv_total"
    echo "  LMUL=4 f64 vsetvli sites:          $rvv_e64_m4"
    echo "  Fvec hot-path RVV opcodes:         $fvec_rvv"
    echo "  Reference tests:                   $ref_pass/$((ref_pass+ref_fail+ref_timeout)) PASS"
    echo "  CPU tests (bit-exact gate):        $cpu_pass/$((cpu_pass+cpu_fail+cpu_timeout)) PASS"
    echo
    echo "  Evidence file: $EVIDENCE"
    echo "  Disassembly:   $DISASM"
} | record
