// Play the real game RTL in a window: Verilator model + SDL2.
//
//   Arrows / WASD   move            Z / Space   A  (wall-break key 1, "*")
//   Enter / P       Start (pause)   X           B  (wall-break key 2, "/")
//   N               next level (S2) C           Select (wall-break key 3, NumLock)
//   R               reset (S1)      Esc         quit
//
// A game controller (Xbox / PlayStation / Switch layout via SDL) works too.
// The button mask is the same one the board receives over UART.
#include <SDL.h>

#include <chrono>
#include <cstdio>
#include <vector>

#include "Vsim_top.h"
#include "verilated.h"

namespace {

constexpr int W = 640, H = 480, SCALE = 2;

enum : uint8_t {  // rtl/io/gamepad.sv
  BTN_UP = 1 << 0, BTN_DOWN = 1 << 1, BTN_LEFT = 1 << 2, BTN_RIGHT = 1 << 3,
  BTN_A = 1 << 4, BTN_B = 1 << 5, BTN_SELECT = 1 << 6, BTN_START = 1 << 7,
};

uint8_t keyboardMask(const uint8_t* k) {
  uint8_t m = 0;
  if (k[SDL_SCANCODE_UP] || k[SDL_SCANCODE_W]) m |= BTN_UP;
  if (k[SDL_SCANCODE_DOWN] || k[SDL_SCANCODE_S]) m |= BTN_DOWN;
  if (k[SDL_SCANCODE_LEFT] || k[SDL_SCANCODE_A]) m |= BTN_LEFT;
  if (k[SDL_SCANCODE_RIGHT] || k[SDL_SCANCODE_D]) m |= BTN_RIGHT;
  if (k[SDL_SCANCODE_Z] || k[SDL_SCANCODE_SPACE]) m |= BTN_A;
  if (k[SDL_SCANCODE_X]) m |= BTN_B;
  if (k[SDL_SCANCODE_C]) m |= BTN_SELECT;
  if (k[SDL_SCANCODE_RETURN] || k[SDL_SCANCODE_P]) m |= BTN_START;
  return m;
}

uint8_t controllerMask(SDL_GameController* c) {
  if (!c) return 0;
  auto b = [c](SDL_GameControllerButton x) { return SDL_GameControllerGetButton(c, x) != 0; };
  auto axis = [c](SDL_GameControllerAxis x) { return SDL_GameControllerGetAxis(c, x); };
  uint8_t m = 0;
  if (b(SDL_CONTROLLER_BUTTON_DPAD_UP) || axis(SDL_CONTROLLER_AXIS_LEFTY) < -16000) m |= BTN_UP;
  if (b(SDL_CONTROLLER_BUTTON_DPAD_DOWN) || axis(SDL_CONTROLLER_AXIS_LEFTY) > 16000) m |= BTN_DOWN;
  if (b(SDL_CONTROLLER_BUTTON_DPAD_LEFT) || axis(SDL_CONTROLLER_AXIS_LEFTX) < -16000) m |= BTN_LEFT;
  if (b(SDL_CONTROLLER_BUTTON_DPAD_RIGHT) || axis(SDL_CONTROLLER_AXIS_LEFTX) > 16000) m |= BTN_RIGHT;
  if (b(SDL_CONTROLLER_BUTTON_A)) m |= BTN_A;
  if (b(SDL_CONTROLLER_BUTTON_B)) m |= BTN_B;
  if (b(SDL_CONTROLLER_BUTTON_BACK) || b(SDL_CONTROLLER_BUTTON_X)) m |= BTN_SELECT;
  if (b(SDL_CONTROLLER_BUTTON_START)) m |= BTN_START;
  return m;
}

uint32_t rgb332ToArgb(uint8_t p) {
  uint32_t r = ((p >> 5) & 7) * 255 / 7, g = ((p >> 2) & 7) * 255 / 7, b = (p & 3) * 255 / 3;
  return 0xff000000u | r << 16 | g << 8 | b;
}

}  // namespace

int main(int argc, char** argv) {
  Verilated::commandArgs(argc, argv);
  if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER) != 0) {
    std::fprintf(stderr, "SDL_Init: %s\n", SDL_GetError());
    return 1;
  }
  SDL_Window* win = SDL_CreateWindow("PacmanHDL (simulated RTL)", SDL_WINDOWPOS_CENTERED,
                                     SDL_WINDOWPOS_CENTERED, W * SCALE, H * SCALE, 0);
  SDL_Renderer* ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_PRESENTVSYNC);
  SDL_Texture* tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, W, H);
  SDL_GameController* pad = nullptr;

  Vsim_top top;
  auto reset = [&top] {
    top.resetN = 0;
    for (int i = 0; i < 32; ++i) { top.clk ^= 1; top.eval(); }
    top.resetN = 1;
  };
  top.clk = 0;
  top.buttons = 0;
  top.levelKeyN = 1;
  reset();

  std::vector<uint32_t> fb(W * H);
  int x = 0, y = 0, frames = 0;
  bool prevVsync = true, prevDe = false, running = true;
  auto t0 = std::chrono::steady_clock::now();

  while (running) {
    top.clk = 1; top.eval();
    if (top.de) {
      if (x < W && y < H) fb[y * W + x] = rgb332ToArgb(top.rgb);
      ++x;
    } else if (prevDe) {
      x = 0; ++y;
    }
    prevDe = top.de;
    bool frameDone = !top.vsync && prevVsync;
    prevVsync = top.vsync;
    top.clk = 0; top.eval();
    if (!frameDone) continue;

    // once per frame: show it, read input
    y = 0;
    SDL_UpdateTexture(tex, nullptr, fb.data(), W * sizeof(uint32_t));
    SDL_RenderCopy(ren, tex, nullptr, nullptr);
    SDL_RenderPresent(ren);

    SDL_Event e;
    while (SDL_PollEvent(&e)) {
      if (e.type == SDL_QUIT) running = false;
      if (e.type == SDL_KEYDOWN && e.key.keysym.scancode == SDL_SCANCODE_ESCAPE) running = false;
      if (e.type == SDL_KEYDOWN && e.key.keysym.scancode == SDL_SCANCODE_R) reset();
      if (e.type == SDL_CONTROLLERDEVICEADDED && !pad) pad = SDL_GameControllerOpen(e.cdevice.which);
    }
    const uint8_t* keys = SDL_GetKeyboardState(nullptr);
    top.buttons = keyboardMask(keys) | controllerMask(pad);
    top.levelKeyN = !keys[SDL_SCANCODE_N];

    if (++frames % 60 == 0) {
      double s = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
      char title[96];
      std::snprintf(title, sizeof title, "PacmanHDL (simulated RTL) - %.1f fps of 73", 60 / s);
      SDL_SetWindowTitle(win, title);
      t0 = std::chrono::steady_clock::now();
    }
  }
  SDL_Quit();
  return 0;
}
