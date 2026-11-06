// Browser side: draws frames from the worker and turns keys into the board's
// gamepad mask (rtl/io/gamepad.sv), the same mapping as sim/play.cpp.
const canvas = document.getElementById('screen');
const ctx = canvas.getContext('2d');
const overlay = document.getElementById('overlay');
const statsEl = document.getElementById('stats');
const img = ctx.createImageData(640, 480);

const UP = 1, DOWN = 2, LEFT = 4, RIGHT = 8, A = 16, B = 32, SELECT = 64, START = 128;
const KEYS = {
  ArrowUp: UP, KeyW: UP, ArrowDown: DOWN, KeyS: DOWN, ArrowLeft: LEFT, KeyA: LEFT,
  ArrowRight: RIGHT, KeyD: RIGHT, KeyZ: A, Space: A, KeyX: B, KeyC: SELECT, Enter: START, KeyP: START,
};
const held = new Map(); // source -> mask, so keys and touch buttons combine
let levelKeyN = 1;

const worker = new Worker('worker.js');
// ?ff=0 clocks every row instead of replaying rows known from the previous frame
if (new URLSearchParams(location.search).get('ff') === '0') worker.postMessage({ fastForward: false });

function send() {
  let buttons = 0;
  for (const m of held.values()) buttons |= m;
  worker.postMessage({ buttons, levelKeyN });
}

addEventListener('keydown', (e) => {
  if (e.code === 'KeyR') { if (!e.repeat) worker.postMessage({ reset: true }); }
  else if (e.code === 'KeyN') levelKeyN = 0;
  else if (e.code in KEYS) held.set(e.code, KEYS[e.code]);
  else return;
  e.preventDefault();
  send();
});
addEventListener('keyup', (e) => {
  if (e.code === 'KeyN') levelKeyN = 1;
  held.delete(e.code);
  send();
});
addEventListener('blur', () => { held.clear(); levelKeyN = 1; send(); });

for (const b of document.querySelectorAll('#pad button')) {
  const id = 'pad' + b.dataset.k, mask = Number(b.dataset.k);
  b.addEventListener('pointerdown', (e) => { e.preventDefault(); held.set(id, mask); send(); });
  for (const ev of ['pointerup', 'pointerleave', 'pointercancel'])
    b.addEventListener(ev, () => { held.delete(id); send(); });
}

worker.onmessage = (e) => {
  const d = e.data;
  if (d.type === 'ready') { overlay.hidden = true; send(); return; }
  img.data.set(new Uint8ClampedArray(d.px));
  ctx.putImageData(img, 0, 0);
  if (d.stats) {
    const pct = Math.round(100 * d.stats.fps / d.stats.boardFps);
    const skip = Math.round(100 * d.stats.skip);
    statsEl.textContent = `${d.stats.fps.toFixed(1)} fps simulated · ${pct}% of hardware speed` +
      (d.stats.skip > 0 ? ` · ${skip}% of rows replayed` : '');
  }
};
worker.onerror = (e) => { overlay.hidden = false; overlay.textContent = 'Failed to load: ' + e.message; };
