// Runs the Verilated design off the main thread and streams frames back.
importScripts('pacman.js');

const W = 640, H = 480;
let buttons = 0, levelKeyN = 1, resetPending = false;

onmessage = (e) => {
  if (e.data.reset) resetPending = true;
  else ({ buttons, levelKeyN } = e.data);
};

createPacman().then((m) => {
  m._pw_init();
  const BOARD_FPS = m._pw_game_fps(); // ~73, or 73/N for a WEB_SCALE=N build
  postMessage({ type: 'ready' });
  let next = performance.now();
  let frames = 0, statT = performance.now();

  function step() {
    // Never run faster than the board; when the machine is slower, run flat out.
    const now = performance.now();
    if (now < next) { setTimeout(step, next - now); return; }
    next = Math.max(next + 1000 / BOARD_FPS, now - 50);

    if (resetPending) { m._pw_reset(); resetPending = false; }
    m._pw_set_inputs(buttons, levelKeyN);
    const ptr = m._pw_run_frame();
    const px = m.HEAPU8.slice(ptr, ptr + W * H * 4);
    frames++;
    let stats = null;
    const t = performance.now();
    if (t - statT > 1000) {
      stats = { fps: frames * 1000 / (t - statT), boardFps: BOARD_FPS };
      frames = 0; statT = t;
    }
    postMessage({ type: 'frame', px: px.buffer, stats }, [px.buffer]);
    setTimeout(step, 0);
  }
  step();
});
