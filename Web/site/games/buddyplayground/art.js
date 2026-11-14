// Procedural art for Buddy Playground: tool icons, outfits and room backdrops. Everything is drawn with canvas 2D.
const TAU = Math.PI * 2;

export function hex2rgb(h) { const n = parseInt(h.slice(1), 16); return [(n >> 16) & 255, (n >> 8) & 255, n & 255]; }
export function shade(h, a) { // a>0 lighten toward white, a<0 darken toward black
  const [r, g, b] = hex2rgb(h); const t = a < 0 ? 0 : 255, p = Math.abs(a);
  const f = (v) => Math.round(v + (t - v) * p);
  return `rgb(${f(r)},${f(g)},${f(b)})`;
}
export function rr(c, x, y, w, h, r) {
  r = Math.min(r, w / 2, h / 2);
  c.beginPath(); c.moveTo(x + r, y); c.lineTo(x + w - r, y); c.quadraticCurveTo(x + w, y, x + w, y + r); c.lineTo(x + w, y + h - r);
  c.quadraticCurveTo(x + w, y + h, x + w - r, y + h); c.lineTo(x + r, y + h); c.quadraticCurveTo(x, y + h, x, y + h - r);
  c.lineTo(x, y + r); c.quadraticCurveTo(x, y, x + r, y); c.closePath();
}
export function starPath(c, cx, cy, r1, r2, n = 5, rot = -Math.PI / 2) {
  c.beginPath();
  for (let i = 0; i < n * 2; i++) { const r = i % 2 ? r2 : r1, a = rot + i * Math.PI / n; const x = cx + Math.cos(a) * r, y = cy + Math.sin(a) * r; i ? c.lineTo(x, y) : c.moveTo(x, y); }
  c.closePath();
}
function lg(c, x0, y0, x1, y1, a, b) { const g = c.createLinearGradient(x0, y0, x1, y1); g.addColorStop(0, a); g.addColorStop(1, b); return g; }
function rg(c, x, y, r0, r1, a, b) { const g = c.createRadialGradient(x, y, r0, x, y, r1); g.addColorStop(0, a); g.addColorStop(1, b); return g; }
function fillStroke(c, fill, stroke, w = 4) { c.fillStyle = fill; c.fill(); if (stroke) { c.strokeStyle = stroke; c.lineWidth = w; c.lineJoin = 'round'; c.stroke(); } }
function gloss(c, x, y, rx, ry, rot = -0.5, a = 0.7) { c.save(); c.translate(x, y); c.rotate(rot); c.fillStyle = `rgba(255,255,255,${a})`; c.beginPath(); c.ellipse(0, 0, rx, ry, 0, 0, TAU); c.fill(); c.restore(); }

export function drawBeachBall(c, r, rot = 0) {
  c.save(); c.rotate(rot);
  const cols = ['#ff5d6c', '#ffd23f', '#3ec6ff', '#ffffff', '#58d68d', '#ff9f43'];
  c.beginPath(); c.arc(0, 0, r, 0, TAU); c.clip();
  for (let i = 0; i < 6; i++) { c.fillStyle = cols[i]; c.beginPath(); c.moveTo(0, 0); c.arc(0, 0, r * 1.1, i * TAU / 6, (i + 1) * TAU / 6); c.closePath(); c.fill(); }
  c.restore(); c.save();
  c.fillStyle = rg(c, -r * 0.35, -r * 0.4, r * 0.05, r * 1.1, 'rgba(255,255,255,0.5)', 'rgba(0,0,40,0.08)'); c.beginPath(); c.arc(0, 0, r, 0, TAU); c.fill();
  c.strokeStyle = 'rgba(40,40,90,0.35)'; c.lineWidth = Math.max(2, r * 0.07); c.stroke();
  c.fillStyle = '#fff'; c.beginPath(); c.arc(0, 0, r * 0.13, 0, TAU); c.fill(); c.restore();
}

export function drawCannon(c, color, recoil = 0, flip = 1) { // toy cannon facing +x, origin at the pivot
  c.save(); c.scale(flip, 1);
  c.fillStyle = 'rgba(0,0,0,0.18)'; c.beginPath(); c.ellipse(0, 44, 46, 9, 0, 0, TAU); c.fill();
  c.save(); c.translate(-recoil, 0);
  rr(c, -16, -20, 78, 40, 18); fillStroke(c, lg(c, 0, -20, 0, 20, shade(color, 0.35), color), shade(color, -0.35), 4);
  rr(c, 52, -25, 20, 50, 10); fillStroke(c, lg(c, 0, -25, 0, 25, '#fff6c9', '#ffd23f'), '#c9961f', 4);
  gloss(c, 20, -10, 22, 5, 0);
  c.restore();
  c.beginPath(); c.arc(-6, 22, 26, 0, TAU); fillStroke(c, lg(c, 0, -4, 0, 48, '#8a6bff', '#5b3fd4'), '#3b258f', 4);
  c.beginPath(); c.arc(-6, 22, 10, 0, TAU); fillStroke(c, '#ffd23f', '#c9961f', 3);
  c.restore();
}

