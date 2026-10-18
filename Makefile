# Open-source build for the Tang Nano 9K (Yosys + nextpnr-himbaechel + Apicula).
# Tools: OSS CAD Suite (https://github.com/YosysHQ/oss-cad-suite-build) on PATH.
#
#   make          synthesize, place & route, pack bitstream
#   make prog     load into SRAM (lost on power-off)
#   make flash    write to on-board flash
#   make lint     Verilator lint of the whole design

BOARD   := tang_nano_9k
DEVICE  := GW1NR-LV9QN88PC6/I5
FAMILY  := GW1N-9C
TOP     := top
BUILD   := build

CORE_SRC  := $(wildcard rtl/game/*.sv) $(wildcard rtl/top/*.sv)
IO_SRC    := rtl/io/gamepad.sv rtl/io/uart_rx.sv rtl/io/lcd_timing.sv
BOARD_SRC := boards/$(BOARD)/top.sv boards/$(BOARD)/gowin_prims.sv
SRC       := $(CORE_SRC) $(IO_SRC) $(BOARD_SRC)
CST       := boards/$(BOARD)/$(BOARD).cst

all: $(BUILD)/$(BOARD).fs

$(BUILD)/$(BOARD).json: $(SRC) $(wildcard assets/*/*.hex)
	@mkdir -p $(BUILD)
	yosys -m slang -l $(BUILD)/yosys.log -p "\
	  read_slang --top $(TOP) $(SRC); \
	  synth_gowin -top $(TOP) -json $@"

$(BUILD)/$(BOARD)_pnr.json: $(BUILD)/$(BOARD).json $(CST)
	nextpnr-himbaechel -l $(BUILD)/nextpnr.log --json $< --write $@ \
	  --device $(DEVICE) --vopt family=$(FAMILY) --vopt cst=$(CST) \
	  --freq 33.75

$(BUILD)/$(BOARD).fs: $(BUILD)/$(BOARD)_pnr.json
	gowin_pack -d $(FAMILY) -o $@ $<

prog: $(BUILD)/$(BOARD).fs
	openFPGALoader -b tangnano9k $<

flash: $(BUILD)/$(BOARD).fs
	openFPGALoader -b tangnano9k -f $<

lint:
	verilator --lint-only -Wall -Wno-fatal --top-module pacman_core $(CORE_SRC)

clean:
	rm -rf $(BUILD)

.PHONY: all prog flash lint clean
