# PacmanHDL

Pac-Man written in SystemVerilog: maze, four ghosts with their own chase
rules, power pellets, fruit and poison pickups, breakable walls, five levels.
Everything, including the picture, is computed in hardware as the screen is
scanned. There is no CPU and no frame buffer.

Originally a university project for the Terasic DE10-Standard (Cyclone V,
Quartus, VGA, PS/2 keypad). That version is preserved on the
[`DE-10`](../../tree/DE-10) branch. `main` targets Sipeed's Tang Nano boards
with a 5" 800×480 RGB LCD and builds with open-source tools only.

## Status

| Target | Fits | Timing (33.75 MHz) | |
|---|---|---|---|
| Tang Nano 20K (GW2AR-18) | 37% | 82 MHz, passes | roomy |
| Tang Nano 9K (GW1NR-9) | 89% | 44 MHz, passes | tight on logic |
| Simulator (Verilator + SDL2) | — | — | playable, ~13 fps (slow motion) |
| Browser (Verilator + WebAssembly) | — | — | playable, ~10 fps (slow motion) |

Not yet tested on real hardware. Sound is not ported yet: the DE-10 used its
WM8731 codec, and the 20K has an onboard amplifier to target.

How the port was done (fitting the 9K, closing timing, verification) is
written up in [docs/PORTING.md](docs/PORTING.md).

## Tools

Install [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build/releases)
(Yosys with the slang SystemVerilog frontend, nextpnr-himbaechel, Apicula,
openFPGALoader, Verilator) and put its `bin/` on your `PATH`. CI uses release
`2026-10-18`. The playable simulator also needs SDL2 (`brew install sdl2` /
`apt install libsdl2-dev`), and the controller script needs
[uv](https://docs.astral.sh/uv/).

## Build and program

```sh
make                              # Tang Nano 9K (default)
make BOARD=tang_nano_20k
make BOARD=tang_nano_20k prog     # load into SRAM
make BOARD=tang_nano_20k flash    # write to on-board flash
```

The bitstream is `build/<board>/pacman.fs`. On macOS the system USB-serial
driver claims the board's JTAG interface; if `openFPGALoader` reports
`FTDI reset failed`, run it with `sudo`.

## Play

The board takes input over the same USB cable that programs it:

```sh
uv run host/pad.py                # small window; keep it focused
```

| Keyboard | Game controller | Action |
|---|---|---|
| Arrows / WASD | D-pad / left stick | move |
| Z / Space | A | break wall, step 1 (`*` on the DE-10 keypad) |
| X | B | break wall, step 2 (`/`) |
| C | Select / Back | break wall, step 3 (NumLock) |
| Enter / P | Start | pause / resume |
| S2 button on the board | | next level |
| S1 button on the board | | reset |

Breakable walls appear once 5% of the coins are eaten and take the three keys
in order. The board LEDs mirror the held buttons, which helps when checking
the link.

No board? `make play` runs the same RTL in a window (R resets, N skips a
level). It runs at about 13 of the game's 73 frames per second, so the game
plays in slow motion.

## Play in the browser

`web/` compiles the same Verilator model to WebAssembly and runs it in a
static page: a Web Worker clocks `sim/sim_top.sv` one pixel at a time, samples
`rgb`/`de`/`vsync` into a canvas, and sends key presses as the same 8-button
mask the board receives. The keys match the table above, plus R (reset) and
N (next level).

Building it needs [emsdk](https://emscripten.org/docs/getting_started/downloads.html)
activated (`source emsdk_env.sh`) next to OSS CAD Suite:

```sh
make web                          # -> web/site/pacman.js + pacman.wasm
python3 web/serve.py              # http://localhost:8000
make web-bench                    # native build of the same harness, prints fps
```

The page is plain static files (`web/site/`), so GitHub Pages can host it.
`.github/workflows/pages.yml` builds and deploys it on pushes to `main` once
Pages is set to "GitHub Actions" in the repository settings. Photos of the
hardware go in `web/site/photos/` (the slots are marked in `index.html`).

Speed: about 10 of the game's 73 frames per second in Chrome on a laptop,
the same as the native build. Nothing is skipped, so the game plays in slow
motion. The web build compiles the model with `-O3`, since Verilator's
default `-Os` runs at half the speed.

## Layout

```
rtl/game/   game logic and graphics (from the DE-10 project)
rtl/top/    pacman_core + blocks converted from the Quartus schematics
rtl/io/     LCD timing, UART receiver, gamepad mapping
boards/     Tang Nano top level and pin constraints (9K, 20K)
assets/     ROM contents ($readmemh): maps, pickups, status icons
sim/        Verilator: playable SDL front end, headless regression
web/        browser build: WebAssembly harness and static page
host/       PC-side controller script
tools/      MIF -> hex, resource report, map generator helpers
docs/       porting notes
```

## Regression

`make regress` plays a scripted 800-frame session in Verilator and compares
every 25th frame against `sim/golden.sha256`. The golden run was recorded
from the original DE-10 design and verified pixel for pixel. Every change
made for the Tang port reproduces it exactly: the map moved to block RAM,
bitmaps moved to ROM, arithmetic was narrowed, resets became synchronous, and
the ghosts' direction choice was spread over four pipeline stages (it is only
needed once per frame). Re-record with
`UPDATE=1 sim/regress.sh` only for intentional gameplay changes.

## Known quirks inherited from the DE-10 version

- Clyde's "chase when far, retreat when near" rule compares an 11-bit
  distance against 128², which is never true, so Clyde always heads to his
  corner (`rtl/game/ghost_move.sv`).
- Turbo mode and the 7-segment timer display were DE-10 extras and are not
  wired up.
