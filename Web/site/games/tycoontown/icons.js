// Procedural 2D art: glyphs, sticker badges, avatar portraits, price tags. All drawn with canvas.
const TAU = Math.PI * 2;
function path(c, pts) { c.beginPath(); pts.forEach((p, i) => (i ? c.lineTo(p[0], p[1]) : c.moveTo(p[0], p[1]))); c.closePath(); }
function star(c, x, y, R, r, n = 5, rot = -Math.PI / 2) { c.beginPath(); for (let i = 0; i < n * 2; i++) { const a = rot + (i * Math.PI) / n, rr = i % 2 ? r : R; c.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr); } c.closePath(); }
function circ(c, x, y, r) { c.beginPath(); c.arc(x, y, r, 0, TAU); }
function rr(c, x, y, w, h, r) { c.beginPath(); c.roundRect(x, y, w, h, r); }

// Draw glyph centred at 0,0 within radius 1 (caller scales). Colours are fixed per glyph for crisp "sticker" look.
const G = {
  heart(c) { c.fillStyle = '#ff3d77'; c.beginPath(); c.moveTo(0, 0.75); c.bezierCurveTo(-1.2, 0, -0.9, -0.9, -0.4, -0.75); c.bezierCurveTo(-0.15, -0.7, 0, -0.5, 0, -0.35); c.bezierCurveTo(0, -0.5, 0.15, -0.7, 0.4, -0.75); c.bezierCurveTo(0.9, -0.9, 1.2, 0, 0, 0.75); c.fill(); c.fillStyle = 'rgba(255,255,255,.55)'; circ(c, -0.5, -0.4, 0.14); c.fill(); },
  star(c) { c.fillStyle = '#ffc928'; star(c, 0, 0.05, 0.95, 0.45); c.fill(); c.lineJoin = 'round'; c.lineWidth = 0.1; c.strokeStyle = '#ffe98a'; c.stroke(); },
  moon(c) { c.fillStyle = '#fff3b0'; c.beginPath(); c.arc(0, 0, 0.85, 0.6, TAU - 0.6); c.arc(0.4, 0, 0.7, TAU - 1.0, 1.0, true); c.closePath(); c.fill(); c.fillStyle = '#fff'; star(c, 0.55, -0.45, 0.22, 0.09, 4); c.fill(); },
  sun(c) { c.fillStyle = '#ffb21c'; for (let i = 0; i < 10; i++) { c.save(); c.rotate((i * TAU) / 10); path(c, [[-0.12, -0.7], [0.12, -0.7], [0, -1]]); c.fill(); c.restore(); } c.fillStyle = '#ffd43b'; circ(c, 0, 0, 0.6); c.fill(); c.fillStyle = '#7a4a10'; circ(c, -0.2, -0.08, 0.07); c.fill(); circ(c, 0.2, -0.08, 0.07); c.fill(); c.strokeStyle = '#7a4a10'; c.lineWidth = 0.06; c.beginPath(); c.arc(0, 0.08, 0.22, 0.2, Math.PI - 0.2); c.stroke(); },
  cloud(c) { c.fillStyle = '#fff'; circ(c, -0.4, 0.15, 0.4); c.fill(); circ(c, 0.05, -0.15, 0.5); c.fill(); circ(c, 0.45, 0.15, 0.38); c.fill(); rr(c, -0.8, 0.1, 1.6, 0.45, 0.22); c.fill(); c.fillStyle = '#6a8aa8'; circ(c, -0.12, 0.2, 0.06); c.fill(); circ(c, 0.28, 0.2, 0.06); c.fill(); },
  flower(c) { c.fillStyle = '#ff6fb5'; for (let i = 0; i < 6; i++) { c.save(); c.rotate((i * TAU) / 6); circ(c, 0, -0.5, 0.33); c.fill(); c.restore(); } c.fillStyle = '#ffd43b'; circ(c, 0, 0, 0.3); c.fill(); },
  fish(c) { c.fillStyle = '#ff8a2a'; c.beginPath(); c.ellipse(-0.1, 0, 0.7, 0.45, 0, 0, TAU); c.fill(); path(c, [[0.5, 0], [0.98, -0.42], [0.98, 0.42]]); c.fill(); c.fillStyle = '#fff'; circ(c, -0.4, -0.1, 0.13); c.fill(); c.fillStyle = '#222'; circ(c, -0.42, -0.1, 0.06); c.fill(); c.fillStyle = '#ffd2a0'; c.beginPath(); c.ellipse(-0.05, 0.2, 0.4, 0.14, 0, 0, TAU); c.fill(); },
  cupcake(c) { c.fillStyle = '#e8a86a'; path(c, [[-0.55, 0.05], [0.55, 0.05], [0.4, 0.85], [-0.4, 0.85]]); c.fill(); c.fillStyle = '#ff8fb0'; circ(c, 0, -0.1, 0.62); c.fill(); circ(c, 0, -0.45, 0.4); c.fill(); c.fillStyle = '#ff3d6e'; circ(c, 0, -0.85, 0.15); c.fill(); c.fillStyle = '#fff'; rr(c, -0.2, -0.2, 0.12, 0.06, 0.03); c.fill(); rr(c, 0.1, -0.05, 0.12, 0.06, 0.03); c.fill(); },
  balloon(c) { c.fillStyle = '#ff4b5c'; c.beginPath(); c.ellipse(0, -0.2, 0.6, 0.72, 0, 0, TAU); c.fill(); path(c, [[0, 0.52], [-0.12, 0.7], [0.12, 0.7]]); c.fill(); c.strokeStyle = '#fff'; c.lineWidth = 0.05; c.beginPath(); c.moveTo(0, 0.7); c.bezierCurveTo(-0.2, 0.85, 0.2, 0.95, 0, 1.05); c.stroke(); c.fillStyle = 'rgba(255,255,255,.6)'; c.beginPath(); c.ellipse(-0.28, -0.45, 0.1, 0.18, 0.5, 0, TAU); c.fill(); },
  leaf(c) { c.fillStyle = '#4fc95a'; c.beginPath(); c.moveTo(-0.7, 0.7); c.bezierCurveTo(-0.9, -0.5, 0, -0.95, 0.85, -0.8); c.bezierCurveTo(0.9, 0.1, 0.2, 0.9, -0.7, 0.7); c.fill(); c.strokeStyle = '#d9ffc0'; c.lineWidth = 0.07; c.beginPath(); c.moveTo(-0.65, 0.65); c.quadraticCurveTo(0, 0, 0.6, -0.6); c.stroke(); },
  paw(c) { c.fillStyle = '#b86a2e'; c.beginPath(); c.ellipse(0, 0.3, 0.5, 0.4, 0, 0, TAU); c.fill(); [[-0.6, -0.1, 0.22], [-0.22, -0.55, 0.22], [0.22, -0.55, 0.22], [0.6, -0.1, 0.22]].forEach(([x, y, r]) => { c.beginPath(); c.ellipse(x, y, r, r * 1.2, 0, 0, TAU); c.fill(); }); },
  cherry(c) { c.strokeStyle = '#3a8a3a'; c.lineWidth = 0.08; c.beginPath(); c.moveTo(-0.4, 0.3); c.quadraticCurveTo(-0.2, -0.6, 0.35, -0.85); c.moveTo(0.35, 0.4); c.quadraticCurveTo(0.3, -0.5, 0.35, -0.85); c.stroke(); c.fillStyle = '#4fc95a'; c.beginPath(); c.ellipse(0.6, -0.8, 0.35, 0.16, -0.3, 0, TAU); c.fill(); c.fillStyle = '#e8203e'; circ(c, -0.4, 0.45, 0.4); c.fill(); circ(c, 0.35, 0.55, 0.4); c.fill(); c.fillStyle = 'rgba(255,255,255,.6)'; circ(c, -0.52, 0.32, 0.09); c.fill(); circ(c, 0.23, 0.42, 0.09); c.fill(); },
  house(c) { c.fillStyle = '#ffe3b0'; rr(c, -0.6, -0.1, 1.2, 0.9, 0.08); c.fill(); c.fillStyle = '#e8503e'; path(c, [[-0.82, -0.05], [0, -0.85], [0.82, -0.05]]); c.fill(); c.fillStyle = '#8a5a30'; rr(c, -0.14, 0.3, 0.28, 0.5, 0.06); c.fill(); c.fillStyle = '#8fd8ff'; rr(c, -0.5, 0.1, 0.25, 0.22, 0.04); c.fill(); rr(c, 0.25, 0.1, 0.25, 0.22, 0.04); c.fill(); },
  bell(c) { c.fillStyle = '#ffc928'; c.beginPath(); c.moveTo(-0.7, 0.45); c.bezierCurveTo(-0.65, -0.1, -0.5, -0.8, 0, -0.8); c.bezierCurveTo(0.5, -0.8, 0.65, -0.1, 0.7, 0.45); c.closePath(); c.fill(); rr(c, -0.82, 0.38, 1.64, 0.2, 0.1); c.fill(); c.fillStyle = '#b8700c'; circ(c, 0, 0.72, 0.17); c.fill(); c.fillStyle = 'rgba(255,255,255,.55)'; c.beginPath(); c.ellipse(-0.28, -0.1, 0.09, 0.3, 0.2, 0, TAU); c.fill(); },
  note(c) { c.fillStyle = '#7a4ae0'; c.beginPath(); c.ellipse(-0.35, 0.55, 0.36, 0.27, -0.4, 0, TAU); c.fill(); c.beginPath(); c.ellipse(0.5, 0.35, 0.36, 0.27, -0.4, 0, TAU); c.fill(); rr(c, -0.1, -0.7, 0.13, 1.25, 0.05); c.fill(); rr(c, 0.75, -0.9, 0.13, 1.25, 0.05); c.fill(); path(c, [[-0.1, -0.7], [0.88, -0.95], [0.88, -0.6], [-0.1, -0.35]]); c.fill(); },
  bolt(c) { c.fillStyle = '#ffb800'; path(c, [[0.15, -1], [-0.6, 0.15], [-0.05, 0.15], [-0.25, 1], [0.65, -0.15], [0.1, -0.15]]); c.fill(); c.lineJoin = 'round'; c.strokeStyle = '#fff3a0'; c.lineWidth = 0.08; c.stroke(); },
  rocket(c) { c.save(); c.rotate(0.6); c.fillStyle = '#ff7a3c'; path(c, [[-0.3, 0.45], [-0.6, 0.85], [-0.1, 0.65]]); c.fill(); path(c, [[0.3, 0.45], [0.6, 0.85], [0.1, 0.65]]); c.fill(); c.fillStyle = '#fff'; c.beginPath(); c.moveTo(0, -1); c.bezierCurveTo(0.6, -0.5, 0.45, 0.4, 0.3, 0.6); c.lineTo(-0.3, 0.6); c.bezierCurveTo(-0.45, 0.4, -0.6, -0.5, 0, -1); c.fill(); c.fillStyle = '#ff4b5c'; c.beginPath(); c.moveTo(0, -1); c.bezierCurveTo(0.25, -0.8, 0.38, -0.6, 0.42, -0.45); c.lineTo(-0.42, -0.45); c.bezierCurveTo(-0.38, -0.6, -0.25, -0.8, 0, -1); c.fill(); c.fillStyle = '#4fb4f0'; circ(c, 0, -0.1, 0.2); c.fill(); c.fillStyle = '#ffd43b'; path(c, [[-0.2, 0.7], [0.2, 0.7], [0, 1.1]]); c.fill(); c.restore(); },
  rainbow(c) { const cols = ['#ff4b5c', '#ffa83c', '#ffe03b', '#5fd35f', '#4fb4f0', '#8a6cf0']; cols.forEach((col, i) => { c.strokeStyle = col; c.lineWidth = 0.14; c.beginPath(); c.arc(0, 0.5, 0.95 - i * 0.13, Math.PI, TAU); c.stroke(); }); c.fillStyle = '#fff'; circ(c, -0.8, 0.55, 0.2); c.fill(); circ(c, -0.55, 0.62, 0.17); c.fill(); circ(c, 0.8, 0.55, 0.2); c.fill(); circ(c, 0.55, 0.62, 0.17); c.fill(); },
  gem(c) { c.fillStyle = '#2ed8c0'; path(c, [[-0.55, -0.55], [0.55, -0.55], [0.95, -0.1], [0, 0.95], [-0.95, -0.1]]); c.fill(); c.fillStyle = '#8affe8'; path(c, [[-0.55, -0.55], [0.55, -0.55], [0.3, -0.1], [-0.3, -0.1]]); c.fill(); c.fillStyle = '#17a890'; path(c, [[0.3, -0.1], [0.95, -0.1], [0, 0.95]]); c.fill(); c.fillStyle = '#fff'; star(c, -0.35, -0.35, 0.16, 0.05, 4); c.fill(); },
  crown(c) { c.fillStyle = '#ffc20e'; path(c, [[-0.8, 0.5], [-0.9, -0.5], [-0.4, -0.05], [0, -0.7], [0.4, -0.05], [0.9, -0.5], [0.8, 0.5]]); c.fill(); c.fillStyle = '#e89a00'; rr(c, -0.8, 0.4, 1.6, 0.25, 0.1); c.fill(); c.fillStyle = '#ff4b5c'; circ(c, 0, 0.12, 0.13); c.fill(); c.fillStyle = '#4fb4f0'; circ(c, -0.45, 0.2, 0.1); c.fill(); circ(c, 0.45, 0.2, 0.1); c.fill(); c.fillStyle = '#fff'; circ(c, 0, -0.78, 0.1); c.fill(); circ(c, -0.92, -0.58, 0.09); c.fill(); circ(c, 0.92, -0.58, 0.09); c.fill(); },
  coin(c) { c.fillStyle = '#e5a10c'; circ(c, 0, 0, 0.95); c.fill(); c.fillStyle = '#ffd43b'; circ(c, 0, 0, 0.8); c.fill(); c.fillStyle = '#e5a10c'; star(c, 0, 0.03, 0.5, 0.22); c.fill(); c.fillStyle = 'rgba(255,255,255,.55)'; c.beginPath(); c.ellipse(-0.35, -0.4, 0.14, 0.3, 0.7, 0, TAU); c.fill(); },
  worm(c) { c.strokeStyle = '#ff9db8'; c.lineWidth = 0.35; c.lineCap = 'round'; c.beginPath(); c.moveTo(-0.7, 0.5); c.bezierCurveTo(-0.7, -0.2, -0.1, 0.5, 0.1, 0); c.bezierCurveTo(0.3, -0.5, 0.7, -0.1, 0.7, -0.4); c.stroke(); c.fillStyle = '#222'; circ(c, 0.62, -0.5, 0.06); c.fill(); },
  chest(c) { c.fillStyle = '#b8742c'; rr(c, -0.85, -0.05, 1.7, 0.85, 0.1); c.fill(); c.fillStyle = '#d99542'; c.beginPath(); c.moveTo(-0.85, -0.05); c.bezierCurveTo(-0.85, -0.85, 0.85, -0.85, 0.85, -0.05); c.fill(); c.fillStyle = '#ffd43b'; rr(c, -0.14, -0.1, 0.28, 0.4, 0.06); c.fill(); c.fillStyle = '#7a4a1a'; circ(c, 0, 0.1, 0.06); c.fill(); },
  sparkle(c) { c.fillStyle = '#fff'; star(c, 0, 0, 1, 0.2, 4); c.fill(); },
};
export const GLYPHS = Object.keys(G);
export function glyph(c, name, x, y, r) { const f = G[name] || G.star; c.save(); c.translate(x, y); c.scale(r, r); f(c); c.restore(); }
export function glyphCanvas(name, size) { const cv = document.createElement('canvas'); cv.width = cv.height = size; glyph(cv.getContext('2d'), name, size / 2, size / 2, size * 0.42); return cv; }

