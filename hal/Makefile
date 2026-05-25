# HAL SIMD shim — reproduction build for riscv64

SHELL    := /bin/bash
CROSS    := riscv64-linux-gnu-
CC       := $(CROSS)gcc
OBJDUMP  := $(CROSS)objdump
QEMU     := qemu-riscv64

CFLAGS   := -O2 -static -I.. -I.

.PHONY: all scalar rvv test verify clean

all: test_hal_riscv64_scalar test_hal_riscv64_rvv

test_hal_riscv64_scalar: test_hal.c simd.h
	$(CC) $(CFLAGS) -march=rv64gc  -o $@ test_hal.c

test_hal_riscv64_rvv: test_hal.c simd.h
	$(CC) $(CFLAGS) -march=rv64gcv -o $@ test_hal.c

test: all
	$(QEMU) ./test_hal_riscv64_scalar > test_hal_results_scalar.txt
	$(QEMU) ./test_hal_riscv64_rvv    > test_hal_results_rvv.txt
	@echo "--- Scalar ---" && tail -3 test_hal_results_scalar.txt
	@echo "--- RVV    ---" && tail -3 test_hal_results_rvv.txt

verify: test
	@diff <(grep -v '^Architecture' test_hal_results_scalar.txt) \
	      <(grep -v '^Architecture' test_hal_results_rvv.txt) \
	  && echo "BIT-IDENTICAL across backends" \
	  || echo "RESULTS DIFFER"
	@echo -n "RVV opcodes in RVV binary: "
	@$(OBJDUMP) -d test_hal_riscv64_rvv    | grep -cE 'vle64|vse64|vfmacc|vsetvl|vfmul|vfadd|vfredosum' || true
	@echo -n "f64m4 opcodes in scalar binary (must be 0): "
	@$(OBJDUMP) -d test_hal_riscv64_scalar | grep -cE 'vfmacc.vv|vfredosum.vs|vsetvli.*e64,m4' || true

clean:
	rm -f test_hal_riscv64_scalar test_hal_riscv64_rvv \
	      test_hal_results_scalar.txt test_hal_results_rvv.txt