// ---- tool icons: drawn inside a [-50,50] box --------------------------------------------------------
export function drawTool(c, id, t = 0) {
  c.lineCap = 'round'; c.lineJoin = 'round';
  switch (id) {
    case 'hand': {
      c.beginPath(); c.arc(0, 12, 28, 0, TAU); fillStroke(c, lg(c, 0, -10, 0, 44, '#ffffff', '#dbe6ff'), '#93a8dd');
      for (let i = 0; i < 4; i++) { const x = -21 + i * 14, h = i === 1 || i === 2 ? 30 : 24; rr(c, x - 7, -22 - (h - 24) - 6, 14, h + 10, 7); fillStroke(c, '#fff', '#93a8dd', 3.5); }
      c.save(); c.translate(-30, 14); c.rotate(-0.9); rr(c, -7, -22, 15, 28, 7); fillStroke(c, '#fff', '#93a8dd', 3.5); c.restore();
      c.beginPath(); c.arc(0, 12, 26, 0, TAU); c.fillStyle = lg(c, 0, -10, 0, 44, '#ffffff', '#dbe6ff'); c.fill();
      rr(c, -28, 30, 56, 18, 8); fillStroke(c, lg(c, 0, 30, 0, 48, '#ff7a8a', '#e04868'), '#a8294a', 3.5);
      gloss(c, -10, 2, 9, 5, -0.5);
      break; }
    case 'hammer': {
      c.save(); c.rotate(0.62);
      rr(c, -7, -6, 14, 64, 7); fillStroke(c, lg(c, -7, 0, 7, 0, '#e9b878', '#b87a3d'), '#7b4a1f', 3.5);
      c.strokeStyle = '#c9c9d8'; c.lineWidth = 5; c.beginPath(); for (let i = 0; i < 6; i++) { c.lineTo(i % 2 ? 6 : -6, 6 + i * 7); } c.stroke();
      rr(c, -34, -46, 68, 44, 20); fillStroke(c, lg(c, 0, -46, 0, -2, '#ff8fb8', '#ff4d8d'), '#a8214f', 4);
      rr(c, -34, -32, 68, 14, 4); c.fillStyle = '#ffd23f'; c.fill();
      starPath(c, 0, -25, 8, 3.5, 5); c.fillStyle = '#ff4d8d'; c.fill();
      gloss(c, -18, -38, 10, 4, 0);
      c.restore(); break; }
    case 'pillow': {
      rr(c, -40, -30, 80, 60, 26); fillStroke(c, rg(c, -12, -14, 4, 60, '#ffc2dd', '#ff8fbd'), '#d95b94', 4);
      for (const [x, y] of [[-40, -30], [40, -30], [-40, 30], [40, 30]]) { c.beginPath(); c.arc(x * 0.93, y * 0.93, 7, 0, TAU); c.fillStyle = '#ff8fbd'; c.fill(); c.stroke(); }
      rr(c, -30, -21, 60, 42, 18); c.setLineDash([5, 5]); c.strokeStyle = 'rgba(255,255,255,0.85)'; c.lineWidth = 2.5; c.stroke(); c.setLineDash([]);
      c.fillStyle = '#fff'; c.beginPath(); c.moveTo(0, 12); c.bezierCurveTo(-20, -2, -8, -18, 0, -6); c.bezierCurveTo(8, -18, 20, -2, 0, 12); c.fill();
      gloss(c, -18, -18, 12, 4, -0.3);
      break; }
    case 'confetti': {
      c.save(); c.rotate(0.55); c.translate(0, 8);
      c.beginPath(); c.moveTo(-12, 44); c.lineTo(12, 44); c.lineTo(28, -8); c.lineTo(-28, -8); c.closePath(); fillStroke(c, lg(c, -28, 0, 28, 0, '#ffe27a', '#ffb52e'), '#c47d12', 4);
      c.save(); c.clip(); c.fillStyle = '#ff5d8f'; for (let i = -2; i < 4; i++) { c.beginPath(); c.moveTo(-40 + i * 22, 50); c.lineTo(-24 + i * 22, 50); c.lineTo(-4 + i * 22, -10); c.lineTo(-20 + i * 22, -10); c.fill(); } c.restore();
      c.beginPath(); c.ellipse(0, -8, 28, 8, 0, 0, TAU); fillStroke(c, '#7a4b12', '#c47d12', 3);
      c.restore();
      const cols = ['#ff5d8f', '#3ec6ff', '#ffd23f', '#58d68d', '#b57bff'];
      for (let i = 0; i < 12; i++) { const a = -1.9 + i * 0.22, d = 24 + (i % 4) * 8; c.save(); c.translate(Math.cos(a) * d - 6, Math.sin(a) * d - 14); c.rotate(i); c.fillStyle = cols[i % 5]; if (i % 3 === 0) { c.beginPath(); c.arc(0, 0, 3.4, 0, TAU); c.fill(); } else c.fillRect(-4, -2, 8, 4); c.restore(); }
      break; }
    case 'water': {
      c.beginPath(); c.moveTo(0, -42); c.bezierCurveTo(36, -38, 40, 16, 8, 34); c.lineTo(-8, 34); c.bezierCurveTo(-40, 16, -36, -38, 0, -42); c.closePath(); fillStroke(c, rg(c, -10, -16, 3, 54, '#9be6ff', '#2f9cff'), '#1766c7', 4);
      c.beginPath(); c.moveTo(-8, 34); c.lineTo(8, 34); c.lineTo(5, 42); c.lineTo(-5, 42); c.closePath(); fillStroke(c, '#2f9cff', '#1766c7', 3);
      gloss(c, -14, -18, 7, 14, 0.3, 0.8);
      c.fillStyle = 'rgba(255,255,255,0.8)'; c.beginPath(); c.arc(16, 8, 3, 0, TAU); c.fill();
      break; }
    case 'tramp': {
      c.strokeStyle = '#5b6cff'; c.lineWidth = 7; for (const x of [-34, 34]) { c.beginPath(); c.moveTo(x, 6); c.lineTo(x * 1.1, 42); c.stroke(); }
      c.strokeStyle = '#8fd0ff'; c.lineWidth = 3; for (let i = -3; i <= 3; i++) { c.beginPath(); c.moveTo(i * 12, 6); c.lineTo(i * 12 * 1.05, 20); c.stroke(); }
      c.beginPath(); c.ellipse(0, 4, 46, 15, 0, 0, TAU); fillStroke(c, '#ff5d8f', '#b82f63', 4);
      c.beginPath(); c.ellipse(0, 3, 38, 11, 0, 0, TAU); fillStroke(c, lg(c, 0, -8, 0, 14, '#7ad8ff', '#2f9cff'), null);
      c.strokeStyle = 'rgba(255,255,255,0.7)'; c.lineWidth = 3; c.beginPath(); c.arc(0, -14, 14, 3.5, 5.9); c.stroke();
      c.beginPath(); c.arc(0, -26, 8, 3.7, 5.7); c.stroke();
      break; }
    case 'beach': {
      drawBeachBall(c, 38, 0.4);
      break; }
    case 'magnet': {
      c.lineCap = 'butt'; c.strokeStyle = '#a8294a'; c.lineWidth = 30; c.beginPath(); c.arc(0, -2, 26, Math.PI, TAU); c.lineTo(26, 28); c.moveTo(-26, -2); c.lineTo(-26, 28); c.stroke();
      c.strokeStyle = lg(c, -30, -30, 30, 10, '#ff8a9a', '#e0334f'); c.lineWidth = 24; c.beginPath(); c.arc(0, -2, 26, Math.PI, TAU); c.lineTo(26, 28); c.moveTo(-26, -2); c.lineTo(-26, 28); c.stroke();
      c.lineCap = 'round'; for (const x of [-26, 26]) { c.fillStyle = '#e8eef9'; c.fillRect(x - 12, 26, 24, 16); c.strokeStyle = '#8a97b8'; c.lineWidth = 3; c.strokeRect(x - 12, 26, 24, 16); }
      c.strokeStyle = 'rgba(255,255,255,0.7)'; c.lineWidth = 4; c.beginPath(); c.arc(0, -2, 26, 3.5, 4.9); c.stroke();
      c.fillStyle = '#ffd23f'; starPath(c, 0, 40, 6, 2.5, 4); c.fill(); starPath(c, 38, -34, 7, 3, 4); c.fill();
      break; }
    case 'balloons': {
      const bs = [[-22, -16, '#ff5d8f'], [20, -22, '#ffd23f'], [0, 4, '#3ec6ff']];
      c.strokeStyle = 'rgba(80,80,110,0.7)'; c.lineWidth = 2; for (const [x, y] of bs) { c.beginPath(); c.moveTo(x, y + 32); c.quadraticCurveTo(x * 0.3 + 6, 40, 0, 48); c.stroke(); }
      for (const [x, y, col] of bs) { c.beginPath(); c.ellipse(x, y, 22, 27, 0, 0, TAU); fillStroke(c, rg(c, x - 7, y - 10, 2, 34, shade(col, 0.55), col), shade(col, -0.3), 3.5); c.beginPath(); c.moveTo(x - 4, y + 26); c.lineTo(x + 4, y + 26); c.lineTo(x, y + 32); c.fillStyle = shade(col, -0.2); c.fill(); gloss(c, x - 8, y - 10, 4, 8, 0.3, 0.7); }
      break; }
    case 'feather': {
      c.save(); c.rotate(0.65);
      c.beginPath(); c.moveTo(0, 52); c.bezierCurveTo(-34, 20, -32, -30, 0, -52); c.bezierCurveTo(32, -30, 34, 20, 0, 52); c.closePath(); fillStroke(c, lg(c, -30, -40, 30, 40, '#ff9ee0', '#8a6bff'), '#5b3fd4', 4);
      c.strokeStyle = 'rgba(255,255,255,0.55)'; c.lineWidth = 2.5; for (let i = -3; i <= 3; i++) { c.beginPath(); c.moveTo(0, i * 12 + 10); c.quadraticCurveTo(-14, i * 12 - 2, -22 + Math.abs(i) * 3, i * 12 - 10); c.moveTo(0, i * 12 + 10); c.quadraticCurveTo(14, i * 12 - 2, 22 - Math.abs(i) * 3, i * 12 - 10); c.stroke(); }
      c.strokeStyle = '#fff4c0'; c.lineWidth = 4; c.beginPath(); c.moveTo(0, 56); c.lineTo(0, -46); c.stroke();
      c.restore(); break; }
    case 'icecream': {
      c.beginPath(); c.moveTo(-22, -2); c.lineTo(22, -2); c.lineTo(0, 50); c.closePath(); fillStroke(c, lg(c, -20, 0, 20, 40, '#ffd48a', '#e3a04a'), '#a96d22', 4);
      c.save(); c.clip(); c.strokeStyle = 'rgba(150,90,20,0.45)'; c.lineWidth = 2.5; for (let i = -4; i < 6; i++) { c.beginPath(); c.moveTo(-30 + i * 10, -4); c.lineTo(10 + i * 10, 50); c.moveTo(30 - i * 10, -4); c.lineTo(-10 - i * 10, 50); c.stroke(); } c.restore();
      c.beginPath(); c.arc(0, -8, 26, 0, TAU); fillStroke(c, rg(c, -8, -18, 2, 34, '#ffd6ec', '#ff8fc2'), '#d85a98', 4);
      c.beginPath(); c.arc(0, -32, 18, 0, TAU); fillStroke(c, rg(c, -6, -40, 2, 24, '#d8fff0', '#79e0b8'), '#2fa57a', 4);
      c.beginPath(); c.arc(0, -52, 7, 0, TAU); fillStroke(c, '#ff3d5a', '#a8132b', 3); gloss(c, -2, -54, 2, 2, 0);
      break; }
    case 'cupcake': {
      c.beginPath(); c.moveTo(-28, 2); c.lineTo(28, 2); c.lineTo(21, 42); c.lineTo(-21, 42); c.closePath(); fillStroke(c, lg(c, 0, 0, 0, 44, '#8fe3ff', '#4fb8f0'), '#2677a8', 4);
      c.save(); c.clip(); c.fillStyle = 'rgba(255,255,255,0.4)'; for (let i = -3; i < 4; i++) c.fillRect(i * 14 - 3, 0, 6, 50); c.restore();
      for (const [y, rx, col] of [[-2, 34, '#ffd2e6'], [-16, 26, '#ff9ec7'], [-29, 17, '#ffd2e6']]) { c.beginPath(); c.ellipse(0, y, rx, 15, 0, 0, TAU); fillStroke(c, lg(c, 0, y - 14, 0, y + 14, shade(col, 0.4), col), '#d85a98', 3.5); }
      c.beginPath(); c.arc(0, -46, 7, 0, TAU); fillStroke(c, '#ff3d5a', '#a8132b', 3);
      const sp = ['#ffd23f', '#3ec6ff', '#58d68d', '#fff']; for (let i = 0; i < 9; i++) { c.save(); c.translate(-20 + (i * 17) % 40, -26 + (i * 7) % 26); c.rotate(i); c.fillStyle = sp[i % 4]; c.fillRect(-3, -1.5, 6, 3); c.restore(); }
      break; }
    case 'fan': {
      c.fillStyle = '#6a7cff'; rr(c, -6, 20, 12, 28, 5); c.fill(); rr(c, -28, 42, 56, 10, 5); c.fill();
      c.beginPath(); c.arc(0, -4, 40, 0, TAU); fillStroke(c, 'rgba(200,225,255,0.55)', '#3a4ccf', 5);
      c.save(); c.translate(0, -4); c.rotate(t * 8);
      for (let i = 0; i < 4; i++) { c.save(); c.rotate(i * Math.PI / 2); c.beginPath(); c.ellipse(0, -18, 11, 19, 0, 0, TAU); fillStroke(c, lg(c, -10, -30, 10, -6, '#9be6ff', '#3ea8ff'), '#1f6ec7', 3); c.restore(); }
      c.beginPath(); c.arc(0, 0, 8, 0, TAU); fillStroke(c, '#ffd23f', '#c9961f', 3); c.restore();
      c.strokeStyle = '#3a4ccf'; c.lineWidth = 2.5; for (const r of [14, 27]) { c.beginPath(); c.arc(0, -4, r + 12, 0, TAU); c.globalAlpha = 0.25; c.stroke(); c.globalAlpha = 1; }
      break; }
    case 'mushroom': {
      rr(c, -17, -2, 34, 48, 16); fillStroke(c, lg(c, -17, 0, 17, 0, '#fff4e0', '#f0d3a6'), '#b98d52', 4);
      c.beginPath(); c.moveTo(-44, 6); c.bezierCurveTo(-46, -46, 46, -46, 44, 6); c.quadraticCurveTo(0, 18, -44, 6); c.closePath(); fillStroke(c, rg(c, -12, -22, 3, 56, '#ff8a8a', '#e8283e'), '#9c1428', 4);
      c.fillStyle = '#fff'; for (const [x, y, r] of [[-20, -8, 8], [12, -22, 9], [24, -4, 7], [-2, -2, 5]]) { c.beginPath(); c.arc(x, y, r, 0, TAU); c.fill(); }
      gloss(c, -26, -24, 9, 4, -0.9, 0.55);
      break; }
    case 'glitter': {
      c.strokeStyle = '#ffd23f'; c.lineWidth = 4; c.beginPath(); c.moveTo(0, -30); c.quadraticCurveTo(10, -46, 4, -52); c.stroke();
      c.beginPath(); c.arc(0, 4, 34, 0, TAU); fillStroke(c, rg(c, -10, -12, 2, 48, '#ffb8f0', '#7a4bff'), '#4a1fb8', 4);
      c.save(); c.clip(); c.strokeStyle = 'rgba(255,255,255,0.35)'; c.lineWidth = 1.6; for (let i = -4; i <= 4; i++) { c.beginPath(); c.ellipse(0, 4, Math.abs(i) * 8 + 1, 34, 0, 0, TAU); c.stroke(); c.beginPath(); c.moveTo(-34, 4 + i * 8); c.lineTo(34, 4 + i * 8); c.stroke(); } c.restore();
      gloss(c, -14, -12, 9, 5, -0.7, 0.75);
      c.fillStyle = '#fff'; for (const [x, y, r] of [[18, -2, 7], [-22, 16, 5], [6, 24, 4], [32, -30, 8], [-38, -22, 6]]) { starPath(c, x, y, r, r * 0.35, 4); c.fill(); }
      c.fillStyle = '#ffd23f'; starPath(c, 0, -34, 7, 3, 4); c.fill();
      break; }
    default: break;
  }
}

