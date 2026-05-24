# OpenBLAS 0.3.33 RVV Findings — Supporting Files

This directory accompanies the GitHub issue
**"[Validation] OpenBLAS 0.3.33 RVV on GCC 15: Complementary Findings to #23"**

## Files

| File | Purpose |
|---|---|
| `dgemm_validate.c` | 12-case DGEMM correctness test using Higham 2002 §3.5 eq. 3.13 error bounds |
| `build_command.sh` | Exact OpenBLAS build invocation for `TARGET=RISCV64_ZVL128B` |
| `reproduce.sh` | Reproduces all opcode counts and reproducibility hashes from the issue |
| `findings_summary.txt` | Plain-text summary of every measured value |

## Quick start

~~~bash
./build_command.sh                                    # Build OpenBLAS (~5 min)
./reproduce.sh                                        # Reproduce all opcode numbers
riscv64-linux-gnu-gcc -O2 -I OpenBLAS dgemm_validate.c \
    OpenBLAS/libopenblas_riscv64_zvl128b-r0.3.33.dev.a \
    -lm -lpthread -static -o dgemm_validate
qemu-riscv64 ./dgemm_validate                         # Run correctness tests
~~~

## Requirements

- `riscv64-linux-gnu-gcc` 15.2.0 (or any GCC 13+)
- `qemu-riscv64` (user-mode emulation)
- `make`, `git`, `objdump`, `nm`

## Author

Tanmay Gulhane (trg-rgb)
