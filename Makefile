# Open-source build for PacmanHDL (Yosys + nextpnr-himbaechel + Apicula).
# Tools: OSS CAD Suite (https://github.com/YosysHQ/oss-cad-suite-build) on PATH.
#
#   make [BOARD=tang_nano_9k|tang_nano_20k]   bitstream in build/<board>/
#   make prog / make flash                    load into SRAM / write to flash
#   make play                                 play the RTL in a window (Verilator + SDL2)
#   make web                                  browser build in web/site (Verilator + Emscripten)
#   make ffverify                             check the browser build's scan fast-forward
#   make regress                              compare against the recorded golden run
#   make lint                                 Verilator lint

BOARD ?= tang_nano_9k

ifeq ($(BOARD),tang_nano_9k)
  DEVICE   := GW1NR-LV9QN88PC6/I5
  FAMILY   := GW1N-9C
  TANG_20K := 0
  LOADER   := tangnano9k
else ifeq ($(BOARD),tang_nano_20k)
  DEVICE   := GW2AR-LV18QN88C8/I7
  FAMILY   := GW2A-18C
  TANG_20K := 1
  LOADER   := tangnano20k
else
  $(error unknown BOARD=$(BOARD))
endif

BUILD     := build/$(BOARD)
CORE_SRC  := $(wildcard rtl/game/*.sv) $(wildcard rtl/top/*.sv)
IO_SRC    := rtl/io/gamepad.sv rtl/io/uart_rx.sv rtl/io/lcd_timing.sv
BOARD_SRC := boards/tang_nano/top.sv boards/tang_nano/gowin_prims.sv
SRC       := $(CORE_SRC) $(IO_SRC) $(BOARD_SRC)
CST       := boards/$(BOARD).cst
ASSETS    := $(wildcard assets/*/*.hex)

all: $(BUILD)/pacman.fs

$(BUILD)/synth.json: $(SRC) $(ASSETS)
	@mkdir -p $(BUILD)
	yosys -m slang -l $(BUILD)/yosys.log -q -p "\
	  read_slang --top top -G TANG_20K=$(TANG_20K) $(SRC); \
	  synth_gowin -top top -json $@"
	@python3 tools/resources.py $(BUILD)/yosys.log

$(BUILD)/pnr.json: $(BUILD)/synth.json $(CST)
	nextpnr-himbaechel -q -l $(BUILD)/nextpnr.log --json $< --write $@ \
	  --device $(DEVICE) --vopt family=$(FAMILY) --vopt cst=$(CST) \
	  --freq 33.75 --report $(BUILD)/timing.json
	@grep -E 'LUT4:|Max frequency' $(BUILD)/nextpnr.log | tail -2

$(BUILD)/pacman.fs: $(BUILD)/pnr.json
	gowin_pack -d $(FAMILY) -o $@ $<

prog: $(BUILD)/pacman.fs
	openFPGALoader -b $(LOADER) $<

flash: $(BUILD)/pacman.fs
	openFPGALoader -b $(LOADER) -f $<

# ---------------------------------------------------------------- simulation
VERILATOR_FLAGS := --cc --exe --build -j 0 -O3 --x-assign fast --x-initial fast \
  --top-module sim_top -Wno-fatal -Wno-lint -Wno-style -Wno-WIDTH -Wno-MULTIDRIVEN
SIM_SRC := $(CORE_SRC) rtl/io/gamepad.sv rtl/io/lcd_timing.sv sim/sim_top.sv
# compact raster for interactive play: 656 x 488, and CLK_HZ chosen so the
# game's one-second timer is still 73 frames, as on the board
COMPACT := -GH_ACT=640 -GH_FRONT=4 -GH_SYNC=4 -GH_BACK=8 \
  -GV_FRONT=2 -GV_SYNC=2 -GV_BACK=4 -GCLK_HZ=23369344

build/sim/play/Vsim_top: $(SIM_SRC) sim/play.cpp $(ASSETS)
	@mkdir -p build/sim/play
	verilator $(VERILATOR_FLAGS) $(COMPACT) --Mdir build/sim/play \
	  -CFLAGS "$(shell sdl2-config --cflags)" -LDFLAGS "$(shell sdl2-config --libs)" \
	  $(SIM_SRC) sim/play.cpp

play: build/sim/play/Vsim_top
	$<

