# Porting notes: DE10-Standard to Tang Nano

How the game moved from a Quartus project on a Cyclone V board to a cheap
Gowin FPGA built with open-source tools only. Each section covers what
changed, why it changed, and how we knew it still played the same. The
README covers how to build and play. This file covers how the port was done.

## Starting point and goals

The original is a university project for the Terasic DE10-Standard:
SystemVerilog game modules wired together in Quartus block diagrams (`.bdf`),
VGA output at 640×480, a PS/2 keypad for input, and sound through the board's
WM8731 codec. That version is kept unchanged on the `DE-10` branch.

The goals for the port:

1. Run on a Sipeed Tang Nano (9K, and later the 20K) with a 5" 800×480 RGB LCD.
2. Build with tools anyone can install for free: no Quartus, no Gowin IDE.
3. Keep the game logic as it was ("adapt", not "rewrite"), and prove it still
   behaves the same.
4. Play from a PC over the board's USB cable for now, with a handheld
   (Game Boy style) enclosure and real buttons planned for later.

## Toolchain

Everything comes from [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build)
(CI pins release `2026-10-18`):

| Step | Tool |
|---|---|
| SystemVerilog parsing | yosys-slang (`read_slang`). Yosys's built-in frontend can't handle the game's SV. |
| Synthesis | Yosys `synth_gowin` |
| Place and route | nextpnr-himbaechel, Gowin uarch |
| Bitstream | Apicula `gowin_pack` |
| Programming | openFPGALoader |
| Simulation | Verilator 5 (+ SDL2 for the playable window) |

The `Makefile` drives all of it: `make`, `make prog`, `make play`,
`make regress`, `make lint`. GitHub Actions builds both bitstreams and runs
the regression on every push.

## Structure of the port

**Schematics converted to SystemVerilog.** The Quartus top level and seven
sub-blocks were `.bdf` schematics. They were converted to plain modules
(`rtl/top/`) by tracing wire endpoints and net labels. The details that
mattered: parameter values set on schematic instances (ghost start positions,
sizes, colours written as untyped binary strings) had to be copied exactly,
and stale parameters that Quartus silently ignores had to be dropped.

**A board-independent core.** `pacman_core` takes a pixel position and
controls and returns an RGB332 colour. Everything board-specific sits outside
it: the PLL, the VGA/LCD timing, PS/2, audio, the 7-segment displays.
`boards/tang_nano/top.sv` wraps the core for both Tang boards (parameter
`TANG_20K`), and `sim/sim_top.sv` wraps it for Verilator.

**No frame buffer.** The game works out each pixel's colour as the screen
scans it (it "races the beam"), so the clock is the pixel clock. The LCD is
driven in DE mode at 896×517 total and 33.75 MHz, which gives 72.9 Hz, the
same frame rate the DE-10 ran VGA at (832×520 at 31.5 MHz). Game speed is
counted in frames, so matching the frame rate keeps movement speed the same.
The 640×480 game sits centred on the 800×480 panel with black side borders.

**Altera IP replaced.** `altsyncram` ROMs and `.mif` files became one
generic `rtl/game/rom.sv` that loads `assets/**/*.hex` with `$readmemh`
(`tools/mif2hex.py` did the conversion).

**Controller over UART.** The Tang's USB chip is both JTAG and a serial port.
`host/pad.py` (keyboard or game controller, auto-detects the board) sends a
1-byte button mask on every change and at least every 100 ms.
`rtl/io/uart_rx.sv` receives it, `rtl/io/gamepad.sv` maps it back to the
keypad codes the game expects (8/2/4/6 for the arrows, `*` `/` NumLock for
wall breaking, Start toggles pause), and the board releases every button
after 0.5 s of silence so a closed script can't leave Pac-Man stuck.

## How we knew it still played the same

Every change was checked against the original design, not against "looks
right":

- `sim/headless.cpp` runs the core in Verilator with scripted button presses
  and dumps frames. The golden run is 800 frames of play. Every 25th frame
  (33 in total) was recorded from the unmodified DE-10 RTL and is stored as
  hashes in `sim/golden.sha256`.
- `make regress` replays the script and compares hashes. Every change below
  was accepted only at 33/33.
- **One clock behind.** Moving the tile map into block RAM adds a clock of
  read latency. Instead of changing game logic to absorb it, `pacman_core`
  registers *all* of its inputs (scan position, controls, even reset
  release), while the RAM is addressed with the un-delayed position. The
  core then behaves as an exact one-clock-delayed copy of the original, so
  the frames stay bit-identical (shifted by one pixel, which the comparison
  accounts for).

## Making it fit the 9K

The GW1NR-9 has 8,640 LUT4s (adders and carry-chain cells count against the
same pool) and 26 block RAMs. In practice nextpnr needs usage below about
90% to place and route. The first open-source build needed about 13,200.

