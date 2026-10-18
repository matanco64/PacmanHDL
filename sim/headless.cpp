// Headless Verilator run: plays a scripted button sequence and writes frames
// as PPM images, for regression-checking changes to the game RTL.
//
//   obj_dir/Vsim_top --frames 400 --dump 50 --out frames/ --press 300:0x08 --press 330:0x00
//
// --press FRAME:MASK sets the gamepad mask from that frame on.
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <map>
#include <string>
#include <vector>

#include "Vsim_top.h"
#include "verilated.h"

static constexpr int W = 800, H = 480;

static void writePpm(const std::string& path, const std::vector<uint8_t>& fb) {
  FILE* f = std::fopen(path.c_str(), "wb");
  if (!f) { std::perror(path.c_str()); std::exit(1); }
  std::fprintf(f, "P6\n%d %d\n255\n", W, H);
  for (uint8_t p : fb) {
    uint8_t r = (p >> 5) & 7, g = (p >> 2) & 7, b = p & 3;
    uint8_t rgb[3] = {uint8_t(r * 255 / 7), uint8_t(g * 255 / 7), uint8_t(b * 255 / 3)};
    std::fwrite(rgb, 1, 3, f);
  }
  std::fclose(f);
}

int main(int argc, char** argv) {
  int frames = 300, dumpEvery = 50;
  std::string out = "frames/";
  std::map<int, uint8_t> presses;
  for (int i = 1; i < argc; ++i) {
    if (!std::strcmp(argv[i], "--frames") && i + 1 < argc) frames = std::atoi(argv[++i]);
    else if (!std::strcmp(argv[i], "--dump") && i + 1 < argc) dumpEvery = std::atoi(argv[++i]);
    else if (!std::strcmp(argv[i], "--out") && i + 1 < argc) out = argv[++i];
    else if (!std::strcmp(argv[i], "--press") && i + 1 < argc) {
      int frame; unsigned mask;
      if (std::sscanf(argv[++i], "%d:%x", &frame, &mask) != 2) { std::fprintf(stderr, "bad --press\n"); return 1; }
      presses[frame] = uint8_t(mask);
    }
  }

  Vsim_top top;
  top.buttons = 0;
  top.levelKeyN = 1;
  top.resetN = 0;
  top.clk = 0;
  for (int i = 0; i < 32; ++i) { top.clk ^= 1; top.eval(); }  // hold reset for 16 clocks
  top.resetN = 1;

  std::vector<uint8_t> fb(W * H);
  int x = 0, y = 0, frame = 0;
  bool prevVsync = true, prevDe = false;
  while (frame < frames) {
    top.clk = 1; top.eval();
    if (top.de) {
      if (x < W && y < H) fb[y * W + x] = top.rgb;
      ++x;
    } else if (prevDe) {
      x = 0; ++y;
    }
    prevDe = top.de;
    if (!top.vsync && prevVsync) {          // end of a frame
      if (dumpEvery && frame % dumpEvery == 0) {
        char name[32];
        std::snprintf(name, sizeof name, "f%04d.ppm", frame);
        writePpm(out + name, fb);
      }
      ++frame; y = 0;
      auto it = presses.find(frame);
      if (it != presses.end()) top.buttons = it->second;
    }
    prevVsync = top.vsync;
    top.clk = 0; top.eval();
  }
  return 0;
}
