// Browser build of the simulator: the same Verilator model as sim/play.cpp,
// driven one frame per call from JavaScript instead of an SDL loop.
//
// Built natively (make web-bench) it runs a fixed number of frames and prints
// the speed, which is the quickest way to check a change before building WASM.
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

#include "Vsim_top.h"
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

constexpr int W = 640, H = 480;
Vsim_top* top;
uint32_t fb[W * H];  // RGBA bytes, ready for ImageData
uint32_t palette[256];
int x, y;
bool prevVsync = true, prevDe;
double cycles;

}  // namespace

EXPORT void pw_reset() {
  top->resetN = 0;
  for (int i = 0; i < 32; ++i) { top->clk ^= 1; top->eval(); }
  top->resetN = 1;
}

EXPORT void pw_init() {
  for (int p = 0; p < 256; ++p) {
    uint32_t r = ((p >> 5) & 7) * 255 / 7, g = ((p >> 2) & 7) * 255 / 7, b = (p & 3) * 255 / 3;
    palette[p] = 0xff000000u | b << 16 | g << 8 | r;
  }
  top = new Vsim_top;
  top->clk = 0;
  top->buttons = 0;
  top->levelKeyN = 1;
  pw_reset();
}

// buttons: gamepad mask, see rtl/io/gamepad.sv. levelKeyN: onboard S2, active low.
EXPORT void pw_set_inputs(int buttons, int levelKeyN) {
  top->buttons = buttons;
  top->levelKeyN = levelKeyN;
}

// Clocks the design until the LCD timing ends a frame; returns the framebuffer.
EXPORT uint32_t* pw_run_frame() {
  for (;;) {
    top->clk = 1; top->eval();
    ++cycles;
    if (top->de) {
      if (x < W && y < H) fb[y * W + x] = palette[top->rgb];
      ++x;
    } else if (prevDe) {
      x = 0; ++y;
    }
    prevDe = top->de;
    bool frameDone = !top->vsync && prevVsync;
    prevVsync = top->vsync;
    top->clk = 0; top->eval();
    if (frameDone) { y = 0; return fb; }
  }
}

EXPORT double pw_cycles() { return cycles; }

#ifndef WEB_SCALE
#define WEB_SCALE 1
#endif
// Frames per game-second this build is tuned for (73 on the board).
EXPORT double pw_game_fps() { return 23369344.0 / WEB_SCALE / (656.0 * 488.0); }

#ifndef __EMSCRIPTEN__
int main(int argc, char** argv) {
  int frames = argc > 1 ? std::atoi(argv[1]) : 300;
  pw_init();
  auto t0 = std::chrono::steady_clock::now();
  for (int f = 0; f < frames; ++f) {
    pw_set_inputs(f >= 100 ? 0x08 : 0, 1);  // hold right after the start countdown
    pw_run_frame();
  }
  double s = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
  std::printf("%d frames in %.2fs: %.1f fps, %.2f Mcycles/s\n", frames, s, frames / s, cycles / s / 1e6);
  return 0;
}
#endif