// ---- outfits ----------------------------------------------------------------------------------------
export const SKINS = {
  peach: '#ffb48a', pink: '#ff9fc4', mint: '#7fe0b8', sky: '#74c7ff', grape: '#b58aff', lemon: '#ffd95a',
};

// slot 'hat' | 'face': drawn in head space (origin = head centre, radius R). 'helmet' is drawn after everything.
export function drawHead(c, id, R, t = 0) {
  c.lineJoin = 'round'; c.lineCap = 'round';
  switch (id) {
    case 'party': {
      c.save(); c.rotate(0.16); c.translate(0, -R * 0.78);
      c.beginPath(); c.moveTo(-R * 0.42, R * 0.1); c.lineTo(R * 0.42, R * 0.1); c.lineTo(0, -R * 1.0); c.closePath(); fillStroke(c, lg(c, -R * 0.4, 0, R * 0.4, 0, '#ff8fd0', '#b57bff'), '#6b3fc4', 3.5);
      c.save(); c.clip(); c.fillStyle = '#ffd23f'; for (let i = 0; i < 3; i++) { c.beginPath(); c.moveTo(-R * 0.6, -R * 0.15 - i * R * 0.34 + R * 0.34); c.lineTo(R * 0.6, -R * 0.45 - i * R * 0.34 + R * 0.34); c.lineTo(R * 0.6, -R * 0.32 - i * R * 0.34 + R * 0.34); c.lineTo(-R * 0.6, -R * 0.02 - i * R * 0.34 + R * 0.34); c.fill(); } c.restore();
      c.beginPath(); c.arc(0, -R * 1.02, R * 0.14, 0, TAU); fillStroke(c, '#ffd23f', '#c9961f', 3);
      c.restore(); break; }
    case 'crown': {
      c.save(); c.translate(0, -R * 0.84); const w = R * 0.56;
      c.beginPath(); c.moveTo(-w, R * 0.16); c.lineTo(-w, -R * 0.2); c.lineTo(-w * 0.5, -R * 0.02); c.lineTo(0, -R * 0.36); c.lineTo(w * 0.5, -R * 0.02); c.lineTo(w, -R * 0.2); c.lineTo(w, R * 0.16); c.closePath(); fillStroke(c, lg(c, 0, -R * 0.3, 0, R * 0.2, '#fff29a', '#ffb52e'), '#b57a12', 3.5);
      for (const [x, y, col] of [[-w * 0.7, 0, '#ff5d8f'], [0, -R * 0.02, '#3ec6ff'], [w * 0.7, 0, '#58d68d']]) { c.beginPath(); c.arc(x, y + R * 0.02, R * 0.07, 0, TAU); fillStroke(c, col, '#fff', 1.5); }
      for (const x of [-w, 0, w]) { c.beginPath(); c.arc(x, -R * (x === 0 ? 0.36 : 0.2), R * 0.06, 0, TAU); fillStroke(c, '#fff29a', '#b57a12', 2.5); }
      c.restore(); break; }
    case 'wizard': {
      c.save(); c.translate(0, -R * 0.78);
      c.beginPath(); c.moveTo(-R * 0.55, R * 0.12); c.quadraticCurveTo(-R * 0.1, -R * 0.5, R * 0.2, -R * 1.0); c.quadraticCurveTo(R * 0.5, -R * 1.18, R * 0.62, -R * 0.78); c.quadraticCurveTo(R * 0.46, -R * 0.4, R * 0.55, R * 0.12); c.closePath(); fillStroke(c, lg(c, -R * 0.5, 0, R * 0.5, 0, '#8a6bff', '#4a2fc4'), '#2a1a86', 3.5);
      c.beginPath(); c.ellipse(0, R * 0.14, R * 0.86, R * 0.2, 0, 0, TAU); fillStroke(c, lg(c, 0, 0, 0, R * 0.3, '#8a6bff', '#4a2fc4'), '#2a1a86', 3.5);
      c.fillStyle = '#ffd23f'; starPath(c, -R * 0.08, -R * 0.2, R * 0.13, R * 0.05); c.fill(); starPath(c, R * 0.2, -R * 0.55, R * 0.09, R * 0.035); c.fill();
      c.restore(); break; }
    case 'beanie': {
      c.save(); c.translate(0, -R * 0.62);
      c.beginPath(); c.moveTo(-R * 0.92, R * 0.1); c.bezierCurveTo(-R * 0.95, -R * 0.75, R * 0.95, -R * 0.75, R * 0.92, R * 0.1); c.closePath(); fillStroke(c, lg(c, -R, 0, R, 0, '#ff7a8a', '#e84860'), '#a0213a', 3.5);
      c.save(); c.clip(); c.strokeStyle = 'rgba(255,255,255,0.5)'; c.lineWidth = R * 0.1; for (let i = -4; i < 5; i++) { c.beginPath(); c.moveTo(i * R * 0.22, -R); c.lineTo(i * R * 0.22 + R * 0.1, R * 0.2); c.stroke(); } c.restore();
      rr(c, -R * 0.96, -R * 0.1, R * 1.92, R * 0.3, R * 0.14); fillStroke(c, '#fff', '#c9c9e0', 3);
      c.beginPath(); c.arc(0, -R * 0.64, R * 0.2, 0, TAU); fillStroke(c, '#fff', '#c9c9e0', 3);
      c.restore(); break; }
    case 'helmet': {
      c.beginPath(); c.arc(0, 0, R * 1.14, 0, TAU); c.fillStyle = 'rgba(190,230,255,0.16)'; c.fill(); c.strokeStyle = 'rgba(255,255,255,0.85)'; c.lineWidth = 4; c.stroke();
      c.strokeStyle = 'rgba(255,255,255,0.7)'; c.lineWidth = 5; c.beginPath(); c.arc(0, 0, R * 0.98, 3.6, 4.5); c.stroke();
      c.lineWidth = 3; c.beginPath(); c.arc(0, 0, R * 0.98, 4.7, 4.95); c.stroke();
      c.save(); c.translate(0, R * 1.0); c.beginPath(); c.ellipse(0, 0, R * 0.78, R * 0.2, 0, 0, TAU); fillStroke(c, lg(c, 0, -R * 0.2, 0, R * 0.2, '#ffffff', '#b8c4de'), '#7c89ad', 3); c.restore();
      break; }
    case 'sunglasses': {
      c.fillStyle = '#20243a'; for (const s of [-1, 1]) { rr(c, s * R * 0.37 - R * 0.27, -R * 0.2, R * 0.54, R * 0.4, R * 0.16); c.fill(); gloss(c, s * R * 0.37 - R * 0.08, -R * 0.08, R * 0.1, R * 0.035, -0.4, 0.5); }
      c.strokeStyle = '#20243a'; c.lineWidth = R * 0.06; c.beginPath(); c.moveTo(-R * 0.1, -R * 0.06); c.quadraticCurveTo(0, -R * 0.14, R * 0.1, -R * 0.06); c.stroke();
      c.beginPath(); c.moveTo(-R * 0.64, -R * 0.05); c.lineTo(-R * 0.92, -R * 0.12); c.moveTo(R * 0.64, -R * 0.05); c.lineTo(R * 0.92, -R * 0.12); c.stroke();
      break; }
    case 'starglasses': {
      for (const s of [-1, 1]) { starPath(c, s * R * 0.38, -R * 0.04, R * 0.34, R * 0.2, 5, -Math.PI / 2); fillStroke(c, 'rgba(255,110,190,0.8)', '#ffd23f', R * 0.07); }
      c.strokeStyle = '#ffd23f'; c.lineWidth = R * 0.06; c.beginPath(); c.moveTo(-R * 0.1, -R * 0.06); c.lineTo(R * 0.1, -R * 0.06); c.stroke();
      break; }
    case 'clownnose': {
      c.beginPath(); c.arc(0, R * 0.2, R * 0.15, 0, TAU); fillStroke(c, rg(c, -R * 0.04, R * 0.15, 1, R * 0.17, '#ff8a8a', '#e8283e'), '#a0132b', 2.5);
      gloss(c, -R * 0.05, R * 0.15, R * 0.04, R * 0.025, -0.5, 0.9);
      break; }
    default: break;
  }
}