export function stickerCanvas(def, size = 128, locked = false) {
  const cv = document.createElement('canvas'); cv.width = cv.height = size; const c = cv.getContext('2d'); const s = size, m = s / 2;
  // scalloped sticker outline
  c.beginPath(); for (let i = 0; i < 24; i++) { const a = (i / 24) * TAU; const r = m * 0.93 - (i % 2 ? m * 0.03 : 0); c.lineTo(m + Math.cos(a) * r, m + Math.sin(a) * r); } c.closePath();
  c.fillStyle = '#fff'; c.shadowColor = 'rgba(0,0,0,.25)'; c.shadowBlur = s * 0.04; c.shadowOffsetY = s * 0.02; c.fill(); c.shadowColor = 'transparent';
  const g = c.createRadialGradient(m, m * 0.7, s * 0.05, m, m, m * 0.8); g.addColorStop(0, locked ? '#d9dde6' : def.c[0]); g.addColorStop(1, locked ? '#aab0bf' : def.c[1]);
  c.fillStyle = g; circ(c, m, m, m * 0.76); c.fill();
  c.strokeStyle = 'rgba(255,255,255,.7)'; c.lineWidth = s * 0.018; circ(c, m, m, m * 0.7); c.stroke();
  if (locked) { c.globalAlpha = 0.5; c.filter = 'grayscale(1) brightness(1.4)'; }
  glyph(c, def.glyph, m, m + s * 0.01, s * 0.3);
  c.filter = 'none'; c.globalAlpha = 1;
  if (!locked && def.rar > 0) { c.fillStyle = '#fff'; star(c, s * 0.82, s * 0.2, s * 0.1, s * 0.04, 4); c.fill(); if (def.rar > 1) { star(c, s * 0.2, s * 0.78, s * 0.08, s * 0.03, 4); c.fill(); } }
  return cv;
}

