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
const fastForward = new URLSearchParams(location.search).get('ff') !== '0';
if (!fastForward) worker.postMessage({ fastForward: false });

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
    odometer('odo-fps', Math.round(d.stats.fps), 2, '');
    odometer('odo-speed', pct, 3, '%');
    odometer('odo-skip', fastForward ? skip : 0, 3, '%');
    statusEl.textContent = `Done · ${d.stats.fps.toFixed(1)} frames/s, ${pct}% of the board's ` +
      `${d.stats.boardFps.toFixed(1)} frames/s`;
  }
};

// rolling-digit counters in the sidebar
function odometer(id, value, digits, unit) {
  const el = document.getElementById(id);
  if (!el) return;
  const s = String(Math.max(0, Math.min(value, 10 ** digits - 1))).padStart(digits, '0');
  el.replaceChildren(...[...s].map((c) => Object.assign(document.createElement('span'), { textContent: c })));
  if (unit) el.append(Object.assign(document.createElement('small'), { textContent: unit }));
}
for (const [id, n, u] of [['odo-fps', 2, ''], ['odo-speed', 3, '%'], ['odo-skip', 3, '%']]) odometer(id, 0, n, u);

const statusEl = document.getElementById('status') || document.createElement('span');
const modeEl = document.getElementById('mode');
if (modeEl) {
  modeEl.innerHTML = fastForward
    ? 'Scan fast-forward on · <a href="?ff=0">clock every row</a>'
    : 'Every row clocked · <a href="./">fast-forward</a>';
}
const addressEl = document.getElementById('address');
if (addressEl) addressEl.textContent = location.href;
statusEl.textContent = 'Loading the hardware design…';
worker.onerror = (e) => { overlay.hidden = false; overlay.textContent = 'Failed to load: ' + e.message; };