// neck accessories drawn in torso space (origin = torso centre, w/h = torso size)
export function drawNeck(c, id, w, h) {
  c.lineJoin = 'round'; c.lineCap = 'round';
  c.save(); c.translate(0, -h * 0.5 + h * 0.26);
  if (id === 'bowtie') {
    for (const s of [-1, 1]) { c.beginPath(); c.moveTo(0, 0); c.lineTo(s * w * 0.3, -w * 0.15); c.quadraticCurveTo(s * w * 0.36, 0, s * w * 0.3, w * 0.15); c.closePath(); fillStroke(c, lg(c, 0, -w * 0.15, 0, w * 0.15, '#ff6a8a', '#d92a58'), '#8f1636', 3); }
    c.beginPath(); c.arc(0, 0, w * 0.07, 0, TAU); fillStroke(c, '#ff8fb0', '#8f1636', 2.5);
  } else if (id === 'scarf') {
    rr(c, -w * 0.46, -w * 0.07, w * 0.92, w * 0.19, w * 0.09); fillStroke(c, lg(c, 0, 0, 0, w * 0.16, '#59d6a8', '#2aa57a'), '#176e4f', 3);
    c.save(); c.translate(w * 0.22, w * 0.1); c.rotate(-0.15); rr(c, 0, 0, w * 0.2, w * 0.44, w * 0.06); fillStroke(c, lg(c, 0, 0, 0, w * 0.4, '#59d6a8', '#2aa57a'), '#176e4f', 3); c.fillStyle = '#fff'; c.fillRect(2, w * 0.14, w * 0.2 - 4, w * 0.06); c.fillRect(2, w * 0.28, w * 0.2 - 4, w * 0.06); c.restore();
  }
  c.restore();
}