export function faceCanvas(av, size = 128) {
  const cv = document.createElement('canvas'); cv.width = cv.height = size; const c = cv.getContext('2d'); const m = size / 2, s = size;
  const hex = (n) => '#' + n.toString(16).padStart(6, '0');
  const fur = hex(av.fur), belly = hex(av.belly);
  const eyes = (y, ex = 0.2, r = 0.065) => { c.fillStyle = '#2a2233'; circ(c, m - s * ex, y, s * r); c.fill(); circ(c, m + s * ex, y, s * r); c.fill(); c.fillStyle = '#fff'; circ(c, m - s * ex + s * 0.02, y - s * 0.02, s * 0.02); c.fill(); circ(c, m + s * ex + s * 0.02, y - s * 0.02, s * 0.02); c.fill(); };
  const cheeks = () => { c.fillStyle = 'rgba(255,110,140,.45)'; circ(c, m - s * 0.29, m + s * 0.12, s * 0.06); c.fill(); circ(c, m + s * 0.29, m + s * 0.12, s * 0.06); c.fill(); };
  if (av.kind === 'fox') {
    c.fillStyle = fur; path(c, [[m - s * 0.36, m - s * 0.1], [m - s * 0.34, m - s * 0.46], [m - s * 0.08, m - s * 0.3]]); c.fill(); path(c, [[m + s * 0.36, m - s * 0.1], [m + s * 0.34, m - s * 0.46], [m + s * 0.08, m - s * 0.3]]); c.fill();
    c.fillStyle = '#ffd9c0'; path(c, [[m - s * 0.3, m - s * 0.2], [m - s * 0.31, m - s * 0.36], [m - s * 0.16, m - s * 0.27]]); c.fill(); path(c, [[m + s * 0.3, m - s * 0.2], [m + s * 0.31, m - s * 0.36], [m + s * 0.16, m - s * 0.27]]); c.fill();
    c.fillStyle = fur; c.beginPath(); c.ellipse(m, m + s * 0.05, s * 0.42, s * 0.36, 0, 0, TAU); c.fill(); c.fillStyle = belly; c.beginPath(); c.ellipse(m, m + s * 0.2, s * 0.28, s * 0.2, 0, 0, TAU); c.fill();
    eyes(m - s * 0.02); c.fillStyle = '#2a2233'; c.beginPath(); c.ellipse(m, m + s * 0.1, s * 0.05, s * 0.035, 0, 0, TAU); c.fill(); cheeks();
  } else if (av.kind === 'bunny') {
    c.fillStyle = fur; c.beginPath(); c.ellipse(m - s * 0.17, m - s * 0.36, s * 0.1, s * 0.27, -0.12, 0, TAU); c.fill(); c.beginPath(); c.ellipse(m + s * 0.17, m - s * 0.36, s * 0.1, s * 0.27, 0.12, 0, TAU); c.fill();
    c.fillStyle = '#ffb0d0'; c.beginPath(); c.ellipse(m - s * 0.17, m - s * 0.34, s * 0.05, s * 0.2, -0.12, 0, TAU); c.fill(); c.beginPath(); c.ellipse(m + s * 0.17, m - s * 0.34, s * 0.05, s * 0.2, 0.12, 0, TAU); c.fill();
    c.fillStyle = fur; c.beginPath(); c.ellipse(m, m + s * 0.1, s * 0.4, s * 0.34, 0, 0, TAU); c.fill(); eyes(m + s * 0.04); c.fillStyle = '#ff7aa8'; c.beginPath(); c.ellipse(m, m + s * 0.14, s * 0.04, s * 0.03, 0, 0, TAU); c.fill(); cheeks();
  } else if (av.kind === 'frog') {
    c.fillStyle = fur; circ(c, m - s * 0.22, m - s * 0.22, s * 0.17); c.fill(); circ(c, m + s * 0.22, m - s * 0.22, s * 0.17); c.fill();
    c.beginPath(); c.ellipse(m, m + s * 0.1, s * 0.44, s * 0.34, 0, 0, TAU); c.fill();
    c.fillStyle = '#fff'; circ(c, m - s * 0.22, m - s * 0.22, s * 0.12); c.fill(); circ(c, m + s * 0.22, m - s * 0.22, s * 0.12); c.fill(); c.fillStyle = '#2a2233'; circ(c, m - s * 0.21, m - s * 0.21, s * 0.06); c.fill(); circ(c, m + s * 0.23, m - s * 0.21, s * 0.06); c.fill();
    c.strokeStyle = '#2a6a2a'; c.lineWidth = s * 0.03; c.lineCap = 'round'; c.beginPath(); c.arc(m, m + s * 0.08, s * 0.2, 0.25, Math.PI - 0.25); c.stroke(); cheeks();
  } else {
    c.fillStyle = fur; c.beginPath(); c.ellipse(m, m + s * 0.04, s * 0.4, s * 0.42, 0, 0, TAU); c.fill(); c.fillStyle = belly; c.beginPath(); c.ellipse(m, m + s * 0.14, s * 0.3, s * 0.3, 0, 0, TAU); c.fill();
    eyes(m - s * 0.02, 0.17); c.fillStyle = '#ffa42b'; path(c, [[m - s * 0.08, m + s * 0.06], [m + s * 0.08, m + s * 0.06], [m, m + s * 0.17]]); c.fill(); cheeks();
  }
  return cv;
}