# Browser build: the same model compiled to WebAssembly (needs emsdk's em++ on PATH).
# OPT_FAST=-O3: Verilator compiles the model with -Os by default, which halves the speed.
# -fno-dfg: Verilator's DFG pass slows this design (9% native, ~4% in WASM; output
# unchanged, make regress passes with it).
# CFG_LDLIBS_THREADS: the model is single-threaded, so drop -pthread/-latomic.
# UNAME_S=Emscripten: on a macOS host verilated.mk adds ld64-only -Wl,-U flags that wasm-ld rejects.
# The ROM images are embedded at the paths the RTL's $$readmemh calls use.
# WEB_SCALE=N moves Pac-Man and the ghosts N pixels per frame instead of 1 and
# shortens the game-second to 73/N frames (CLK_HZ / N), so the browser needs N
# times fewer frames for the same game time. N must divide the 16-px tile: 1, 2
# or 4. 2 is the default (36.5 frames per game-second); WEB_SCALE=1 is the
# board's exact timing, which make regress checks.
WEB_SCALE ?= 2
WEB_CLK := $(shell expr 23369344 / $(WEB_SCALE))
WEB_SIM := $(COMPACT) -GCLK_HZ=$(WEB_CLK) +define+SPEED_SCALE=$(WEB_SCALE) \
  -fno-dfg -CFLAGS -DWEB_SCALE=$(WEB_SCALE) -CFLAGS -DFF_SEC=$(WEB_CLK)
WEB_EXPORTS := _pw_init,_pw_reset,_pw_set_inputs,_pw_run_frame,_pw_cycles,_pw_game_fps
WEB_EXPORTS := $(WEB_EXPORTS),_pw_set_fastforward,_pw_take_skip_ratio
WEB_LDFLAGS := -O3 -sMODULARIZE=1 -sEXPORT_NAME=createPacman -sENVIRONMENT=worker \
  -sALLOW_MEMORY_GROWTH=1 -sEXPORTED_FUNCTIONS=$(WEB_EXPORTS) -sEXPORTED_RUNTIME_METHODS=HEAPU8 \
  --embed-file $(CURDIR)/assets@/assets
WEB_MAKEFLAGS := CXX=em++ LINK=em++ AR=emar OPT_FAST=-O3 CFG_LDLIBS_THREADS= UNAME_S=Emscripten
# The scan fast-forward (web/scanff.h) reads the model's members directly, so the
# web builds verilate first, list the members of the generated root class into
# fields.inc, and then compile.
WEB_HDRS := web/scanff.h
VERILATE := verilator $(filter-out --build,$(VERILATOR_FLAGS)) $(WEB_SIM)
FIELDS = awk '/^ *::[A-Za-z]/ && !/static/ && !/\(/ && /;$$/ { n=$$NF; sub(/;$$/,"",n); print "F(" n ")" }' \
  $(1)/Vsim_top___024root.h > $(1)/fields.inc
NPROC := $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

web/site/pacman.js: $(SIM_SRC) web/wasm.cpp $(WEB_HDRS) $(ASSETS)
	@mkdir -p build/sim/web
	$(VERILATE) --Mdir build/sim/web -o pacman.js -CFLAGS "-I$(CURDIR)/web -I$(CURDIR)/build/sim/web" \
	  -LDFLAGS "$(WEB_LDFLAGS)" $(SIM_SRC) web/wasm.cpp
	$(call FIELDS,build/sim/web)
	$(MAKE) -C build/sim/web -f Vsim_top.mk -j$(NPROC) $(WEB_MAKEFLAGS)
	cp build/sim/web/pacman.js build/sim/web/pacman.wasm web/site/

web: web/site/pacman.js

# native build of the browser harness: prints how fast the model runs
web-bench: $(SIM_SRC) web/wasm.cpp $(WEB_HDRS) $(ASSETS)
	@mkdir -p build/sim/bench
	$(VERILATE) --Mdir build/sim/bench -o bench -CFLAGS "-I$(CURDIR)/web -I$(CURDIR)/build/sim/bench" \
	  $(SIM_SRC) web/wasm.cpp
	$(call FIELDS,build/sim/bench)
	$(MAKE) -C build/sim/bench -f Vsim_top.mk -j$(NPROC) OPT_FAST=-O3
	build/sim/bench/bench 300 0
	build/sim/bench/bench 300 1

# runs a fully clocked model beside a fast-forwarded one and compares every
# register and pixel of every frame: make ffverify [FF_FRAMES=n] [FF_SEED=n]
FF_FRAMES ?= 3000
FF_SEED ?= 1
build/sim/ffverify/ffverify: $(SIM_SRC) web/ffverify.cpp $(WEB_HDRS) $(ASSETS)
	@mkdir -p build/sim/ffverify
	$(VERILATE) --Mdir build/sim/ffverify -o ffverify \
	  -CFLAGS "-I$(CURDIR)/web -I$(CURDIR)/build/sim/ffverify" $(SIM_SRC) web/ffverify.cpp
	$(call FIELDS,build/sim/ffverify)
	$(MAKE) -C build/sim/ffverify -f Vsim_top.mk -j$(NPROC) OPT_FAST=-O3

ffverify: build/sim/ffverify/ffverify
	$< $(FF_FRAMES) $(FF_SEED)

regress:
	sim/regress.sh build/sim/regress

lint:
	verilator --lint-only -Wall -Wno-fatal --top-module sim_top $(SIM_SRC)

clean:
	rm -rf build

.PHONY: all prog flash play web web-bench ffverify regress lint clean
