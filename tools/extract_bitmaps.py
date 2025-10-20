"""
Simple extractor that pulls 8'h.. tokens for named bitmaps from the SV file
and writes a .mem file (one byte hex per line) suitable for $readmemh.
Usage (Windows PowerShell / cmd):
  python tools\extract_bitmaps.py ..\RTL\Bitmaps\sideBitMapV1.sv
"""
import re
import sys
from pathlib import Path

if len(sys.argv) < 2:
    print("Usage: python extract_bitmaps.py <sv-file>")
    sys.exit(1)

sv_path = Path(sys.argv[1])
text = sv_path.read_text()

# bitmap names to extract (adjust if you have different names)
names = ["start", "play", "win", "lose", "pause"]

# regex to find logic ... name = { ... };
for name in names:
    # find the initializer block for the name
    # match from "logic [0:63]... name = {", capture inside balanced braces using a simple approach:
    m = re.search(r"\b" + re.escape(name) + r"\s*=\s*\{(.*?)\}\s*;", text, re.S)
    if not m:
        print(f"WARNING: {name} initializer not found in {sv_path}")
        continue
    body = m.group(1)
    # find all 8'h?? tokens
    tokens = re.findall(r"8'h([0-9a-fA-F]{1,2})", body)
    if not tokens:
        print(f"WARNING: no hex tokens for {name}")
        continue
    # If tokens are grouped per row, flatten; write each byte on its own line (two hex digits)
    out = Path(sv_path.parent / f"{name}.mem")
    with out.open("w") as f:
        for t in tokens:
            f.write(t.zfill(2) + "\n")
    print(f"Wrote {out} ({len(tokens)} bytes)")

# basic sanity: each should have 64*64 = 4096 bytes
for name in names:
    p = sv_path.parent / f"{name}.mem"
    if p.exists():
        n = sum(1 for _ in p.open())
        if n != 4096:
            print(f"NOTE: {p} has {n} lines (expected 4096).")