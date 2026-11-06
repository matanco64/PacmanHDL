// Scan fast-forward: runs the Verilator model a frame at a time, but replays
// rows whose outcome is already known from the previous frame instead of
// clocking them.
//
// The game draws the screen and detects collisions while the raster scans, so
// every clock can change state. In practice, between two frames almost nothing
// changes away from the sprites. At the end of every active row the model's
// state is snapshotted. When the state that row a..b depends on equals the
// previous frame's state at the same row, rows a..b would replay exactly what
// they did last frame, so the model is set to last frame's state at the end of
// row b, the framebuffer keeps last frame's pixels, and only the registers
// that run independently of the frame are advanced analytically: the LFSRs
// (8-bit, one step per clock) and the one-second counter.
//
// "Depends on" is decided per register:
//   - combinational values are recomputed after the jump (found at start-up by
//     disturbing each member and re-settling the model);
//   - sprite registers (Pac-Man, each ghost, and the logic named after them)
//     only matter to the rows around that sprite, old and new position;
//   - the tile map matters only to the rows of the tiles that changed;
//   - any other difference blocks skipping for the rest of the frame.
// A register that differs from last frame and also changed during the rows
// to skip in last frame cannot be replayed, so the skip stops before that row.
// Rows where the previous frame's one-second tick fired, and any row where
// this frame's tick will fire, are clocked. While a breakable wall or a fruit
// is waiting to be placed (the placement can hit any tile the scan passes, by
// LFSR), every row is clocked.
//
// verify mode (web/ffverify.cpp) runs this beside a fully clocked model and
// compares every register and pixel of every frame.
#pragma once
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#include "Vsim_top.h"
#include "Vsim_top___024root.h"

// Verilator's settle pass: recomputes every combinational member from state.
VL_ATTR_COLD void Vsim_top___024root___stl_comb__TOP__0(Vsim_top___024root* vlSelf);

namespace scanff {

constexpr int W = 640, H = 480, HT = 656;
#ifndef FF_SEC
#define FF_SEC 23369344
#endif

enum Kind : uint8_t { K_STATE, K_COMB, K_LFSR, K_SEC, K_MAP, K_SPRITE, K_LOCAL, K_ROWS, K_POWER };

// Registers allowed to differ from last frame over skipped rows: they are only
// read in vertical blanking or at the one-second tick (both always clocked), or
// they are pixel pipeline stages that refill during horizontal blanking.
static const char* const kLocal[] = {
  // controller inputs, latched in vertical blanking
  "game__DOT__keyPadQ", "game__DOT__keyPadValidQ", "game__DOT__starQ", "game__DOT__slashQ",
  "game__DOT__numQ", "game__DOT__pauseNQ", "game__DOT__turboQ", "game__DOT__level_keyQ",
  // map drawer: frame and second counters, pixel pipeline
  "inst45__DOT__pulseCnt", "inst45__DOT__secCnt", "inst45__DOT__frameRnd", "inst45__DOT__RGBout",
  "inst45__DOT__mapDR", "inst45__DOT__coinsDR", "inst45__DOT__powerDR", "inst45__DOT__pickUpDR",
  // wall breaking: latched at startOfFrame, applied in vertical blanking
  "inst45__DOT__breakTile", "inst45__DOT__breakAddr", "inst45__DOT__breakNum",
  "inst45__DOT__breakSlash", "inst45__DOT__breakStar", "unnamedblk3__DOT__pacX",
  "unnamedblk3__DOT__pacY", "unnamedblk3__DOT__targetX", "unnamedblk3__DOT__targetY",
};
// Registers that only change when Pac-Man collides with something, which can
// only happen on Pac-Man's rows.
static const char* const kPacman[] = {
  "updater_inst__DOT__coinsCollected", "updater_inst__DOT__powerCollected",
  "updater_inst__DOT__collisionFlag", "inst45__DOT__partialScore",
};
// Side-panel values and the rows they are drawn on (x >= 512, see pacman_core).
static const struct { const char* name; int lo, hi; } kRows[] = {
  {"inst32__DOT__totalScore", 48, 112},
  {"binary_to_bcd_inst__DOT__ones", 48, 112},
  {"binary_to_bcd_inst__DOT__tens", 48, 112},
  {"binary_to_bcd_inst__DOT__hundreds", 48, 112},
};

struct Field {
  const char* name;
  uint32_t off, size;  // in the model
  uint32_t poff;       // in a snapshot
  Kind kind;
  int8_t sprite;
  int16_t lo = 0, hi = 0;  // K_ROWS: rows the value is drawn on
  bool tileBand = false;    // K_SPRITE: tiles-around reader, not drawing
};

inline uint8_t lfsrStep(uint8_t s) {
  return uint8_t(s << 1) | (((s >> 7) ^ (s >> 5) ^ (s >> 4) ^ (s >> 3)) & 1);
}

class Runner {
 public:
  Vsim_top* top;
  Vsim_top___024root* r;
  uint32_t fb[W * H];
  uint32_t palette[256];
  bool ff = true;
  long debugFrame = -1;
  double cycles = 0;
  long rowsClocked = 0, rowsSkipped = 0, frames = 0;
  std::vector<long> blockCount;  // per field: how often it stopped a skip (diagnostics)

