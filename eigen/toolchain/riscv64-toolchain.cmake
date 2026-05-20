# riscv64-toolchain.cmake
# CMake toolchain file for cross-compiling to RISC-V64 on Ubuntu/Debian
# Toolchain: riscv64-linux-gnu-gcc (apt: gcc-riscv64-linux-gnu)
# Tanmay Gulhane — LFX Mentorship Summer 2026

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR riscv64)

set(CMAKE_C_COMPILER   riscv64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER riscv64-linux-gnu-g++)

set(CMAKE_FIND_ROOT_PATH /usr/riscv64-linux-gnu)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# Static link so binary runs on real RISC-V hardware without sysroot
set(CMAKE_EXE_LINKER_FLAGS "-static")
