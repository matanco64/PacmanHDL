#!/usr/bin/env python3
"""Summarize Gowin resource use from a Yosys log (last `stat` of the top module)."""
import re, sys

LIMITS = {'LUT+ALU': 8640, 'FF': 6480, 'BSRAM': 26}  # GW1NR-9

log = open(sys.argv[1] if len(sys.argv) > 1 else 'build/yosys.log').read()
stat = log[log.rfind('=== top ==='):]
stat = stat[:stat.find('\n===')]  # just this module, not the repeated hierarchy table

def count(pattern):
    return sum(int(n) for n in re.findall(r'^\s+(\d+)\s+(?:' + pattern + r')\s*$', stat, re.M))

used = {
    'LUT+ALU': count(r'LUT[1-4]') + count(r'ALU'),
    'FF': count(r'DFF\w*'),
    'BSRAM': count(r'SP|SPX9|SDPB|SDPX9B|DPB|DPX9B|pROM|pROMX9'),
}
for k, v in used.items():
    print(f'{k:8s} {v:6d} / {LIMITS[k]:5d}  {100 * v / LIMITS[k]:5.1f}%')
print(f'(LUT {count(r"LUT[1-4]")}, ALU {count(r"ALU")}, MUX2 {count(r"MUX2_LUT[5-8]")}, MULT {count(r"MULT\w+")})')
