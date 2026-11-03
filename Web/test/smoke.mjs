// Plays every cartridge through the compiled WebAssembly module with scripted input.
import { readFileSync } from 'node:fs';
import { loadEngine } from '../site/engine.js';

const wasmPath = process.argv[2];
if (!wasmPath) { console.error('usage: node smoke.mjs <pocketweb.wasm>'); process.exit(2); }

const engine = await loadEngine(readFileSync(wasmPath));
const ex = engine.ex;
ex.pb_init(44100);
const carts = engine.cartridges();
if (carts.length < 10) { console.error('expected many cartridges, got', carts.length); process.exit(1); }

let seed = 12345;
const rand = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
let failures = 0;

for (const cart of carts) {
  const started = Date.now();
  for (const color of [1, 0]) {
    ex.pb_set_mode(color, 0);
    ex.pb_insert(cart.index);
    const seen = new Set();
    let buttons = 0;
    const frames = cart.era === '64' ? 420 : 900;
    for (let f = 0; f < frames; f++) {
      if (f % 9 === 0) buttons = (rand() * 256) | 0;
      if (f % 6 < 2) buttons |= 16; // mash A
      ex.pb_tick(1000 / 60, buttons);
      if (f > 160 && f % 25 === 0) {
        const { w, h, data } = engine.frame();
        const px = new Uint32Array(data.buffer, data.byteOffset, w * h);
        for (let i = 0; i < px.length; i += 641) seen.add(px[i]);
        const a = engine.audio(256);
        for (let i = 0; i < a.length; i++) if (!Number.isFinite(a[i])) { console.error(cart.id, 'non-finite audio'); failures++; break; }
      }
    }
    if (seen.size < 2) { console.error(`FAIL ${cart.id} (color=${color}): flat frame`); failures++; }
    ex.pb_eject();
  }
  console.log(`ok ${cart.id.padEnd(14)} ${Date.now() - started} ms`);
}
console.log(failures === 0 ? `all ${carts.length} cartridges ran` : `${failures} failure(s)`);
process.exit(failures === 0 ? 0 : 1);
