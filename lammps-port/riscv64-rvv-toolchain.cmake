# riscv64-rvv-toolchain.cmake
# Cross-compile from x86_64 → riscv64 with RVV 1.0 enabled.
# Used for OpenMM 8.5.0 LFX port at #25-standard.
#
# rv64gcv breakdown:
#   g  = IMAFD_Zicsr_Zifencei (general-purpose ISA)
#   c  = compressed instructions
#   v  = RVV 1.0 (the whole point)
#
# Notes:
#   - OpenMM CPU platform uses vectorize_portable.h (GCC vector extensions)
#     for riscv64. With -march=rv64gcv -O3, GCC 15.2.0 will lower these to
#     RVV instructions. Whether it picks LMUL=1 or higher is the open
#     empirical question Phase 1 answers via objdump.
#   - sysroot is the Ubuntu cross-toolchain default; adjust if yours differs.

set(CMAKE_SYSTEM_NAME      Linux)
set(CMAKE_SYSTEM_PROCESSOR riscv64)

set(CMAKE_C_COMPILER       riscv64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER     riscv64-linux-gnu-g++)
set(CMAKE_AR               riscv64-linux-gnu-ar)
set(CMAKE_RANLIB           riscv64-linux-gnu-ranlib)
set(CMAKE_STRIP            riscv64-linux-gnu-strip)
set(CMAKE_OBJDUMP          riscv64-linux-gnu-objdump)

# ABI: lp64d (hard-float, double precision in registers — required for f64 HPC)
set(_RV_ARCH_FLAGS "-march=rv64gcv -mabi=lp64d")

set(CMAKE_C_FLAGS_INIT     "${_RV_ARCH_FLAGS}")
set(CMAKE_CXX_FLAGS_INIT   "${_RV_ARCH_FLAGS}")

# Ubuntu/Debian cross-toolchain default sysroot
set(CMAKE_FIND_ROOT_PATH   /usr/riscv64-linux-gnu)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Belt-and-suspenders: tell try_compile() not to try executing the test binary
# (it's a riscv64 ELF; the build host is x86_64).
set(CMAKE_CROSSCOMPILING TRUE)