  Runner() {
    for (int p = 0; p < 256; ++p) {
      uint32_t rr = ((p >> 5) & 7) * 255 / 7, g = ((p >> 2) & 7) * 255 / 7, b = (p & 3) * 255 / 3;
      palette[p] = 0xff000000u | b << 16 | g << 8 | rr;
    }
    top = new Vsim_top;
    r = top->rootp;
    top->clk = 0;
    top->buttons = 0;
    top->levelKeyN = 1;
    reset();
    buildFields();
    for (int s = 0; s < 256; ++s) {
      uint8_t v = uint8_t(s);
      for (int i = 0; i < HT; ++i) v = lfsrStep(v);
      lfsrRow[s] = v;
    }
  }

  void reset() {
    top->resetN = 0;
    for (int i = 0; i < 32; ++i) { top->clk ^= 1; top->eval(); }
    top->resetN = 1;
    prevValid = false;
  }

  void setInputs(int buttons, int levelKeyN) {
    top->buttons = buttons;
    top->levelKeyN = levelKeyN;
  }

  // Clocks the design until the LCD timing ends a frame; returns the framebuffer.
  uint32_t* runFrame() {
    curTick = -1;
    for (;;) {
      top->clk = 1; top->eval();
      ++cycles;
      bool rowEnd = false;
      if (top->de) {
        if (x < W && y < H) fb[y * W + x] = palette[top->rgb];
        ++x;
      } else if (prevDe) {
        rowEnd = true;
      }
      prevDe = top->de;
      bool frameDone = !top->vsync && prevVsync;
      prevVsync = top->vsync;
      top->clk = 0; top->eval();
      if (rowEnd) {
        ++rowsClocked;
        atRowEnd(y);
        x = 0; ++y;
      }
      if (frameDone) {
        y = 0;
        ++frames;
        std::swap(prevSnap, curSnap);
        prevTick = curTick;
        prevValid = ff;
        return fb;
      }
    }
  }

  size_t snapBytes() const { return snapSize; }
  const std::vector<Field>& fieldList() const { return fields; }

 private:
  int x = 0, y = 0;
  bool prevDe = false, prevVsync = true;
  std::vector<Field> fields;     // members a snapshot holds (not ROMs, not Verilator internals)
  std::vector<int> stateFields;  // indices of non-combinational ones
  struct Range { uint32_t off, len, poff; };
  std::vector<Range> ranges;
  size_t snapSize = 0;
  std::vector<uint8_t> prevSnap, curSnap;  // H snapshots each
  bool prevValid = false;
  int prevTick = -1, curTick = -1;  // row in which the one-second counter wrapped
  uint8_t lfsrRow[256];
  // well-known members
  const Field *fSec = nullptr, *fMap = nullptr, *fPlacing = nullptr, *fFruit = nullptr, *fLevel = nullptr,
              *fCoins = nullptr, *fCoinsTot = nullptr;
  const Field* fSpriteY[5] = {};
  std::vector<int> lfsrFields;
  std::vector<int> diff;

  static bool has(const std::string& s, const char* t) { return s.find(t) != std::string::npos; }
  static bool ends(const std::string& s, const char* t) {
    size_t n = std::strlen(t);
    return s.size() >= n && s.compare(s.size() - n, n, t) == 0;
  }

