#!/usr/bin/env python3
"""Compare two directories of PPM frames from sim/headless.cpp.

  compare_frames.py GOLDEN_DIR NEW_DIR [--shift N]

--shift N: NEW is expected to be GOLDEN moved N pixels to the right (N extra
clocks of pipeline latency). Only the game window (x 80..719) is compared.
"""
import os, sys

def load(path):
    data = open(path, 'rb').read()
    parts = data.split(b'\n', 3)
    w, h = map(int, parts[1].split())
    return w, h, parts[3]

def main():
    args = sys.argv[1:]
    shift = 0
    if '--shift' in args:
        i = args.index('--shift'); shift = int(args[i + 1]); del args[i:i + 2]
    gold, new = args
    names = sorted(f for f in os.listdir(gold) if f.endswith('.ppm'))
    bad = 0
    for n in names:
        if not os.path.exists(os.path.join(new, n)):
            print(f'{n}: missing'); bad += 1; continue
        w, h, a = load(os.path.join(gold, n))
        _, _, b = load(os.path.join(new, n))
        diffs, first = 0, None
        for y in range(h):
            for x in range(80 + shift, 720):
                pa = a[(y * w + x - shift) * 3:(y * w + x - shift) * 3 + 3]
                pb = b[(y * w + x) * 3:(y * w + x) * 3 + 3]
                if pa != pb:
                    diffs += 1
                    first = first or (x, y)
        print(f'{n}: {"OK" if not diffs else f"{diffs} pixels differ, first at {first}"}')
        bad += bool(diffs)
    print(f'{len(names) - bad}/{len(names)} frames match')
    sys.exit(1 if bad else 0)

main()
