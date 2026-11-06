// Checks the scan fast-forward (web/scanff.h): runs a fully clocked model and
// a fast-forwarded one side by side on the same scripted inputs and compares
// every register and every pixel after each frame.
//
//   ffverify [frames] [seed]
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "scanff.h"
#include "verilated.h"

int main(int argc, char** argv) {
  int frames = argc > 1 ? std::atoi(argv[1]) : 2000;
  unsigned seed = argc > 2 ? unsigned(std::atoi(argv[2])) : 1;
  bool quiet = std::getenv("FF_BENCH") != nullptr;  // only time the fast model
  scanff::Runner* ref = quiet ? nullptr : new scanff::Runner;
  scanff::Runner* ffr = new scanff::Runner;
  if (ref) ref->ff = false;
  if (const char* d = std::getenv("FF_DEBUG")) ffr->debugFrame = std::atol(d);
  std::printf("snapshot %zu bytes/row, %zu members\n", ffr->snapBytes(), ffr->fieldList().size());

  // scripted play: a random walk through the maze, a pause, and level skips
  // (levels 3-5 have fog around Pac-Man)
  unsigned rng = seed * 2654435761u + 1;
  auto next = [&] { rng = rng * 1103515245u + 12345u; return rng >> 16; };
  static const int dirs[4] = {0x01, 0x02, 0x04, 0x08};
  int buttons = 0, hold = 0;
  double tRef = 0, tFf = 0;
  for (int f = 0; f < frames; ++f) {
    if (f >= 60 && --hold <= 0) {
      buttons = dirs[next() % 4];
      if (next() % 8 == 0) buttons |= 0x10 << (next() % 3);  // wall-break keys
      hold = 5 + int(next() % 40);
    }
    int b = buttons;
    if (f % 700 == 400 || f % 700 == 410) b |= 0x80;           // pause, resume
    int levelKeyN = (f % 900 == 850) ? 0 : 1;                  // next level
    auto t0 = std::chrono::steady_clock::now();
    if (ref) { ref->setInputs(b, levelKeyN); ref->runFrame(); }
    auto t1 = std::chrono::steady_clock::now();
    ffr->setInputs(b, levelKeyN); ffr->runFrame();
    auto t2 = std::chrono::steady_clock::now();
    tRef += std::chrono::duration<double>(t1 - t0).count();
    tFf += std::chrono::duration<double>(t2 - t1).count();
    if (!ref) continue;
    bool bad = std::memcmp(ref->fb, ffr->fb, sizeof ref->fb) != 0;
    int nbad = 0;
    for (const auto& fl : ffr->fieldList())
      if (std::memcmp((char*)ref->r + fl.off, (char*)ffr->r + fl.off, fl.size)) {
        if (nbad++ < 20) std::printf("  frame %d: %s differs\n", f, fl.name);
        bad = true;
      }
    if (bad) {
      int px = 0, firstRow = -1;
      for (int i = 0; i < scanff::W * scanff::H; ++i)
        if (ref->fb[i] != ffr->fb[i]) { if (firstRow < 0) firstRow = i / scanff::W; ++px; }
      int x0 = 9999, x1 = -1, y1 = -1;
      for (int i = 0; i < scanff::W * scanff::H; ++i)
        if (ref->fb[i] != ffr->fb[i]) {
          x0 = std::min(x0, i % scanff::W); x1 = std::max(x1, i % scanff::W); y1 = i / scanff::W;
        }
      std::printf("MISMATCH at frame %d: %d members, %d pixels in x %d..%d, y %d..%d\n", f, nbad, px, x0, x1,
                  firstRow, y1);
      return 1;
    }
    if (f % 250 == 249)
      std::printf("frame %d ok, %.0f%% of rows skipped so far\n", f + 1,
                  100.0 * ffr->rowsSkipped / (ffr->rowsSkipped + ffr->rowsClocked));
  }
  std::printf("%d frames identical. rows skipped %.1f%%. fast %.1f fps", frames,
              100.0 * ffr->rowsSkipped / (ffr->rowsSkipped + ffr->rowsClocked), frames / tFf);
  if (ref) std::printf(", full %.1f fps", frames / tRef);
  std::printf("\n");
  // what stopped skips most often
  std::vector<std::pair<long, const char*>> top;
  for (size_t i = 0; i < ffr->blockCount.size(); ++i)
    if (ffr->blockCount[i]) top.push_back({ffr->blockCount[i], ffr->fieldList()[i].name});
  std::sort(top.rbegin(), top.rend());
  for (size_t i = 0; i < top.size() && i < 25; ++i) std::printf("  %7ld %s\n", top[i].first, top[i].second);
  return 0;
}
