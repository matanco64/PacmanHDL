# Open-source build for PacmanHDL (Yosys + nextpnr-himbaechel + Apicula).
# Tools: OSS CAD Suite (https://github.com/YosysHQ/oss-cad-suite-build) on PATH.
#
#   make [BOARD=tang_nano_9k|tang_nano_20k]   bitstream in build/<board>/
#   make prog / make flash                    load into SRAM / write to flash
#   make play                                 play the RTL in a window (Verilator + SDL2)
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

regress:
	sim/regress.sh build/sim/regress

lint:
	verilator --lint-only -Wall -Wno-fatal --top-module sim_top $(SIM_SRC)

clean:
	rm -rf build

.PHONY: all prog flash play regress lint clean
