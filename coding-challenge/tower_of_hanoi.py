#!/usr/bin/env python3
"""
Tower of Hanoi - LFX Mentorship Coding Challenge
=================================================
Broadening the RISC-V High Precision Code Base and Reach

Demonstrates both RECURSION and ITERATION to solve the classic
Tower of Hanoi puzzle, with simple ASCII graphics.

Author : Tanmay Gulhane
Program: Broadening the RISC-V High Precision Code Base and Reach
Date   : May 2026

Usage:
    python3 tower_of_hanoi.py          # recursive solver (default)
    python3 tower_of_hanoi.py -i       # iterative solver
"""

import time
import sys

NUM_DISKS  = 4
DELAY      = 0.3
PEG_LABELS = ['A', 'B', 'C']
PEG_HEIGHT = NUM_DISKS + 2
move_counter = 0


def draw_state(pegs, move_num, move_desc):
    n = NUM_DISKS
    width = (n * 2 + 3)
    peg_width = width + 4
    print(f"\n  Move {move_num:>3}:  {move_desc}")
    print("  " + "-" * (peg_width * 3))
    for row in range(PEG_HEIGHT, 0, -1):
        line = "  "
        for peg in pegs:
            slot_index = len(peg) - (PEG_HEIGHT - row + 1)
            if 0 <= slot_index < len(peg):
                size = peg[slot_index]
                disk_str = "#" * size
                disk_str = disk_str.center(width, '.' if size else ' ')
            else:
                disk_str = "|".center(width)
            line += disk_str.center(peg_width)
        print(line)
    print("  " + ("=" * width).center(peg_width) * 3)
    print("  " + "".join(label.center(peg_width) for label in PEG_LABELS))
    print()
    if DELAY > 0:
        time.sleep(DELAY)


# ================================================================
# RECURSIVE SOLUTION
# ----------------------------------------------------------------
# RECURSION: To move N disks from src to dst using aux as scratch:
#   1. Recursively move top (N-1) disks from src to aux
#   2. Move the largest disk from src to dst  (base action)
#   3. Recursively move (N-1) disks from aux to dst
#
# Base case: N == 0, do nothing and return.
# The call stack IS the algorithm's memory.
# ================================================================

def hanoi_recursive(n, src, dst, aux, pegs, depth=0):
    global move_counter

    # BASE CASE: nothing to move, unwind the call stack
    if n == 0:
        return

    # RECURSIVE STEP 1: move n-1 disks out of the way
    hanoi_recursive(n - 1, src, aux, dst, pegs, depth + 1)

    # ACTUAL MOVE: place disk n from src to dst
    disk = pegs[src].pop()
    pegs[dst].append(disk)
    move_counter += 1
    draw_state(pegs, move_counter,
               f"[Depth {depth}] Disk {disk} : {PEG_LABELS[src]} -> {PEG_LABELS[dst]}")

    # RECURSIVE STEP 2: place n-1 disks on top of disk n
    hanoi_recursive(n - 1, aux, dst, src, pegs, depth + 1)


# ================================================================
# ITERATIVE SOLUTION
# ----------------------------------------------------------------
# ITERATION: For N disks, exactly 2^N - 1 moves are required.
# Each step k encodes which disk moves via bit arithmetic:
#
#   disk that moves on step k = position of lowest set bit in k
#
# Direction is determined by parity of N - no recursion needed,
# just a single loop and bit operations.
# ================================================================

def hanoi_iterative(n, pegs):
    global move_counter
    total_moves = (1 << n) - 1

    # ITERATION: peg cycling order depends on parity of n
    cycle = [0, 2, 1] if n % 2 == 1 else [0, 1, 2]

    # ITERATION: single loop replaces all recursion
    for k in range(1, total_moves + 1):

        # Which disk moves? Lowest set bit of k
        step_index = (k // (k & -k)) % 3
        peg_a = cycle[step_index % 3]
        peg_b = cycle[(step_index + 1) % 3]

        # Pick the legal direction
        top_a = pegs[peg_a][-1] if pegs[peg_a] else float('inf')
        top_b = pegs[peg_b][-1] if pegs[peg_b] else float('inf')
        src, dst = (peg_a, peg_b) if top_a < top_b else (peg_b, peg_a)

        # Perform the move
        disk = pegs[src].pop()
        pegs[dst].append(disk)
        move_counter += 1
        draw_state(pegs, move_counter,
                   f"[Step {k}/{total_moves}] Disk {disk} : {PEG_LABELS[src]} -> {PEG_LABELS[dst]}")


def init_pegs(n):
    return [list(range(n, 0, -1)), [], []]


def main():
    n = NUM_DISKS
    print("=" * 60)
    print(f"   TOWER OF HANOI  -  {n} disks")
    print(f"   Optimal moves required: 2^{n} - 1 = {(1 << n) - 1}")
    print("=" * 60)

    mode = "recursive"
    if len(sys.argv) > 1 and sys.argv[1].lower() in ("iter", "iterative", "-i"):
        mode = "iterative"

    print(f"\n  Solver: {mode.upper()}\n")

    global move_counter
    move_counter = 0
    pegs = init_pegs(n)
    draw_state(pegs, 0, "Initial state")

    if mode == "recursive":
        hanoi_recursive(n, src=0, dst=2, aux=1, pegs=pegs)
    else:
        hanoi_iterative(n, pegs)

    print("=" * 60)
    print(f"   DONE! Completed in {move_counter} moves.")
    print(f"   All {n} disks are now on peg C.")
    print("=" * 60)
    assert pegs[2] == list(range(n, 0, -1)), "Verification FAILED!"
    print("   Solution verified correct.\n")


if __name__ == "__main__":
    main()