  void buildFields() {
    std::vector<Field> all;
#define F(n) all.push_back({#n, uint32_t((char*)&r->n - (char*)r), uint32_t(sizeof(r->n)), 0, K_STATE, -1});
#include "fields.inc"
#undef F
    static const char* spriteKeys[5][3] = {
      {"game__DOT__inst1__DOT__", "around_pacman_inst", "game__DOT__inst54__DOT__"},  // Pac-Man, fog
      {"game__DOT__blinky__DOT__", "around_blinky_inst", nullptr},
      {"game__DOT__pinky__DOT__", "around_pinky_inst", nullptr},
      {"game__DOT__inky__DOT__", "around_inky_inst", nullptr},
      {"game__DOT__clyde__DOT__", "around_clyde_inst", nullptr},
    };
    for (Field& f : all) {
      std::string n = f.name;
      if (n.rfind("__V", 0) == 0 || has(n, "__DOT____V")) continue;  // Verilator internals
      if (has(n, "__DOT__mem") || has(n, "glyph") || has(n, "__DOT__shapes") || has(n, "__DOT__sprite")) continue;
      for (int s = 0; s < 5; ++s)
        for (const char* k : spriteKeys[s])
          if (k && f.sprite < 0 && has(n, k)) { f.sprite = int8_t(s); f.kind = K_SPRITE; }
      f.tileBand = has(n, "__DOT__around_");
      if (n.size() > 11 && n.compare(n.size() - 11, 11, "__DOT__lfsr") == 0) f.kind = K_LFSR;
      if (has(n, "oneSecCount")) f.kind = K_SEC;
      if (n == "sim_top__DOT__game__DOT__inst45__DOT__pacmanMap") f.kind = K_MAP;
      for (const char* k : kLocal) if (ends(n, k)) f.kind = K_LOCAL;
      if (has(n, "game__DOT__inst10__DOT__") && f.kind != K_SEC) f.kind = K_LOCAL;  // game timer (not drawn)
      for (const char* k : kPacman) if (ends(n, k)) { f.kind = K_SPRITE; f.sprite = 0; }
      for (const auto& k : kRows) if (ends(n, k.name)) { f.kind = K_ROWS; f.lo = int16_t(k.lo); f.hi = int16_t(k.hi); }
      if (ends(n, "inst45__DOT__shine") || ends(n, "inst45__DOT__togglePow")) f.kind = K_POWER;
      fields.push_back(f);
    }
    for (const Field& f : all)
      if (std::none_of(fields.begin(), fields.end(), [&](const Field& k) { return k.off == f.off && k.size == f.size; }))
        excluded.push_back(f.off);
    std::sort(excluded.begin(), excluded.end());
    std::sort(fields.begin(), fields.end(), [](const Field& a, const Field& b) { return a.off < b.off; });

    // Which members are combinational: disturb each, re-settle, see if it comes back.
    size_t whole = sizeof(*r);
    std::vector<uint8_t> save(whole), probe(64);
    std::memcpy(save.data(), (void*)r, whole);
    for (Field& f : fields) {
      if (f.kind == K_LFSR || f.kind == K_SEC || f.kind == K_MAP) continue;
      if (f.size > 64) continue;
      uint8_t* p = (uint8_t*)r + f.off;
      for (uint32_t i = 0; i < f.size; ++i) p[i] ^= 0x5a;
      Vsim_top___024root___stl_comb__TOP__0(r);
      if (std::memcmp(p, save.data() + f.off, f.size) == 0) f.kind = K_COMB;
      std::memcpy((void*)r, save.data(), whole);
    }

    // snapshot layout: consecutive runs of members, padding included
    uint32_t poff = 0;
    for (size_t i = 0; i < fields.size(); ++i) {
      Field& f = fields[i];
      if (!ranges.empty() && f.off >= ranges.back().off + ranges.back().len &&
          f.off <= ranges.back().off + ranges.back().len + 8 &&
          noneExcluded(ranges.back().off + ranges.back().len, f.off)) {
        Range& rg = ranges.back();
        uint32_t end = f.off + f.size;
        f.poff = rg.poff + (f.off - rg.off);
        poff += end - (rg.off + rg.len);
        rg.len = end - rg.off;
      } else {
        ranges.push_back({f.off, f.size, poff});
        f.poff = poff;
        poff += f.size;
      }
    }
    snapSize = (poff + 7) & ~7u;
    prevSnap.assign(snapSize * H, 0);
    curSnap.assign(snapSize * H, 0);
    blockCount.assign(fields.size(), 0);

    for (size_t i = 0; i < fields.size(); ++i) {
      const Field& f = fields[i];
      std::string n = f.name;
      if (f.kind != K_COMB) stateFields.push_back(int(i));
      if (f.kind == K_LFSR) lfsrFields.push_back(int(i));
      if (f.kind == K_SEC) fSec = &f;
      if (f.kind == K_MAP) fMap = &f;
      if (has(n, "updater_inst__DOT__addBreak_st")) fPlacing = &f;
      if (has(n, "updater_inst__DOT__fruitSpawnPending")) fFruit = &f;
      if (ends(n, "updater_inst__DOT__coinsCollected")) fCoins = &f;
      if (ends(n, "manager_inst__DOT__coinsTot")) fCoinsTot = &f;
      if (n == "sim_top__DOT__game__DOT__inst__DOT__level") fLevel = &f;
      if (n == "sim_top__DOT__game__DOT__inst1__DOT__inst_pacman__DOT__topLeftY") fSpriteY[0] = &f;
      static const char* g[4] = {"blinky", "pinky", "inky", "clyde"};
      for (int s = 0; s < 4; ++s)
        if (n == std::string("sim_top__DOT__game__DOT__") + g[s] + "__DOT__inst__DOT__topLeftY") fSpriteY[s + 1] = &f;
    }
  }
  std::vector<uint32_t> excluded;  // offsets of members a snapshot must not touch
  bool noneExcluded(uint32_t lo, uint32_t hi) const {
    auto it = std::lower_bound(excluded.begin(), excluded.end(), lo);
    return it == excluded.end() || *it >= hi;
  }