export function priceTagCanvas(text, hex) {
  const cv = document.createElement('canvas'); cv.width = 256; cv.height = 128; const c = cv.getContext('2d');
  const col = '#' + hex.toString(16).padStart(6, '0');
  c.shadowColor = 'rgba(0,0,0,.3)'; c.shadowBlur = 10; c.shadowOffsetY = 4; c.fillStyle = '#fff'; rr(c, 20, 18, 216, 80, 38); c.fill(); c.shadowColor = 'transparent';
  c.fillStyle = col; rr(c, 30, 28, 196, 60, 30); c.fill();
  c.fillStyle = 'rgba(255,255,255,.28)'; rr(c, 38, 32, 180, 22, 11); c.fill();
  c.fillStyle = '#fff'; c.font = '800 44px ui-rounded, "SF Pro Rounded", system-ui, sans-serif'; c.textAlign = 'center'; c.textBaseline = 'middle'; c.lineWidth = 6; c.strokeStyle = 'rgba(0,0,0,.25)'; c.strokeText(text, 128, 60); c.fillText(text, 128, 60);
  return cv;
}
export function labelCanvas(text, bg, fg = '#fff', w = 512, h = 256, sub) {
  const cv = document.createElement('canvas'); cv.width = w; cv.height = h; const c = cv.getContext('2d');
  c.fillStyle = bg; c.fillRect(0, 0, w, h);
  c.fillStyle = fg; c.font = `900 ${h * (sub ? 0.4 : 0.5)}px ui-rounded, "SF Pro Rounded", system-ui, sans-serif`; c.textAlign = 'center'; c.textBaseline = 'middle'; c.fillText(text, w / 2, h * (sub ? 0.38 : 0.52));
  if (sub) { c.font = `800 ${h * 0.2}px ui-rounded, system-ui, sans-serif`; c.fillText(sub, w / 2, h * 0.76); }
  return cv;
}
export function makeTexture(THREE, cv, opt = {}) { const t = new THREE.CanvasTexture(cv); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 8; if (opt.repeat) { t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(opt.repeat[0], opt.repeat[1]); } return t; }
