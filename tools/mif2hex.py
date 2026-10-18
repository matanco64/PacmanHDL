#!/usr/bin/env python3
"""Convert an Altera .mif (hex radix) to a $readmemh file, one word per line."""
import re, sys

src, dst = sys.argv[1], sys.argv[2]
text = open(src).read()
depth = int(re.search(r'DEPTH\s*=\s*(\d+)', text).group(1))
assert re.search(r'ADDRESS_RADIX\s*=\s*HEX', text) and re.search(r'DATA_RADIX\s*=\s*HEX', text)
words = ['0'] * depth
body = text.split('BEGIN', 1)[1].split('END', 1)[0]
for line in body.splitlines():
    line = line.split('--')[0].strip()
    m = re.match(r'([0-9A-Fa-f]+)\s*:\s*([0-9A-Fa-f]+)\s*;', line)
    if m: words[int(m.group(1), 16)] = m.group(2).lower()
    elif line: sys.exit(f'{src}: unsupported line {line!r}')
open(dst, 'w').write('\n'.join(words) + '\n')