| Change | Why it was big |
|---|---|
| Tile map (32×32 tiles × 4 bits) moved from flip-flops to block RAM, with a write-first bypass and a separate read port for wall breaking | Thousands of flip-flops plus the multiplexers that read them |
| Digit, score text, Pac-Man and ghost bitmaps moved to registered block-RAM ROMs (`ram_style = "block"`, otherwise Yosys keeps small ROMs in LUTs) | Large constant lookup tables |
| Bounding-box test: one 12-bit subtractor per axis, with power-of-two sizes tested on the upper bits | Was several full-width compares per object |
| `pacman_move` positions and speeds as 16-bit signed instead of 32-bit `int` (values are pixels × 16, under 11k) | Halved every adder and comparator |
| `ghost_move` scratch variables given defaults (no latches), `minDist` sized to the actual distances | Removed latches and 32-bit compares |

Result: 8,414 LUTs (97%, doesn't place) → 7,819 (90%) → 7,605 (88%) after
registering object positions. All at 33/33.

## Making it fast enough

Fitting wasn't enough: the first 9K build that placed ran at 19 MHz, and the
LCD needs 33.75 MHz.

**Why not just lower the clock?** The design produces one pixel per clock,
so the clock *is* the pixel rate. Using the board's 27 MHz crystal directly
would give 58 Hz. The panel may accept that, but the game would run 20%
slower because speed is counted in frames, and 27 MHz was still above what
the 9K reached at the time.

**Why not tell the tool that some paths are slow?** Most of the game logic
(movement, ghost decisions) only matters once per frame. Normally you'd
declare those as multicycle paths, but nextpnr doesn't support multicycle
constraints. The open-source answer is to make the paths short in hardware:
add registers so each piece fits in one clock, and arrange the result to be
ready when it's needed.

What got it there:

1. **Registered object positions** (`pacman_move`, `ghost_move`). Positions
   only change during vertical blanking, so registering the `/16` scaling
   adds a clock of delay that nobody can see. 19 → 23 MHz.
2. **Synchronous resets everywhere in the core.** nextpnr times an
   asynchronous clear → Q as a combinational arc. Every path started at the
   reset synchronizer, ran through the core's reset register and a second
   asynchronous clear, then into game logic: about 12 ns of the 44 ns path.
   With synchronous resets that detour no longer exists. The board's reset
   synchronizer still asserts asynchronously and releases synchronously.
3. **Ghost steering split over four pipeline stages** (`ghost_move`). The
   chase/scatter decision (target tile → distance from each neighbouring
   tile → closest allowed direction) is only used on the `startOfFrame`
   clock, so it now runs over four registered steps that finish on that
   clock: target and neighbour tiles, per-axis distances, Manhattan sums,
   pairwise compares. The final pick from the compares is the same as the
   original running-minimum loop, including the random tie-break. Inky's
   random offset uses the LFSR value four clocks ahead, so it matches too.
   Trade-off: a button press that changes Pac-Man's direction in the last
   120 ns before a frame reaches Pinky's targeting a frame later.

Steps 2 and 3 together: **23 → 44.3 MHz on the 9K** at 7,749 LUTs (89%),
and 82 MHz on the 20K (37%). Still 33/33.

## Gotchas worth remembering

- yosys-slang flattens the design and has a loop unroll limit (raised to
  4000 for the map initialisation loops).
- Constructs Quartus accepts but Yosys rejects or mis-maps: an asynchronous
  reset that loads a variable instead of a constant (Gowin can only build
  this with latches), mixing blocking and non-blocking assignments to one
  variable, and 2-state `int` with a non-zero reset value.
- `dist` is a SystemVerilog keyword (randomisation constraints). Don't name
  a signal that.
- The PLL (`rPLL`) needs a blackbox declaration for simulation and lint
  (`boards/tang_nano/gowin_prims.sv`).
- nextpnr's LUT4 count includes ALUs and carry-chain filler, so it is higher
  than Yosys's `stat` (`tools/pack_count.sh` gets the real number quickly).
- macOS: the system USB-serial driver claims the board's JTAG interface, and
  `openFPGALoader` reports `FTDI reset failed` unless run with `sudo`. The
  UART shows up as the highest-numbered `/dev/cu.usbserial-*`.
- macOS file systems are case-insensitive by default: `RTL/` and `rtl/` are
  the same directory, so renaming one to the other needs an intermediate name.
- The playable simulator runs about 13 of the game's 73 frames per second.
  Verilator is the limit (one thread was fastest, LTO didn't help). A
  full-speed simulator would need a different approach.

## Status and open items

| Item | State |
|---|---|
| 9K and 20K bitstreams | Build, place and meet timing |
| Real hardware | Not tested on a board yet |
| Sound | Not ported. The DE-10 used its WM8731 codec; the 20K has an onboard amplifier. The 9K has little logic left for it. |
| Clyde | Inherited bug: an 11-bit distance compared to 128², so he never chases. Kept so the regression matches; fixing it means re-recording the golden run. |
| Enclosure | Planned: 3D-printed handheld with real buttons, design not started. |
| Branches | `DE-10` is the original. The port is on `tang-nano-9k` and becomes `main` after review. |
