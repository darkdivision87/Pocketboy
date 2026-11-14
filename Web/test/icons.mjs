// Renders a picture icon for every cartridge by playing it in the compiled wasm and keeping the most colourful frame.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { deflateSync } from 'node:zlib';
import { loadEngine } from '../site/engine.js';

const [wasmPath, outDir] = process.argv.slice(2);
if (!wasmPath || !outDir) { console.error('usage: node icons.mjs <pocketweb.wasm> <outDir>'); process.exit(2); }
mkdirSync(outDir, { recursive: true });

const crcTable = new Uint32Array(256).map((_, n) => { let c = n; for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1); return c >>> 0; });
const crc32 = (buf) => { let c = 0xffffffff; for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
function chunk(type, data) {
  const t = Buffer.from(type, 'ascii');
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([t, data])));
  return Buffer.concat([len, t, data, crc]);
}
function png(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; Buffer.from(rgba.buffer, rgba.byteOffset + y * w * 4, w * 4).copy(raw, y * (w * 4 + 1) + 1); }
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}

const engine = await loadEngine(readFileSync(wasmPath));
const ex = engine.ex;
ex.pb_init(44100);
ex.pb_set_mode(1, 0);

function grab() {
  const { w, h, data } = engine.frame();
  const src = new Uint8Array(data.buffer, data.byteOffset, w * h * 4);
  if (w === 160) return { w, h, rgba: Uint8Array.from(src) };
  // 64 carts: average 2x2 down to 160x144 so every icon is the same size
  const ow = w / 2, oh = h / 2;
  const out = new Uint8Array(ow * oh * 4);
  for (let y = 0; y < oh; y++) for (let x = 0; x < ow; x++) for (let c = 0; c < 4; c++) {
    const i = ((y * 2) * w + x * 2) * 4 + c;
    out[(y * ow + x) * 4 + c] = (src[i] + src[i + 4] + src[i + w * 4] + src[i + w * 4 + 4]) >> 2;
  }
  return { w: ow, h: oh, rgba: out };
}
function richness(img) {
  const seen = new Set();
  const px = new Uint32Array(img.rgba.buffer, img.rgba.byteOffset, img.w * img.h);
  for (let i = 0; i < px.length; i += 7) seen.add(px[i] & 0xf8f8f8);
  return seen.size;
}

for (const cart of engine.cartridges()) {
  ex.pb_insert(cart.index);
  for (let f = 0; f < 175; f++) ex.pb_tick(1000 / 60, 0);
  for (let f = 0; f < 8; f++) ex.pb_tick(1000 / 60, 16); // press A to leave the title
  let best = null, bestScore = -1;
  for (let shot = 0; shot < 3; shot++) {
    for (let f = 0; f < 140; f++) {
      const b = 8 | (f % 24 < 3 ? 16 : 0); // run right, tap A now and then
      ex.pb_tick(1000 / 60, b);
    }
    const img = grab();
    const score = richness(img);
    if (score > bestScore) { bestScore = score; best = img; }
  }
  writeFileSync(`${outDir}/${cart.id}.png`, png(best.w, best.h, best.rgba));
  ex.pb_eject();
  console.log('icon', cart.id, bestScore);
}