// back accessories drawn behind torso in torso space
export function drawBack(c, id, w, h, flutter, t) {
  c.lineJoin = 'round'; c.lineCap = 'round';
  if (id === 'cape') {
    const f = Math.max(-34, Math.min(34, flutter));
    c.beginPath(); c.moveTo(-w * 0.46, -h * 0.4); c.quadraticCurveTo(-w * 0.95 + f, h * 0.1, -w * 0.82 + f * 1.5, h * 0.78); c.quadraticCurveTo(0 + f * 1.2, h * 0.92, w * 0.82 + f * 1.5, h * 0.78); c.quadraticCurveTo(w * 0.95 + f, h * 0.1, w * 0.46, -h * 0.4); c.closePath();
    fillStroke(c, lg(c, 0, -h * 0.4, 0, h * 0.8, '#ff5d6c', '#c7213a'), '#8a1228', 4);
    c.strokeStyle = 'rgba(255,255,255,0.25)'; c.lineWidth = 3; c.beginPath(); c.moveTo(-w * 0.2, -h * 0.2); c.quadraticCurveTo(-w * 0.28 + f * 0.6, h * 0.2, -w * 0.3 + f, h * 0.6); c.stroke();
  } else if (id === 'wings') {
    const fl = Math.sin(t * 9) * 0.12;
    for (const s of [-1, 1]) { c.save(); c.translate(s * w * 0.3, -h * 0.2); c.rotate(s * (0.5 + fl)); c.scale(s, 1);
      c.beginPath(); c.moveTo(0, 0); c.bezierCurveTo(w * 0.2, -h * 0.9, w * 1.15, -h * 0.85, w * 0.95, -h * 0.15); c.bezierCurveTo(w * 0.75, h * 0.15, w * 0.2, h * 0.1, 0, 0); c.closePath();
      fillStroke(c, lg(c, 0, -h * 0.6, w, 0, 'rgba(255,255,255,0.95)', 'rgba(255,190,240,0.9)'), '#e08ac8', 3.5);
      c.strokeStyle = 'rgba(224,138,200,0.6)'; c.lineWidth = 2; c.beginPath(); c.moveTo(w * 0.1, -h * 0.05); c.quadraticCurveTo(w * 0.5, -h * 0.5, w * 0.85, -h * 0.28); c.stroke(); c.restore(); }
  }
}

export const OUTFITS = {
  skins: [['peach', 'Peachy', 0], ['pink', 'Bubblegum', 30], ['mint', 'Minty', 30], ['sky', 'Skyblue', 40], ['grape', 'Grapey', 50], ['lemon', 'Lemony', 50]],
  hat: [['party', 'Party Hat', 40], ['beanie', 'Cozy Beanie', 50], ['wizard', 'Wizard Hat', 90], ['crown', 'Royal Crown', 120], ['helmet', 'Space Helmet', 150]],
  face: [['sunglasses', 'Cool Shades', 50], ['starglasses', 'Star Specs', 70], ['clownnose', 'Red Nose', 40]],
  neck: [['bowtie', 'Bow Tie', 40], ['scarf', 'Cozy Scarf', 60]],
  back: [['cape', 'Hero Cape', 90], ['wings', 'Fairy Wings', 130]],
};