  uint8_t* snap(std::vector<uint8_t>& v, int row) { return v.data() + size_t(row) * snapSize; }
  void take(uint8_t* dst) {
    for (const Range& rg : ranges) std::memcpy(dst + rg.poff, (uint8_t*)r + rg.off, rg.len);
  }
  void put(const uint8_t* src) {
    for (const Range& rg : ranges) std::memcpy((uint8_t*)r + rg.off, src + rg.poff, rg.len);
  }
  static uint32_t val(const uint8_t* s, const Field* f) {
    uint32_t v = 0;
    std::memcpy(&v, s + f->poff, std::min<uint32_t>(f->size, 4));
    return v;
  }
  // First y row of map row t. The scan's tile row is y/16 - 1 in 5 bits, so map row
  // t is scanned on y rows 16(t+1)..16(t+1)+15, and row 31 on y rows 0..15.
  static int tileRow(int t) { return (16 * (t + 1)) & 511; }
  static bool same(const uint8_t* a, const uint8_t* b, const Field& f) {
    return std::memcmp(a + f.poff, b + f.poff, f.size) == 0;
  }

  // Called with the model just past the end of active row v.
  void atRowEnd(int v) {
    uint8_t* cur = snap(curSnap, v);
    take(cur);
    if (curTick < 0 && v > 0 && val(cur, fSec) < val(snap(curSnap, v - 1), fSec)) curTick = v;
    if (!prevValid || v >= H - 1) return;
    if (val(cur, fPlacing) == 1 || val(cur, fFruit)) return;
    // wall placement starts at the next tile the scan crosses once 5% of the coins are eaten
    if (val(cur, fPlacing) == 0 && val(cur, fCoins) * 100 > 5 * val(cur, fCoinsTot)) return;
    int a = v + 1, b = H - 1;
    const uint8_t* prev = snap(prevSnap, v);

    // one-second counter: no wrap inside the skipped rows, and not where last frame's was
    uint32_t sec = val(cur, fSec);
    long k = (long(FF_SEC) - long(sec)) / HT;
    b = int(std::min<long>(b, a - 1 + k));
    if (prevTick >= a) b = std::min(b, prevTick - 1);
    if (b < a) return;

    // state that differs from last frame
    diff.clear();
    for (int i : stateFields) {
      const Field& f = fields[i];
      if (f.kind == K_LFSR || f.kind == K_SEC) continue;
      if (!same(cur, prev, f)) diff.push_back(i);
    }
    int level = int(val(cur, fLevel));
    int fogMargin = (level >= 3 && level <= 5) ? 136 : 0;
    for (int i : diff) {
      const Field& f = fields[i];
      int stop = b + 1;  // first row this field forbids skipping
      if (f.kind == K_MAP) {
        for (uint32_t t = 0; t < f.size; ++t)
          if (cur[f.poff + t] != prev[f.poff + t]) {
            int y0 = tileRow(int(t & 31)) - 2, y1 = tileRow(int(t & 31)) + 17;
            if (y1 >= a) stop = std::min(stop, std::max(y0, a));
          }
      } else if (f.kind == K_ROWS) {
        if (f.hi >= a) stop = std::max<int>(f.lo, a);
      } else if (f.kind == K_POWER) {
        // power pellets: rows of tiles holding one, in either frame's map
        for (uint32_t t = 0; t < fMap->size; ++t)
          if (cur[fMap->poff + t] == 5 || prev[fMap->poff + t] == 5) {
            int y0 = tileRow(int(t & 31)) - 2, y1 = tileRow(int(t & 31)) + 17;
            if (y1 >= a) stop = std::min(stop, std::max(y0, a));
          }
      } else if (f.kind == K_LOCAL) {
        // allowed to differ; still has to stay constant over the rows below
      } else if (f.kind == K_SPRITE) {
        const Field* fy = fSpriteY[f.sprite];
        int y0 = int(std::min(val(cur, fy), val(prev, fy)));
        int y1 = int(std::max(val(cur, fy), val(prev, fy)));
        if (f.tileBand) {
          // the tiles around it are read on map rows tile-1..tile+1, where tile is
          // y/16 - 1 in 5 bits (in the vertical tunnel, y >= 512, it wraps to 0)
          for (int yy : {y0, y1})
            for (int k = -1; k <= 1; ++k) {
              int t = ((yy >> 4) - 1 + k) & 31;
              int lo = tileRow(t) - 2, hi = tileRow(t) + 17;
              if (hi >= a) stop = std::min(stop, std::max(lo, a));
            }
        } else {
          // drawn on rows y..y+h (Pac-Man 16, ghosts 32); the fog (levels 3-5) is a
          // circle around Pac-Man
          int lo = y0 - 2, hi = y1 + (f.sprite == 0 ? 16 : 32) + 2;
          if (f.sprite == 0) { lo -= fogMargin; hi += fogMargin; }
          if (hi >= a) stop = std::min(stop, std::max(lo, a));
        }
      } else {
        stop = a;
      }
      // must also stay constant over the rows in last frame
      for (int rr = a; rr < stop; ++rr)
        if (!same(snap(prevSnap, rr), prev, f)) { stop = rr; break; }
      if (stop <= b) {
        b = stop - 1;
        ++blockCount[i];
        if (b < a) return;
      }
    }
    if (debugFrame == frames) {
      std::printf("f%ld row %d: skip %d..%d, pacY %u/%u level %d, differs:", frames, v, a, b, val(cur, fSpriteY[0]),
                  val(prev, fSpriteY[0]), level);
      for (int i : diff) std::printf(" %s", fields[i].name + 25);
      std::printf("\n");
    }
    skip(v, a, b);
  }

  void skip(int v, int a, int b) {
    const uint8_t* cur = snap(curSnap, v);
    int n = b - a + 1;
    // registers: last frame's, except those that differ now (constant over the rows)
    for (int rr = a; rr <= b; ++rr) {
      uint8_t* s = snap(curSnap, rr);
      std::memcpy(s, snap(prevSnap, rr), snapSize);
      for (int i : diff) std::memcpy(s + fields[i].poff, cur + fields[i].poff, fields[i].size);
    }
    for (int rr = a; rr <= b; ++rr) {
      uint32_t s = val(cur, fSec) + uint32_t(rr - a + 1) * HT;
      std::memcpy(snap(curSnap, rr) + fSec->poff, &s, 4);
    }
    uint8_t* end = snap(curSnap, b);
    for (int i : lfsrFields) {
      uint8_t s = cur[fields[i].poff];
      for (int j = 0; j < n; ++j) s = lfsrRow[s];
      end[fields[i].poff] = s;
    }
    put(end);
    Vsim_top___024root___stl_comb__TOP__0(r);
    cycles += double(n) * HT;
    rowsSkipped += n;
    y = b;  // runFrame advances to b + 1
  }
};

}  // namespace scanff
