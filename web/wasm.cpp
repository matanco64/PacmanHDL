// Browser build of the simulator: the same Verilator model as sim/play.cpp,
// driven one frame per call from JavaScript instead of an SDL loop.
//
// Rows whose outcome is known from the previous frame are replayed instead of
// clocked (web/scanff.h); pw_set_fastforward(0) clocks every row.
//
// Built natively (make web-bench) it runs a fixed number of frames and prints
// the speed, which is the quickest way to check a change before building WASM.
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

#include "scanff.h"
#include "verilated.h"

#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#define EXPORT extern "C" EMSCRIPTEN_KEEPALIVE
// The Verilator runtime references CPU-affinity calls that Emscripten lacks.
// The model is single-threaded, so report "not supported" if they are reached.
#include <pthread.h>
#include <sched.h>
extern "C" int pthread_getaffinity_np(pthread_t, size_t, cpu_set_t*) { return 38; /* ENOSYS */ }
extern "C" int pthread_setaffinity_np(pthread_t, size_t, const cpu_set_t*) { return 38; }
extern "C" int sched_getcpu() { return 0; }
#else
#define EXPORT extern "C"
#endif

namespace {
scanff::Runner* run;
}

EXPORT void pw_init() { run = new scanff::Runner; }
EXPORT void pw_reset() { run->reset(); }

// buttons: gamepad mask, see rtl/io/gamepad.sv. levelKeyN: onboard S2, active low.
EXPORT void pw_set_inputs(int buttons, int levelKeyN) { run->setInputs(buttons, levelKeyN); }

// Runs the design until the LCD timing ends a frame; returns the RGBA framebuffer.
EXPORT uint32_t* pw_run_frame() { return run->runFrame(); }

EXPORT double pw_cycles() { return run->cycles; }

// 1: replay rows known from the previous frame (default), 0: clock every row
EXPORT void pw_set_fastforward(int on) { run->ff = on != 0; }

// share of active rows replayed instead of clocked since the last call
EXPORT double pw_take_skip_ratio() {
  long s = run->rowsSkipped, c = run->rowsClocked;
  run->rowsSkipped = run->rowsClocked = 0;
  return s + c ? double(s) / double(s + c) : 0.0;
}

#ifndef WEB_SCALE
#define WEB_SCALE 1
#endif
// Frames per game-second this build is tuned for (73 on the board).
EXPORT double pw_game_fps() { return 23369344.0 / WEB_SCALE / (656.0 * 488.0); }

#ifndef __EMSCRIPTEN__
int main(int argc, char** argv) {
  int frames = argc > 1 ? std::atoi(argv[1]) : 300;
  pw_init();
  if (argc > 2) pw_set_fastforward(std::atoi(argv[2]));
  auto t0 = std::chrono::steady_clock::now();
  for (int f = 0; f < frames; ++f) {
    pw_set_inputs(f >= 100 ? 0x08 : 0, 1);  // hold right after the start countdown
    pw_run_frame();
  }
  double s = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
  std::printf("%d frames in %.2fs: %.1f fps, %.0f%% of rows replayed\n", frames, s, frames / s,
              100.0 * pw_take_skip_ratio());
  return 0;
}
#endif
