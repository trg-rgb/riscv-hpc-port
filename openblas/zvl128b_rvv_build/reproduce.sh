#!/usr/bin/env bash
# Reproduces all measurements from the OpenBLAS findings issue.
# Run after build_command.sh has produced libopenblas_riscv64_zvl128b-r0.3.33.dev.a
#
# Author: trg-rgb (Tanmay Gulhane)

set -euo pipefail

LIB="${1:-OpenBLAS/libopenblas_riscv64_zvl128b-r0.3.33.dev.a}"

if [ ! -f "$LIB" ]; then
    echo "ERROR: library not found at $LIB"
    echo "Usage: $0 [path/to/libopenblas_riscv64_zvl128b-r0.3.33.dev.a]"
    exit 1
fi

echo "=========================================================="
echo "Reproducing OpenBLAS 0.3.33 RVV findings"
echo "Library: $LIB"
echo "=========================================================="

# 1. Total RVV opcode count
echo ""
echo "--- Total RVV opcode count ---"
COUNT=$(riscv64-linux-gnu-objdump -d "$LIB" 2>/dev/null \
    | grep -c "vle64\|vfmacc\|vsetvli\|vlse64\|vfmul\|vfadd\|vfredosum")
echo "Total RVV opcodes: $COUNT"
echo "Expected: 14355"

# 2. Per-opcode breakdown
echo ""
echo "--- Per-opcode breakdown ---"
for opc in vsetvli vle64 vfmacc vfmul vfadd vfredosum; do
    N=$(riscv64-linux-gnu-objdump -d "$LIB" 2>/dev/null | grep -c "$opc")
    printf "  %-12s %d\n" "$opc" "$N"
done

# 3. dgemm_kernel size
echo ""
echo "--- dgemm_kernel size (authoritative from symbol table) ---"
riscv64-linux-gnu-nm --print-size --size-sort "$LIB" 2>/dev/null \
    | grep " dgemm_kernel$"
echo "Expected: 0000000000000000 000000000000084e T dgemm_kernel"

# 4. Reproducibility check
echo ""
echo "--- Opcode count reproducibility (10 runs) ---"
for i in $(seq 1 10); do
    C=$(riscv64-linux-gnu-objdump -d "$LIB" 2>/dev/null \
        | grep -c "vle64\|vfmacc\|vsetvli\|vlse64\|vfmul\|vfadd\|vfredosum")
    H=$(riscv64-linux-gnu-objdump -d "$LIB" 2>/dev/null \
        | grep -E "vle64|vfmacc|vsetvli|vlse64|vfmul|vfadd|vfredosum" \
        | md5sum | cut -d' ' -f1)
    echo "Run $i: count=$C  hash=$H"
done

echo ""
echo "=========================================================="
echo "Reproduction complete."
echo "For DGEMM correctness, run: qemu-riscv64 ./dgemm_validate"
echo "=========================================================="
