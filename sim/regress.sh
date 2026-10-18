#!/bin/sh
# Build the Verilator model, play a scripted session (800 frames: start
# countdown, moving, eating, pause/unpause) and check every 25th frame.
#
#   sim/regress.sh [WORK_DIR]                 compare with sim/golden.sha256
#   sim/regress.sh WORK_DIR GOLDEN_DIR [N]    pixel diff against PPM frames,
#                                             NEW expected N pixels to the right
#   UPDATE=1 sim/regress.sh                   re-record sim/golden.sha256
set -e
WORK=${1:-build/sim/regress}
rm -rf "$WORK/obj" "$WORK/frames"; mkdir -p "$WORK/frames"
verilator --cc --exe --build -j 0 -O3 --x-assign fast --x-initial fast \
  --Mdir "$WORK/obj" --top-module sim_top -Wno-fatal -Wno-lint -Wno-style \
  -Wno-WIDTH -Wno-MULTIDRIVEN \
  rtl/game/*.sv rtl/top/*.sv rtl/io/gamepad.sv rtl/io/lcd_timing.sv \
  sim/sim_top.sv sim/headless.cpp > "$WORK/verilator.log" 2>&1 || { tail -20 "$WORK/verilator.log"; exit 1; }
"$WORK/obj/Vsim_top" --frames 801 --dump 25 --out "$WORK/frames/" \
  --press 250:0x04 --press 330:0x01 --press 420:0x08 --press 500:0x02 \
  --press 600:0x80 --press 610:0x00 --press 640:0x80 --press 650:0x04
if [ -n "$2" ]; then
  exec python3 sim/compare_frames.py "$2" "$WORK/frames" --shift "${3:-0}"
fi
(cd "$WORK/frames" && shasum -a 256 *.ppm) > "$WORK/frames.sha256"
if [ -n "$UPDATE" ]; then
  cp "$WORK/frames.sha256" sim/golden.sha256; echo "recorded sim/golden.sha256"; exit 0
fi
if diff -u sim/golden.sha256 "$WORK/frames.sha256"; then
  echo "regression: all $(wc -l < sim/golden.sha256 | tr -d ' ') frames match"
else
  echo "regression: frames differ (see above)"; exit 1
fi
