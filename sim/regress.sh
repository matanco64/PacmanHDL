#!/bin/sh
# Build the Verilator model, play the scripted session and compare against
# golden frames:  sim/regress.sh GOLDEN_DIR WORK_DIR [SHIFT]
set -e
GOLDEN=$1; WORK=$2; SHIFT=${3:-1}
rm -rf "$WORK/obj" "$WORK/frames"; mkdir -p "$WORK/frames"
verilator --cc --exe --build -j 8 -O3 --x-assign fast --x-initial fast \
  --Mdir "$WORK/obj" --top-module sim_top -Wno-fatal -Wno-lint -Wno-style \
  -Wno-WIDTH -Wno-MULTIDRIVEN \
  rtl/game/*.sv rtl/top/*.sv rtl/io/gamepad.sv rtl/io/lcd_timing.sv \
  sim/sim_top.sv sim/headless.cpp > "$WORK/verilator.log" 2>&1 || { tail -20 "$WORK/verilator.log"; exit 1; }
"$WORK/obj/Vsim_top" --frames 801 --dump 25 --out "$WORK/frames/" \
  --press 250:0x04 --press 330:0x01 --press 420:0x08 --press 500:0x02 \
  --press 600:0x80 --press 610:0x00 --press 640:0x80 --press 650:0x04
python3 sim/compare_frames.py "$GOLDEN" "$WORK/frames" --shift "$SHIFT"
