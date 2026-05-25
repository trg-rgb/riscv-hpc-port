# OpenBLAS ZVL128B build artifacts

The ZVL128B-RVV build of OpenBLAS 0.3.33 produced:

- Library: `libopenblas_riscv64_zvl128b-r0.3.33.dev.a` (49 MB)
- RVV opcode count: 14,355 (verified via objdump)
- Build command, reproduce script, validation harness: `~/openblas_findings/`

The build artifact and supporting files are preserved at
`/home/tanmay/openblas_findings/` rather than under this directory.
The technical findings from this build drove upstream documentation
PR OpenMathLib/OpenBLAS#5819 (co-authored with @Vaibhav805).

See Issue #25 for the full technical writeup.
