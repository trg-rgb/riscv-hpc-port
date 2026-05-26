#!/usr/bin/env bash
# Run 7 CPU platform tests under qemu, capture pass/fail.
# Skip TestCpuNonbondedForce — already passed in earlier background run.

set -uo pipefail
BUILD=~/riscv-hpc-port/openmm-port/build-riscv64
LOGS=~/riscv-hpc-port/openmm-port/logs
export QEMU_LD_PREFIX=/usr/riscv64-linux-gnu
cd "$BUILD"

TESTS=(
  TestCpuPeriodicTorsionForce
  TestCpuRBTorsionForce
  TestCpuSettle
  TestCpuCustomNonbondedForce
  TestCpuPme
  TestCpuLangevinIntegrator
  TestCpuEwald
)

PASS=(); FAIL=(); TIMEOUT=()
: > "$LOGS/phase1c-cputests.summary"

for t in "${TESTS[@]}"; do
  echo "=== $t ===" | tee -a "$LOGS/phase1c-cputests.summary"
  start=$(date +%s)
  set +e
  timeout 1500 qemu-riscv64 -E LD_LIBRARY_PATH="$BUILD" "./$t" \
    > "$LOGS/$t.out" 2>&1
  rc=$?
  set -e
  el=$(( $(date +%s) - start ))
  case $rc in
    0)   echo "  PASS    (${el}s)"          | tee -a "$LOGS/phase1c-cputests.summary"; PASS+=("$t (${el}s)") ;;
    124) echo "  TIMEOUT after ${el}s"      | tee -a "$LOGS/phase1c-cputests.summary"; TIMEOUT+=("$t") ;;
    *)   echo "  FAIL rc=$rc (${el}s)"      | tee -a "$LOGS/phase1c-cputests.summary"
         tail -5 "$LOGS/$t.out" | sed 's/^/    /' | tee -a "$LOGS/phase1c-cputests.summary"
         FAIL+=("$t (rc=$rc)") ;;
  esac
done

{
  echo
  echo "=== SUMMARY ==="
  printf 'PASS    (%d):\n'    "${#PASS[@]}"
  for x in "${PASS[@]}";    do echo "  $x";    done
  printf 'FAIL    (%d):\n'    "${#FAIL[@]}"
  for x in "${FAIL[@]}";    do echo "  $x";    done
  printf 'TIMEOUT (%d):\n' "${#TIMEOUT[@]}"
  for x in "${TIMEOUT[@]}"; do echo "  $x";    done
} | tee -a "$LOGS/phase1c-cputests.summary"
