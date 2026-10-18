#!/bin/sh
# Synthesize and pack only, printing the device utilisation nextpnr reports.
set -e
make -s build/tang_nano_9k/synth.json > /dev/null
nextpnr-himbaechel --json build/tang_nano_9k/synth.json --device GW1NR-LV9QN88PC6/I5 \
  --vopt family=GW1N-9C --vopt cst=boards/tang_nano_9k.cst \
  --pack-only 2>&1 | grep -E '^Info:\s+(LUT4|ALU|DFF|BSRAM):'
