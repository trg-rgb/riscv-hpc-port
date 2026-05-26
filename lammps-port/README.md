# LAMMPS riscv64 port with RVV auto-vectorization

Cross-compile of [LAMMPS](https://github.com/lammps/lammps) development tip
(commit `7f680de`, dated 30 March 2026) to `riscv64` with GCC 15.2.0
targeting `rv64gcv_zba_zbb_zfh`. **Zero upstream patches required.**

## Headline numbers

| Metric | Value |
|---|---|
| Upstream patches needed | 0 |
| RVV opcodes auto-vectorized in `lmp` binary | 63,913 |
| RVV in `PairLJCut::compute` (per-timestep MD hot path) | 0 |
| RVV in `PPPM::compute` (long-range solver, exercised by peptide) | 46 |
| `melt` example (4000 LJ atoms, 250 steps) wall under qemu | 7.5 s |
| `peptide` example (2004 atoms, 300 steps + PPPM) wall under qemu | 85.7 s |
| KSpace fraction of peptide loop (vectorized path) | 25.01 % |
| `.deb` size compressed / installed | 22 MB / 125 MB |
| `.deb` SHA256 | `f97e82e6475d59f96899cd21dd5767e4bf3a616b4f896658ab59fa4ec3ba2ef6` |

**Honest framing**: 63,913 RVV opcodes reflects *vectorization coverage in
the binary*, not *acceleration of any particular workload*. GCC 15.2's
auto-vectorizer cannot vectorize the indexed neighbor-list access pattern
in `PairLJCut::compute`, `Neighbor::build`, or `Verlet::run` without
explicit gather intrinsics. The vectorized code paths (KSpace/PPPM
long-range solvers, parsers, allocators) execute when the workload
exercises them — confirmed via the peptide benchmark's 25% KSpace loop
fraction.

## Plug-and-play

```bash
sudo dpkg -i dist/lammps-riscv64-rvv_30Mar26-1_riscv64.deb
sudo apt install -f                      # pull in matplotlib + ffmpeg
lammps-rvv-verify                        # five-gate forensic self-test
lammps-rvv-demo                          # melt sim + GIF/MP4 in ~/lammps-demo-output/
```

## Repo layout

| Path | Purpose |
|---|---|
| `lammps-phase1-bootstrap.sh` | clone LAMMPS + configure + build (Phase 1A) |
| `lammps-phase1b-verify.sh` | 7-gate forensic verification (Phase 1B) |
| `riscv64-rvv-toolchain.cmake` | CMake toolchain file (reused across ports) |
| `scripts/visualize_dump.py` | Trajectory → MP4/GIF renderer (handles all 4 LAMMPS coord variants) |
| `scripts/package-deb.sh` | Plug-and-play `.deb` builder w/ strip, lintian-clean, qemu smoke test |
| `dist/*.deb` | Built package |
| `run-melt/in.melt` | Modified melt input (dump enabled for visualization) |
| `run-melt/dump.melt` | Reference trajectory (11 frames, 4000 atoms) |
| `run-melt/melt.{gif,mp4}` | Visualization artifacts |
| `logs/peptide/peptide.log` | Runtime evidence: KSpace path executed (25% of loop) |

## Reproduce

```bash
git clone https://github.com/trg-rgb/riscv-hpc-port.git
cd riscv-hpc-port/lammps-port

./lammps-phase1-bootstrap.sh           # ~5–10 min (downloads LAMMPS + builds)
./lammps-phase1b-verify.sh             # ~1 min (forensic checks)
./scripts/package-deb.sh               # ~30 s (build + verify the .deb)
```

## See also

- Sibling ports in this repo: `../openmm-port`, `../tflite`, `../hal`, `../doom`, `../openblas`
- Full forensic writeup: issue in
  [clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries](https://github.com/clusterchallenge/Hardware-Abstraction-Layer-Transitional-Libraries/issues)
