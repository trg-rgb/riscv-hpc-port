#!/usr/bin/env python3
"""
visualize_dump.py — Render a LAMMPS custom-dump trajectory to MP4 + GIF.

Handles all four LAMMPS coordinate variants:
    x  y  z      (wrapped, absolute)
    xu yu zu     (unwrapped, absolute)
    xs ys zs     (wrapped, scaled to [0,1])  -> converted to absolute
    xsu ysu zsu  (unwrapped, scaled)         -> converted to absolute

Usage:
    python3 visualize_dump.py dump.melt --out melt
"""
import argparse
import shutil
import subprocess
import sys
from pathlib import Path

import matplotlib
import numpy as np

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D  # noqa: F401  (registers 3d projection)


def parse_dump(path):
    """Yield (timestep, box, cols, atoms_array) for each frame in a LAMMPS custom dump."""
    with open(path) as f:
        while True:
            line = f.readline()
            if not line:
                return
            if not line.startswith("ITEM: TIMESTEP"):
                continue
            timestep = int(f.readline().strip())
            assert f.readline().startswith("ITEM: NUMBER OF ATOMS")
            natoms = int(f.readline().strip())
            f.readline()  # ITEM: BOX BOUNDS ...
            box = [tuple(map(float, f.readline().split())) for _ in range(3)]
            cols = f.readline().strip().split()[2:]  # strip "ITEM: ATOMS"
            data = np.empty((natoms, len(cols)))
            for i in range(natoms):
                data[i] = list(map(float, f.readline().split()))
            yield timestep, box, cols, data


def get_coords(cols, data, box):
    """Return absolute (x, y, z) arrays regardless of dump coord variant."""
    variants = [
        (("x", "y", "z"), False),
        (("xu", "yu", "zu"), False),
        (("xs", "ys", "zs"), True),
        (("xsu", "ysu", "zsu"), True),
    ]
    for (cx, cy, cz), scaled in variants:
        if all(c in cols for c in (cx, cy, cz)):
            ix, iy, iz = cols.index(cx), cols.index(cy), cols.index(cz)
            x, y, z = data[:, ix], data[:, iy], data[:, iz]
            if scaled:
                (xlo, xhi), (ylo, yhi), (zlo, zhi) = box
                x = xlo + x * (xhi - xlo)
                y = ylo + y * (yhi - ylo)
                z = zlo + z * (zhi - zlo)
            return x, y, z
    raise ValueError(f"No recognized coordinate columns in dump header: {cols}")


def render_frame(timestep, box, cols, data, out_png, idx, total):
    fig = plt.figure(figsize=(8, 8), dpi=100)
    ax = fig.add_subplot(111, projection="3d")

    x, y, z = get_coords(cols, data, box)
    it = cols.index("type") if "type" in cols else None
    types = data[:, it].astype(int) if it is not None else None
    unique = np.unique(types) if types is not None else [1]

    if types is not None and len(unique) > 1:
        cmap = plt.get_cmap("tab10")
        for i, t in enumerate(unique):
            m = types == t
            ax.scatter(
                x[m], y[m], z[m],
                c=[cmap(i)], s=18, alpha=0.75, edgecolors="none",
                label=f"type {t}",
            )
        ax.legend(loc="upper right", fontsize=8)
    else:
        # single type: colour by z for depth perception
        ax.scatter(x, y, z, c=z, cmap="viridis", s=18, alpha=0.8, edgecolors="none")

    (xlo, xhi), (ylo, yhi), (zlo, zhi) = box
    ax.set_xlim(xlo, xhi)
    ax.set_ylim(ylo, yhi)
    ax.set_zlim(zlo, zhi)
    ax.set_xlabel("x")
    ax.set_ylabel("y")
    ax.set_zlabel("z")
    ax.set_title(f"LAMMPS riscv64 — step {timestep}   frame {idx + 1}/{total}")

    # slow azimuth sweep over the run for visual continuity
    ax.view_init(elev=20, azim=30 + (idx / max(1, total - 1)) * 60)

    plt.tight_layout()
    fig.savefig(out_png, dpi=100, bbox_inches="tight")
    plt.close(fig)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dump_file")
    ap.add_argument("--out", default="trajectory")
    ap.add_argument("--fps", type=int, default=4)
    ap.add_argument("--skip", type=int, default=1, help="render every Nth frame")
    ap.add_argument("--no-gif", action="store_true")
    ap.add_argument("--no-mp4", action="store_true")
    args = ap.parse_args()

    if not shutil.which("ffmpeg"):
        sys.exit("ERROR: ffmpeg not found in PATH")

    frames_dir = Path(f"{args.out}_frames")
    if frames_dir.exists():
        shutil.rmtree(frames_dir)
    frames_dir.mkdir(parents=True)

    frames = list(parse_dump(args.dump_file))[:: args.skip]
    n = len(frames)
    print(f"Rendering {n} frames from {args.dump_file}")
    for i, (ts, box, cols, data) in enumerate(frames):
        png = frames_dir / f"frame_{i:04d}.png"
        render_frame(ts, box, cols, data, png, i, n)
        print(f"  frame {i + 1}/{n}  step={ts}  atoms={len(data)}")

    if not args.no_mp4:
        mp4 = f"{args.out}.mp4"
        subprocess.run(
            [
                "ffmpeg", "-y", "-framerate", str(args.fps),
                "-i", str(frames_dir / "frame_%04d.png"),
                "-c:v", "libx264", "-pix_fmt", "yuv420p",
                "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2",
                mp4,
            ],
            check=True,
        )
        print(f"Wrote {mp4}")

    if not args.no_gif:
        gif = f"{args.out}.gif"
        palette = frames_dir / "palette.png"
        subprocess.run(
            [
                "ffmpeg", "-y", "-framerate", str(args.fps),
                "-i", str(frames_dir / "frame_%04d.png"),
                "-vf", f"fps={args.fps},scale=480:-1:flags=lanczos,palettegen",
                str(palette),
            ],
            check=True,
        )
        subprocess.run(
            [
                "ffmpeg", "-y", "-framerate", str(args.fps),
                "-i", str(frames_dir / "frame_%04d.png"),
                "-i", str(palette),
                "-filter_complex",
                f"fps={args.fps},scale=480:-1:flags=lanczos[x];[x][1:v]paletteuse",
                gif,
            ],
            check=True,
        )
        print(f"Wrote {gif}")


if __name__ == "__main__":
    main()