// ---- rooms --------------------------------------------------------------------------------------------
function rand(seed) { let a = seed >>> 0; return () => { a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
function cloud(c, x, y, s, a = 0.9) { c.fillStyle = `rgba(255,255,255,${a})`; c.beginPath(); for (const [dx, dy, r] of [[0, 0, 26], [28, -10, 32], [58, 0, 24], [30, 8, 28], [-4, 6, 20]]) { c.moveTo(x + dx * s + r * s, y + dy * s); c.arc(x + dx * s, y + dy * s, r * s, 0, TAU); } c.fill(); }
function glow(c, x, y, r, col) { const g = c.createRadialGradient(x, y, 0, x, y, r); g.addColorStop(0, col); g.addColorStop(1, col.replace(/[\d.]+\)$/, '0)')); c.fillStyle = g; c.fillRect(x - r, y - r, r * 2, r * 2); }

export const ROOMS = [['playroom', 'Playroom', 0], ['beach', 'Sunny Beach', 100], ['snow', 'Snow Land', 180], ['space', 'Moon Base', 260]];

export function drawRoom(c, room, W, H, floorY) {
  const R = rand(room.length * 977 + 13);
  const fy = floorY - 24; // visual floor edge (feet stand a little way into the floor)
  const fn = ROOM_DRAW[room] || ROOM_DRAW.playroom; fn(c, W, H, fy, R);
  // soft vignette
  const v = c.createRadialGradient(W / 2, H * 0.45, Math.min(W, H) * 0.35, W / 2, H * 0.5, Math.max(W, H) * 0.8); v.addColorStop(0, 'rgba(0,0,0,0)'); v.addColorStop(1, 'rgba(30,10,60,0.22)'); c.fillStyle = v; c.fillRect(0, 0, W, H);
}

const ROOM_DRAW = {
  playroom(c, W, H, fy, R) {
    c.fillStyle = lg(c, 0, 0, 0, fy, '#ffe8b8', '#ffc9d9'); c.fillRect(0, 0, W, fy);
    c.fillStyle = 'rgba(255,255,255,0.35)'; for (let x = 0; x < W; x += 90) c.fillRect(x, 0, 45, fy);
    c.fillStyle = 'rgba(255,255,255,0.45)'; for (let y = 30; y < fy - 60; y += 64) for (let x = (y / 64 % 2) * 32 + 20; x < W; x += 64) { c.beginPath(); c.arc(x, y, 5, 0, TAU); c.fill(); }
    // wainscot
    const wy = fy - Math.min(120, H * 0.16); c.fillStyle = lg(c, 0, wy, 0, fy, '#a8e6d8', '#7fd0c0'); c.fillRect(0, wy, W, fy - wy);
    c.fillStyle = 'rgba(255,255,255,0.28)'; for (let x = 20; x < W; x += 80) { rr(c, x, wy + 16, 56, fy - wy - 30, 12); c.fill(); }
    c.fillStyle = '#fff'; c.fillRect(0, wy - 7, W, 10); c.fillStyle = 'rgba(0,0,0,0.08)'; c.fillRect(0, wy + 3, W, 4);
    // window
    const ww = Math.min(240, W * 0.26), wh = ww * 0.9, wx = W * 0.12, wyy = Math.max(70, fy * 0.1);
    rr(c, wx - 12, wyy - 12, ww + 24, wh + 24, 22); c.fillStyle = '#fff'; c.fill(); c.strokeStyle = '#e6c9a0'; c.lineWidth = 3; c.stroke();
    c.save(); rr(c, wx, wyy, ww, wh, 14); c.clip(); c.fillStyle = lg(c, 0, wyy, 0, wyy + wh, '#8fdcff', '#d9f6ff'); c.fillRect(wx, wyy, ww, wh);
    glow(c, wx + ww * 0.75, wyy + wh * 0.28, 70, 'rgba(255,240,150,0.9)'); c.fillStyle = '#ffe36a'; c.beginPath(); c.arc(wx + ww * 0.75, wyy + wh * 0.28, 20, 0, TAU); c.fill();
    cloud(c, wx + 20, wyy + 40, 0.9); cloud(c, wx + ww * 0.55, wyy + wh * 0.62, 0.7);
    c.fillStyle = '#74d08a'; c.beginPath(); c.ellipse(wx + ww * 0.3, wyy + wh + 20, ww * 0.7, wh * 0.3, 0, 0, TAU); c.fill(); c.restore();
    c.fillStyle = '#fff'; c.fillRect(wx + ww / 2 - 4, wyy, 8, wh); c.fillRect(wx, wyy + wh / 2 - 4, ww, 8);
    c.fillStyle = '#ff8fb8'; c.beginPath(); c.moveTo(wx - 26, wyy - 16); c.quadraticCurveTo(wx + 14, wyy + wh * 0.5, wx - 26, wyy + wh + 10); c.lineTo(wx - 8, wyy + wh + 10); c.quadraticCurveTo(wx + 30, wyy + wh * 0.5, wx - 8, wyy - 16); c.fill();
    c.beginPath(); c.moveTo(wx + ww + 26, wyy - 16); c.quadraticCurveTo(wx + ww - 14, wyy + wh * 0.5, wx + ww + 26, wyy + wh + 10); c.lineTo(wx + ww + 8, wyy + wh + 10); c.quadraticCurveTo(wx + ww - 30, wyy + wh * 0.5, wx + ww + 8, wyy - 16); c.fill();
    // bunting
    const cols = ['#ff5d8f', '#ffd23f', '#3ec6ff', '#58d68d', '#b57bff']; c.strokeStyle = '#8a6b4a'; c.lineWidth = 3; c.beginPath(); c.moveTo(0, 14); c.quadraticCurveTo(W / 2, 70, W, 14); c.stroke();
    for (let i = 0; i < 18; i++) { const t = (i + 0.5) / 18, x = W * t, y = 14 + (1 - Math.pow(2 * t - 1, 2)) * 28 + 3; c.fillStyle = cols[i % 5]; c.beginPath(); c.moveTo(x - 17, y); c.lineTo(x + 17, y); c.lineTo(x, y + 36); c.closePath(); c.fill(); }
    // shelf with toys (right)
    const sx = W * 0.7, sy = Math.max(160, fy * 0.3), sw = Math.min(300, W * 0.28);
    rr(c, sx, sy, sw, 14, 6); c.fillStyle = '#d89a5a'; c.fill(); c.fillStyle = 'rgba(0,0,0,0.12)'; c.fillRect(sx + 6, sy + 14, sw - 12, 6);
    const blocks = [['#ff5d8f', 'A'], ['#3ec6ff', 'B'], ['#ffd23f', 'C']]; blocks.forEach(([col, ch], i) => { const bx = sx + 16 + i * 52, by = sy - 46; rr(c, bx, by, 46, 46, 8); fillStroke(c, col, shade(col, -0.3), 3); c.fillStyle = '#fff'; c.font = '800 26px ui-rounded,system-ui,sans-serif'; c.textAlign = 'center'; c.fillText(ch, bx + 23, by + 33); });
    c.fillStyle = '#b57bff'; c.beginPath(); c.arc(sx + sw - 50, sy - 24, 24, 0, TAU); c.fill(); c.fillStyle = '#fff'; c.beginPath(); c.arc(sx + sw - 58, sy - 30, 6, 0, TAU); c.fill();
    c.fillStyle = '#ffd23f'; starPath(c, sx + sw - 18, sy - 24, 18, 8); c.fill();
    // floor
    c.fillStyle = lg(c, 0, fy, 0, H, '#f4c283', '#d99a58'); c.fillRect(0, fy, W, H - fy);
    c.strokeStyle = 'rgba(140,80,30,0.25)'; c.lineWidth = 2; for (let y = fy + 30; y < H; y += 40) { c.beginPath(); c.moveTo(0, y); c.lineTo(W, y); c.stroke(); }
    for (let i = 0; i < 30; i++) { const x = R() * W, y = fy + 10 + R() * (H - fy), len = 40 + R() * 90; c.beginPath(); c.moveTo(x, y); c.lineTo(x + len, y); c.stroke(); }
    c.fillStyle = 'rgba(255,255,255,0.25)'; c.fillRect(0, fy, W, 5); c.fillStyle = 'rgba(120,60,20,0.22)'; c.fillRect(0, fy - 4, W, 4);
    // rug
    c.save(); c.translate(W / 2, fy + (H - fy) * 0.45); c.scale(1, 0.2); for (const [r, col] of [[Math.min(380, W * 0.36), '#ff8fb8'], [Math.min(330, W * 0.31), '#fff2f7'], [Math.min(280, W * 0.26), '#7fd0ff'], [Math.min(220, W * 0.2), '#fff2f7'], [Math.min(170, W * 0.15), '#ffd23f']]) { c.fillStyle = col; c.beginPath(); c.arc(0, 0, r, 0, TAU); c.fill(); } c.restore();
  },
  beach(c, W, H, fy, R) {
    c.fillStyle = lg(c, 0, 0, 0, fy, '#5ec8ff', '#d9f7ff'); c.fillRect(0, 0, W, fy);
    glow(c, W * 0.8, fy * 0.2, 220, 'rgba(255,246,170,0.85)'); c.fillStyle = '#fff3a0'; c.beginPath(); c.arc(W * 0.8, fy * 0.2, 46, 0, TAU); c.fill();
    cloud(c, W * 0.1, fy * 0.14, 1.4); cloud(c, W * 0.45, fy * 0.08, 1.0, 0.8); cloud(c, W * 0.62, fy * 0.3, 1.2, 0.85);
    const hy = fy * 0.62; c.fillStyle = lg(c, 0, hy, 0, fy, '#2fc2e8', '#7fe3f0'); c.fillRect(0, hy, W, fy - hy);
    c.strokeStyle = 'rgba(255,255,255,0.7)'; c.lineWidth = 3; for (let k = 0; k < 4; k++) { const y = hy + 14 + k * ((fy - hy) / 4.4); c.beginPath(); for (let x = 0; x <= W; x += 10) { const yy = y + Math.sin(x * 0.03 + k * 2) * 4; x ? c.lineTo(x, yy) : c.moveTo(x, yy); } c.stroke(); }
    c.fillStyle = 'rgba(255,255,255,0.85)'; c.fillRect(0, fy - 10, W, 6);
    // palm
    const px = W * 0.1; c.strokeStyle = '#b07a3f'; c.lineWidth = 18; c.beginPath(); c.moveTo(px, fy); c.quadraticCurveTo(px + 30, fy - 140, px + 8, fy - 250); c.stroke();
    c.strokeStyle = '#d9a05c'; c.lineWidth = 5; for (let i = 0; i < 6; i++) { c.beginPath(); c.moveTo(px - 10, fy - 30 - i * 40); c.lineTo(px + 14, fy - 40 - i * 40); c.stroke(); }
    c.fillStyle = '#35b86a'; for (let i = 0; i < 6; i++) { c.save(); c.translate(px + 8, fy - 250); c.rotate(-2.6 + i * 0.85); c.beginPath(); c.moveTo(0, 0); c.quadraticCurveTo(50, -50, 120, -8); c.quadraticCurveTo(50, -18, 0, 0); c.fill(); c.restore(); }
    c.fillStyle = '#8a5a2a'; c.beginPath(); c.arc(px + 2, fy - 244, 9, 0, TAU); c.arc(px + 18, fy - 240, 9, 0, TAU); c.fill();
    // umbrella
    const ux = W * 0.86; c.strokeStyle = '#fff'; c.lineWidth = 6; c.beginPath(); c.moveTo(ux, fy + 6); c.lineTo(ux - 10, fy - 150); c.stroke();
    c.save(); c.translate(ux - 10, fy - 150); c.beginPath(); c.moveTo(-100, 14); c.quadraticCurveTo(-90, -80, 0, -84); c.quadraticCurveTo(90, -80, 100, 14); c.closePath(); c.clip();
    for (let i = -5; i < 5; i++) { c.fillStyle = i % 2 ? '#fff' : '#ff5d6c'; c.fillRect(i * 20, -90, 20, 110); } c.restore();
    c.strokeStyle = 'rgba(0,0,0,0.15)'; c.lineWidth = 2; c.beginPath(); c.moveTo(ux - 110, fy - 136); c.quadraticCurveTo(ux - 10, fy - 120, ux + 90, fy - 136); c.stroke();
    // sand
    c.fillStyle = lg(c, 0, fy, 0, H, '#ffe6a8', '#f2c878'); c.fillRect(0, fy, W, H - fy);
    c.fillStyle = 'rgba(255,255,255,0.35)'; c.beginPath(); c.moveTo(0, fy); for (let x = 0; x <= W; x += 20) c.lineTo(x, fy + 4 + Math.sin(x * 0.04) * 3); c.lineTo(W, fy - 4); c.lineTo(0, fy - 4); c.fill();
    c.fillStyle = 'rgba(160,110,40,0.28)'; for (let i = 0; i < 260; i++) { c.beginPath(); c.arc(R() * W, fy + 8 + R() * (H - fy), 1 + R() * 1.6, 0, TAU); c.fill(); }
    // sandcastle & starfish & shells
    const cx = W * 0.3, cy = fy + (H - fy) * 0.5; c.fillStyle = '#e6b868'; rr(c, cx - 34, cy - 30, 68, 30, 4); c.fill(); rr(c, cx - 14, cy - 56, 28, 28, 4); c.fill(); for (const x of [-34, -14, 6, 26]) c.fillRect(cx + x, cy - 38, 8, 8); c.fillStyle = '#ff5d6c'; c.fillRect(cx - 1, cy - 78, 3, 24); c.beginPath(); c.moveTo(cx + 2, cy - 78); c.lineTo(cx + 22, cy - 71); c.lineTo(cx + 2, cy - 64); c.fill();
    c.fillStyle = '#ff9f43'; starPath(c, W * 0.58, cy + 14, 22, 9, 5, 0.2); c.fill(); c.fillStyle = '#ffd1e0'; c.beginPath(); c.ellipse(W * 0.72, cy + 4, 16, 12, 0, Math.PI, TAU); c.fill();
  },
  space(c, W, H, fy, R) {
    c.fillStyle = lg(c, 0, 0, 0, H, '#100a38', '#3a1d78'); c.fillRect(0, 0, W, H);
    glow(c, W * 0.2, fy * 0.3, 300, 'rgba(160,80,255,0.35)'); glow(c, W * 0.85, fy * 0.55, 260, 'rgba(60,160,255,0.3)'); glow(c, W * 0.55, fy * 0.1, 220, 'rgba(255,90,170,0.22)');
    for (let i = 0; i < 160; i++) { const x = R() * W, y = R() * fy, r = 0.6 + R() * 1.8; c.fillStyle = `rgba(255,255,255,${0.35 + R() * 0.65})`; c.beginPath(); c.arc(x, y, r, 0, TAU); c.fill(); }
    // ringed planet
    const px = W * 0.76, py = fy * 0.3, pr = Math.min(90, W * 0.1); c.save(); c.translate(px, py); c.rotate(-0.3);
    c.strokeStyle = 'rgba(255,200,120,0.55)'; c.lineWidth = 14; c.beginPath(); c.ellipse(0, 0, pr * 1.9, pr * 0.5, 0, Math.PI, TAU); c.stroke();
    c.beginPath(); c.arc(0, 0, pr, 0, TAU); c.fillStyle = rg(c, -pr * 0.3, -pr * 0.35, 4, pr * 1.1, '#ffd29a', '#e0693a'); c.fill();
    c.save(); c.clip(); c.strokeStyle = 'rgba(255,255,255,0.25)'; c.lineWidth = 8; for (let i = -2; i <= 2; i++) { c.beginPath(); c.moveTo(-pr, i * pr * 0.35); c.lineTo(pr, i * pr * 0.35 + 8); c.stroke(); } c.restore();
    c.strokeStyle = 'rgba(255,200,120,0.8)'; c.lineWidth = 14; c.beginPath(); c.ellipse(0, 0, pr * 1.9, pr * 0.5, 0, 0, Math.PI); c.stroke(); c.restore();
    // earth
    const ex = W * 0.16, ey = fy * 0.22, er = Math.min(54, W * 0.06); c.beginPath(); c.arc(ex, ey, er, 0, TAU); c.fillStyle = rg(c, ex - er * 0.3, ey - er * 0.3, 2, er * 1.1, '#7fd8ff', '#1a62d0'); c.fill();
    c.save(); c.beginPath(); c.arc(ex, ey, er, 0, TAU); c.clip(); c.fillStyle = '#4fc772'; c.beginPath(); c.ellipse(ex - er * 0.25, ey - er * 0.1, er * 0.45, er * 0.3, 0.5, 0, TAU); c.ellipse(ex + er * 0.35, ey + er * 0.35, er * 0.3, er * 0.2, -0.3, 0, TAU); c.fill(); c.restore();
    glow(c, ex, ey, er * 2, 'rgba(120,200,255,0.25)');
    // moon surface
    c.fillStyle = lg(c, 0, fy, 0, H, '#cfc8e8', '#8f86b8'); c.beginPath(); c.moveTo(0, fy + 6); for (let x = 0; x <= W; x += 30) c.lineTo(x, fy + 4 + Math.sin(x * 0.02) * 4); c.lineTo(W + 30, fy + 4); c.lineTo(W + 30, H); c.lineTo(0, H); c.fill();
    c.fillStyle = 'rgba(255,255,255,0.3)'; c.fillRect(0, fy + 2, W, 3);
    for (let i = 0; i < 9; i++) { const x = R() * W, y = fy + 24 + R() * (H - fy - 24), r = 14 + R() * 30; c.fillStyle = 'rgba(70,60,110,0.35)'; c.beginPath(); c.ellipse(x, y, r, r * 0.32, 0, 0, TAU); c.fill(); c.fillStyle = 'rgba(255,255,255,0.25)'; c.beginPath(); c.ellipse(x, y + 2, r * 0.9, r * 0.25, 0, Math.PI, TAU); c.fill(); }
    // flag + rover-ish ufo
    const fx = W * 0.9; c.strokeStyle = '#e6e6f5'; c.lineWidth = 4; c.beginPath(); c.moveTo(fx, fy + 10); c.lineTo(fx, fy - 90); c.stroke(); c.fillStyle = '#ff5d8f'; c.beginPath(); c.moveTo(fx, fy - 90); c.lineTo(fx + 50, fy - 76); c.lineTo(fx, fy - 60); c.fill(); c.fillStyle = '#ffd23f'; starPath(c, fx + 18, fy - 76, 8, 3.5); c.fill();
  },
  snow(c, W, H, fy, R) {
    c.fillStyle = lg(c, 0, 0, 0, fy, '#a8d8ff', '#eaf7ff'); c.fillRect(0, 0, W, fy);
    glow(c, W * 0.2, fy * 0.2, 200, 'rgba(255,255,255,0.8)'); cloud(c, W * 0.5, fy * 0.12, 1.3, 0.9); cloud(c, W * 0.8, fy * 0.26, 1.0, 0.8);
    c.fillStyle = '#c4d9f0'; c.beginPath(); c.moveTo(0, fy); for (let i = 0; i <= 6; i++) c.lineTo(W * i / 6 + 20, fy - 150 - (i % 2 ? 80 : 0) - R() * 40); c.lineTo(W, fy); c.fill();
    c.fillStyle = '#fff'; c.beginPath(); c.moveTo(0, fy); c.quadraticCurveTo(W * 0.25, fy - 110, W * 0.5, fy - 30); c.quadraticCurveTo(W * 0.78, fy - 120, W, fy - 20); c.lineTo(W, fy); c.fill();
    const tree = (x, s) => { c.fillStyle = '#7a5230'; c.fillRect(x - 6 * s, fy - 20 * s, 12 * s, 24 * s); for (let k = 0; k < 3; k++) { const y = fy - 20 * s - k * 40 * s, w = (62 - k * 16) * s; c.fillStyle = '#2f9a6a'; c.beginPath(); c.moveTo(x - w, y); c.lineTo(x + w, y); c.lineTo(x, y - 62 * s); c.closePath(); c.fill(); c.fillStyle = '#fff'; c.beginPath(); c.moveTo(x - w * 0.62, y - 24 * s); c.quadraticCurveTo(x, y - 14 * s, x + w * 0.62, y - 24 * s); c.lineTo(x, y - 62 * s); c.closePath(); c.fill(); } };
    tree(W * 0.08, 1.2); tree(W * 0.18, 0.8); tree(W * 0.93, 1.1);
    // igloo
    const ix = W * 0.8, ir = Math.min(120, W * 0.12); c.beginPath(); c.arc(ix, fy, ir, Math.PI, TAU); c.fillStyle = lg(c, 0, fy - ir, 0, fy, '#ffffff', '#d4e8fa'); c.fill(); c.strokeStyle = '#a9c7e6'; c.lineWidth = 3; c.stroke();
    c.save(); c.beginPath(); c.arc(ix, fy, ir, Math.PI, TAU); c.clip(); c.strokeStyle = 'rgba(120,160,210,0.5)'; c.lineWidth = 2; for (let k = 1; k < 5; k++) { c.beginPath(); c.moveTo(ix - ir, fy - k * ir / 4.5); c.lineTo(ix + ir, fy - k * ir / 4.5); c.stroke(); } c.restore();
    c.beginPath(); c.arc(ix, fy, ir * 0.32, Math.PI, TAU); c.fillStyle = '#4a6a96'; c.fill();
    // ground
    c.fillStyle = lg(c, 0, fy, 0, H, '#ffffff', '#cfe3f7'); c.fillRect(0, fy, W, H - fy);
    c.fillStyle = 'rgba(140,180,230,0.3)'; c.fillRect(0, fy, W, 4);
    c.fillStyle = 'rgba(255,255,255,0.95)'; for (let i = 0; i < 200; i++) { c.beginPath(); c.arc(R() * W, fy + R() * (H - fy), 1 + R() * 2, 0, TAU); c.fill(); }
    c.fillStyle = 'rgba(150,190,235,0.35)'; for (let i = 0; i < 6; i++) { c.beginPath(); c.ellipse(R() * W, fy + 20 + R() * (H - fy - 20), 40 + R() * 60, 7, 0, 0, TAU); c.fill(); }
    // snowman
    const sx = W * 0.32, sy = fy + (H - fy) * 0.55; c.fillStyle = '#fff'; c.strokeStyle = '#b7d2ee'; c.lineWidth = 3; for (const [y, r] of [[sy - 22, 30], [sy - 66, 22], [sy - 98, 15]]) { c.beginPath(); c.arc(sx, y, r, 0, TAU); c.fill(); c.stroke(); }
    c.fillStyle = '#ff8a3d'; c.beginPath(); c.moveTo(sx, sy - 98); c.lineTo(sx + 22, sy - 94); c.lineTo(sx, sy - 90); c.fill(); c.fillStyle = '#222'; c.beginPath(); c.arc(sx - 5, sy - 103, 2, 0, TAU); c.arc(sx + 5, sy - 103, 2, 0, TAU); c.fill();
  },
};
