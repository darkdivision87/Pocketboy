// Item sprites (tiny shape DSL), extra rooms and shirts for Buddy Playground. All procedural canvas art.
import { drawTool, shade, rr, starPath, lg, rg, glow, cloud, rand, gloss, ROOM_DRAW } from './art.js';
const TAU = Math.PI * 2;

const ALIAS = { popper: 'confetti', beach: 'beach', balloons: 'balloons', hose2: 'hose', hand: 'hand', nuke: 'glitter', tickle: 'feather', rubber: 'hammer', spring2: 'spring' };
const drawn = new Set(['hammer', 'pillow', 'confetti', 'water', 'tramp', 'beach', 'magnet', 'balloons', 'feather', 'icecream', 'cupcake', 'fan', 'mushroom', 'glitter', 'hand']);

// ops: C circle, E ellipse, R rounded rect (centre), L capsule line, P polygon, S star, D flat dot, H highlight, A arc ring, G group(rot,scale,tx,ty), g end group, I other sprite
const SPR = {
  bat: [['L', -24, 26, 26, -24, 30, '#ff6fb0'], ['L', -40, 42, -24, 26, 17, '#fff0a0'], ['H', 12, -14, 5, 16, -0.8], ['D', 20, -22, 3, '#fff']],
  rollpin: [['L', -26, 26, 26, -26, 26, '#efc088'], ['L', -46, 46, -32, 32, 11, '#c98a4a'], ['L', 32, -32, 46, -46, 11, '#c98a4a'], ['H', 0, 0, 4, 18, -0.78]],
  glove: [['E', -2, 30, 22, 16, '#fff'], ['R', -2, 34, 40, 20, 8, '#f0f4ff'], ['C', 0, -6, 34, '#ff4d5e'], ['E', -26, -2, 12, 18, '#ff6a78', 0.5], ['H', -10, -24, 11, 7, -0.5], ['L', -14, 24, 14, 24, 3, '#c9283c']],
  sword: [['L', -22, 22, 28, -28, 17, '#8fe0ff'], ['R', -22, 22, 40, 10, 5, '#ffd23f', -0.78], ['L', -42, 44, -26, 28, 11, '#ff5d8f'], ['H', 10, -10, 3, 20, -0.78], ['S', 30, -32, 8, '#fff']],
  plunger: [['L', -34, 34, 14, -14, 9, '#d9a060'], ['C', 22, -22, 24, '#ff4d5e'], ['E', 22, -22, 16, 11, '#ff7a86', 0.78], ['H', 14, -32, 7, 4, -0.7]],
  claws: [['R', 0, 30, 56, 16, 7, '#ff7a8a'], ['P', '#fff6d8', -26, 22, -22, -36, -10, 22], ['P', '#fff6d8', -8, 22, 0, -44, 8, 22], ['P', '#fff6d8', 10, 22, 22, -36, 26, 22], ['H', -16, 4, 2, 12, 0.2]],
  torch: [['R', 0, 24, 18, 44, 7, '#d9a060'], ['E', 0, -14, 17, 24, '#ffb52e'], ['E', 0, -8, 9, 14, '#fff4a8'], ['S', -26, -30, 7, '#fff'], ['S', 26, -18, 6, '#ffe27a'], ['S', 20, -44, 5, '#fff']],
  grenade: [['C', 0, 8, 30, '#ff7ab8'], ['R', 0, -22, 22, 12, 4, '#ffd23f'], ['A', 18, -30, 8, 4, '#c9c9d8'], ['H', -12, -4, 8, 12, 0.4], ['D', 12, 10, 4, '#ffd23f'], ['D', -6, 22, 4, '#3ec6ff'], ['D', 14, 24, 3, '#58d68d']],
  rocket: [['G', 0.7, 1, 1, 0, 0], ['P', '#ffb52e', -8, 28, 8, 28, 0, 52], ['R', 0, 0, 28, 64, 14, '#ff5d6c'], ['P', '#ffd23f', -14, -26, 14, -26, 0, -52], ['P', '#6a7cff', -14, 12, -30, 38, -14, 34], ['P', '#6a7cff', 14, 12, 30, 38, 14, 34], ['C', 0, -4, 8, '#bfeaff'], ['g']],
  bouncybomb: [['C', 0, 6, 32, '#3ec6ff'], ['L', 4, -26, 14, -40, 5, '#c9c9d8'], ['S', 16, -42, 8, '#ffd23f'], ['H', -14, -8, 8, 14, 0.5], ['D', -10, 6, 4, '#3a1d4a'], ['D', 10, 6, 4, '#3a1d4a'], ['E', 0, 18, 8, 5, '#fff']],
  hose: [['A', 0, 4, 28, 15, '#ff5d6c'], ['A', 0, 4, 28, 6, '#ff9aa4'], ['R', 36, -22, 28, 14, 6, '#ffd23f', -0.5], ['L', 22, -26, 34, -34, 8, '#ff5d6c']],
  slime: [['C', 0, 8, 32, '#7ae04a'], ['C', -18, -8, 16, '#8ef25c'], ['C', 16, -16, 15, '#7ae04a'], ['E', 24, 38, 7, 12, '#7ae04a'], ['E', -20, 40, 6, 10, '#7ae04a'], ['H', -14, -4, 8, 5, -0.5], ['D', -8, 12, 4, '#3a1d4a'], ['D', 10, 12, 4, '#3a1d4a']],
  icebucket: [['R', 0, 10, 54, 46, 10, '#7ad8ff'], ['E', 0, -14, 28, 9, '#d8f6ff'], ['R', -8, -22, 18, 18, 4, '#fff', 0.3], ['R', 10, -26, 14, 14, 4, '#e8fbff', -0.3], ['A', 0, -8, 34, 3, '#9fb0d8'], ['H', -16, 10, 4, 14, 0]],
  peasoup: [['E', 0, 12, 40, 30, '#fff'], ['E', 0, -6, 36, 13, '#8cd45a'], ['C', -12, -8, 4, '#b4ec80'], ['C', 10, -6, 4, '#b4ec80'], ['L', -10, -26, -6, -40, 4, '#e8f4ff'], ['L', 10, -26, 14, -40, 4, '#e8f4ff']],
  paint: [['C', 0, 0, 28, '#b57bff'], ['C', -26, -10, 11, '#b57bff'], ['C', 22, -26, 10, '#b57bff'], ['C', 28, 16, 9, '#b57bff'], ['C', -14, 28, 9, '#b57bff'], ['H', -10, -10, 9, 5, -0.6], ['D', 40, -2, 3, '#ff5d8f']],
  bubble: [['A', -10, -14, 20, 7, '#3ec6ff'], ['L', -4, 6, 20, 40, 9, '#ff5d8f'], ['C', 24, -30, 11, '#cdeeff'], ['C', 34, -6, 7, '#cdeeff'], ['C', 14, -44, 6, '#cdeeff']],
  waterpistol: [['R', -4, -10, 66, 26, 11, '#3ec6ff'], ['R', 36, -10, 14, 16, 5, '#ffd23f'], ['R', -22, 18, 17, 32, 7, '#ff5d8f', 0.25], ['C', -2, -24, 11, '#9be6ff'], ['H', -8, -16, 16, 3, 0]],
  poppergun: [['R', -6, -4, 58, 26, 12, '#ff8fbe'], ['P', '#ffd23f', 24, -16, 50, -30, 50, 24, 24, 10], ['R', -22, 22, 16, 30, 6, '#b57bff', 0.25], ['D', 38, -38, 4, '#3ec6ff'], ['D', 24, -42, 4, '#58d68d'], ['S', 52, -42, 5, '#ff5d8f']],
  cupcakecannon: [['R', -4, 24, 70, 28, 12, '#4fd0a0'], ['I', 'cupcake', 6, -10, 0.55], ['C', -34, 38, 10, '#6a7cff']],
  pie: [['E', 0, 20, 42, 14, '#e8d5b0'], ['E', 0, 4, 36, 22, '#fffaf0'], ['E', 0, -6, 24, 10, '#fff'], ['C', 0, -16, 8, '#ff3d5a'], ['H', -14, -2, 10, 4, -0.2]],
  tomato: [['C', 0, 6, 33, '#ff4d4d'], ['S', 0, -26, 14, '#58d68d'], ['H', -14, -8, 9, 5, -0.7]],
  pizza: [['P', '#ffcf5a', -36, -26, 36, -26, 0, 46], ['R', 0, -28, 76, 15, 7, '#e6a040'], ['C', -10, -6, 9, '#e8283e'], ['C', 12, -12, 8, '#e8283e'], ['C', 0, 16, 8, '#e8283e'], ['D', -16, -16, 3, '#58d68d']],
  blocks: [['R', -16, 14, 38, 38, 6, '#ff5d8f', -0.1], ['R', 22, 18, 32, 32, 6, '#3ec6ff', 0.1], ['R', 2, -20, 34, 34, 6, '#ffd23f', 0.15], ['D', 2, -20, 8, '#fff'], ['D', -16, 14, 7, '#fff']],
  bouncyball: [['C', 0, 0, 32, '#58d68d'], ['A', 0, 0, 20, 5, '#fff'], ['A', 0, 0, 8, 4, '#ffd23f'], ['H', -12, -14, 9, 5, -0.7]],
  duck: [['C', -2, 14, 28, '#ffd23f'], ['C', 14, -18, 18, '#ffd23f'], ['E', 32, -14, 10, 6, '#ff9f43'], ['D', 20, -24, 3.5, '#3a1d4a'], ['E', -8, 16, 14, 9, '#ffc21f', 0.3], ['H', 6, -26, 6, 3, -0.4], ['D', 24, -16, 3, '#ff9ec7']],
  vice: [['R', -38, 4, 18, 64, 7, '#ff8a3d'], ['R', 38, 4, 18, 64, 7, '#ff8a3d'], ['C', 0, 6, 16, '#ffb48a'], ['P', '#fff', -26, -30, -14, -24, -26, -18], ['P', '#fff', 26, -30, 14, -24, 26, -18], ['D', -4, 2, 2.5, '#3a1d4a'], ['D', 4, 2, 2.5, '#3a1d4a']],
  conveyor: [['R', 0, 14, 90, 28, 14, '#6a7cff'], ['C', -36, 14, 13, '#ffd23f'], ['C', 36, 14, 13, '#ffd23f'], ['P', '#fff', -12, 8, -2, 14, -12, 20], ['P', '#fff', 6, 8, 16, 14, 6, 20], ['R', 0, -4, 80, 8, 4, '#4a5ae8']],
  spring: [['R', 0, 38, 56, 12, 6, '#6a7cff'], ['L', -16, 28, 16, 20, 7, '#c9c9d8'], ['L', 16, 20, -16, 12, 7, '#c9c9d8'], ['L', -16, 12, 16, 4, 7, '#c9c9d8'], ['L', 16, 4, -16, -4, 7, '#c9c9d8'], ['R', 0, -16, 56, 14, 7, '#ff5d6c']],
  butterflies: [['E', -16, -8, 19, 24, '#ff9ee0', -0.5], ['E', 16, -8, 19, 24, '#b57bff', 0.5], ['E', -12, 18, 12, 15, '#ffd1f0', 0.3], ['E', 12, 18, 12, 15, '#d8b8ff', -0.3], ['R', 0, 4, 7, 38, 3, '#5a2a52'], ['D', -16, -10, 5, '#fff'], ['D', 16, -10, 5, '#fff']],
  _bee: [['E', -5, -14, 9, 12, '#e8f8ff', -0.4], ['E', 8, -14, 9, 12, '#e8f8ff', 0.4], ['C', 0, 0, 15, '#ffd23f'], ['R', -3, 0, 5, 22, 2, '#3a1d4a'], ['R', 6, 0, 5, 20, 2, '#3a1d4a'], ['D', -9, -3, 2, '#3a1d4a']],
  bees: [['I', '_bee', -18, -12, 1], ['I', '_bee', 18, 4, 1], ['I', '_bee', -6, 26, 0.8]],
  penguin: [['E', 0, 8, 27, 36, '#3a3f66'], ['E', 0, 14, 17, 26, '#fff'], ['E', 0, -12, 3, 3, '#3a3f66'], ['E', 0, -8, 8, 5, '#ff9f43'], ['D', -9, -18, 3.5, '#fff'], ['D', 9, -18, 3.5, '#fff'], ['D', -9, -18, 1.6, '#111'], ['D', 9, -18, 1.6, '#111'], ['E', -12, 44, 11, 5, '#ff9f43'], ['E', 12, 44, 11, 5, '#ff9f43']],
  dino: [['E', -30, 28, 20, 8, '#6fd86a', 0.3], ['C', -2, 12, 30, '#6fd86a'], ['C', 24, -14, 18, '#7ee878'], ['D', 30, -20, 3.5, '#3a1d4a'], ['S', -12, -16, 8, '#ffb52e'], ['S', 4, -22, 8, '#ffb52e'], ['E', 10, 22, 14, 18, '#a8f09a'], ['E', 32, -8, 8, 4, '#ff9ec7']],
  raincloud: [['C', -18, 2, 18, '#c9d6ee'], ['C', 6, -8, 24, '#dbe5f6'], ['C', 28, 2, 17, '#c9d6ee'], ['R', 4, 10, 62, 18, 9, '#c9d6ee'], ['L', -14, 28, -18, 40, 4, '#3ea8ff'], ['L', 6, 30, 2, 44, 4, '#3ea8ff'], ['L', 24, 28, 20, 40, 4, '#3ea8ff']],
  lightning: [['P', '#ffd23f', 8, -48, -20, 4, -2, 4, -12, 48, 22, -10, 4, -10, 18, -48]],
  tornado: [['E', 0, -34, 36, 9, '#aebde0'], ['E', 4, -18, 29, 8, '#9fb0d8'], ['E', -3, -2, 22, 7, '#aebde0'], ['E', 2, 14, 16, 6, '#9fb0d8'], ['E', 0, 30, 9, 5, '#aebde0'], ['D', -30, -40, 3, '#fff'], ['D', 24, 4, 3, '#fff']],
  meteor: [['G', 0.6, 1, 1, 0, 0], ['P', '#ff9f43', -14, -18, 14, -18, 0, -54], ['R', 0, 8, 46, 42, 18, '#fff2f7'], ['E', 0, 6, 16, 8, '#ffc4e0'], ['D', -10, 16, 3, '#3a1d4a'], ['D', 10, 16, 3, '#3a1d4a'], ['g']],
  ghost: [['R', 0, 4, 56, 56, 22, '#fff'], ['C', -18, 36, 9, '#fff'], ['C', 0, 38, 9, '#fff'], ['C', 18, 36, 9, '#fff'], ['D', -11, -4, 5, '#3a1d4a'], ['D', 11, -4, 5, '#3a1d4a'], ['E', 0, 12, 6, 8, '#3a1d4a'], ['D', -20, 8, 5, '#ffc4e0'], ['D', 20, 8, 5, '#ffc4e0']],
  pumpkin: [['C', 0, 6, 33, '#ff9f43'], ['E', -14, 6, 12, 30, '#ff8a2b'], ['E', 14, 6, 12, 30, '#ff8a2b'], ['R', 0, -28, 10, 14, 3, '#58a050'], ['P', '#3a1d4a', -18, -4, -6, -4, -12, -14], ['P', '#3a1d4a', 6, -4, 18, -4, 12, -14], ['P', '#3a1d4a', -16, 12, -8, 8, 0, 14, 8, 8, 16, 12, 10, 22, -10, 22]],
  skeleton: [['C', 0, -8, 30, '#f6f6f6'], ['R', 0, 24, 30, 16, 6, '#f6f6f6'], ['C', -12, -8, 9, '#3a1d4a'], ['C', 12, -8, 9, '#3a1d4a'], ['P', '#3a1d4a', 0, 2, -5, 12, 5, 12], ['L', -8, 24, -8, 32, 2, '#c9c9d8'], ['L', 0, 24, 0, 32, 2, '#c9c9d8'], ['L', 8, 24, 8, 32, 2, '#c9c9d8']],
  hand: null,
};

function shaded(c, col, fn, w = 3.5) {
  fn(); c.fillStyle = lg(c, 0, -50, 0, 50, shade(col, 0.3), col); c.fill(); c.strokeStyle = shade(col, -0.38); c.lineWidth = w; c.lineJoin = 'round'; c.stroke();
}
function ops(c, spec, t) {
  for (const o of spec) {
    switch (o[0]) {
      case 'C': { const [, x, y, r, col] = o; c.beginPath(); c.arc(x, y, r, 0, TAU); c.fillStyle = rg(c, x - r * 0.3, y - r * 0.35, r * 0.1, r * 1.1, shade(col, 0.4), col); c.fill(); c.strokeStyle = shade(col, -0.38); c.lineWidth = 3.5; c.stroke(); break; }
      case 'E': { const [, x, y, rx, ry, col, rot = 0] = o; c.beginPath(); c.ellipse(x, y, rx, ry, rot, 0, TAU); c.fillStyle = lg(c, x, y - ry, x, y + ry, shade(col, 0.3), col); c.fill(); c.strokeStyle = shade(col, -0.38); c.lineWidth = 3.5; c.stroke(); break; }
      case 'R': { const [, x, y, w, h, rad, col, rot = 0] = o; c.save(); c.translate(x, y); c.rotate(rot); rr(c, -w / 2, -h / 2, w, h, rad); c.fillStyle = lg(c, -w / 2, -h / 2, w / 2, h / 2, shade(col, 0.32), col); c.fill(); c.strokeStyle = shade(col, -0.38); c.lineWidth = 3.5; c.lineJoin = 'round'; c.stroke(); c.restore(); break; }
      case 'L': { const [, x1, y1, x2, y2, w, col] = o; c.lineCap = 'round'; c.beginPath(); c.moveTo(x1, y1); c.lineTo(x2, y2); c.strokeStyle = shade(col, -0.38); c.lineWidth = w + 5; c.stroke(); c.strokeStyle = col; c.lineWidth = w; c.stroke(); c.strokeStyle = shade(col, 0.45); c.globalAlpha = 0.6; c.lineWidth = w * 0.28; c.beginPath(); c.moveTo(x1 - w * 0.15, y1 - w * 0.15); c.lineTo(x2 - w * 0.15, y2 - w * 0.15); c.stroke(); c.globalAlpha = 1; break; }
      case 'P': { const col = o[1]; c.beginPath(); for (let i = 2; i < o.length; i += 2) i === 2 ? c.moveTo(o[i], o[i + 1]) : c.lineTo(o[i], o[i + 1]); c.closePath(); c.fillStyle = lg(c, 0, -50, 0, 50, shade(col, 0.3), col); c.fill(); c.strokeStyle = shade(col, -0.38); c.lineWidth = 3.5; c.lineJoin = 'round'; c.stroke(); break; }
      case 'S': { const [, x, y, r, col] = o; starPath(c, x, y, r, r * 0.45, 5); c.fillStyle = col; c.fill(); c.strokeStyle = shade(col, -0.4); c.lineWidth = 2.5; c.lineJoin = 'round'; c.stroke(); break; }
      case 'D': { const [, x, y, r, col] = o; c.beginPath(); c.arc(x, y, r, 0, TAU); c.fillStyle = col; c.fill(); break; }
      case 'H': { const [, x, y, rx, ry, rot = 0] = o; gloss(c, x, y, rx, ry, rot, 0.7); break; }
      case 'A': { const [, x, y, r, w, col] = o; c.beginPath(); c.arc(x, y, r, 0, TAU); c.strokeStyle = col; c.lineWidth = w; c.stroke(); break; }
      case 'G': { const [, rot, sx, sy, tx, ty] = o; c.save(); c.translate(tx, ty); c.rotate(rot); c.scale(sx, sy); break; }
      case 'g': c.restore(); break;
      case 'I': { const [, id, x, y, s] = o; c.save(); c.translate(x, y); c.scale(s, s); drawItem(c, id, t); c.restore(); break; }
      default: break;
    }
  }
}
export function drawItem(c, id, t = 0) {
  id = ALIAS[id] || id;
  c.lineCap = 'round'; c.lineJoin = 'round';
  if (SPR[id]) { ops(c, SPR[id], t); return; }
  drawTool(c, id, t);
}

// ---- extra rooms ----------------------------------------------------------------------------------------
ROOM_DRAW.box = (c, W, H, fy, R) => {
  c.fillStyle = lg(c, 0, 0, 0, fy, '#f1e6d4', '#dfd0b8'); c.fillRect(0, 0, W, fy);
  c.fillStyle = 'rgba(255,255,255,0.35)'; for (let x = 0; x < W; x += 140) c.fillRect(x, 0, 70, fy);
  c.fillStyle = '#d2c2a6'; c.fillRect(0, fy - 22, W, 22); c.fillStyle = 'rgba(0,0,0,0.08)'; c.fillRect(0, fy - 4, W, 4);
  c.fillStyle = lg(c, 0, fy, 0, H, '#c9b79a', '#a89472'); c.fillRect(0, fy, W, H - fy);
  c.strokeStyle = 'rgba(80,60,30,0.18)'; c.lineWidth = 2; for (let y = fy + 30; y < H; y += 44) { c.beginPath(); c.moveTo(0, y); c.lineTo(W, y); c.stroke(); }
  c.fillStyle = 'rgba(255,255,255,0.25)'; c.fillRect(0, fy, W, 4);
};
ROOM_DRAW.kitchen = (c, W, H, fy, R) => {
  c.fillStyle = '#fff6e0'; c.fillRect(0, 0, W, fy);
  c.strokeStyle = 'rgba(120,180,200,0.45)'; c.lineWidth = 2; for (let x = 0; x < W; x += 56) { c.beginPath(); c.moveTo(x, 0); c.lineTo(x, fy); c.stroke(); } for (let y = 0; y < fy; y += 56) { c.beginPath(); c.moveTo(0, y); c.lineTo(W, y); c.stroke(); }
  c.fillStyle = 'rgba(255,255,255,0.4)'; for (let x = 0; x < W; x += 112) c.fillRect(x, 0, 56, fy);
  const cw = Math.min(260, W * 0.3); for (const x of [W * 0.04, W * 0.62]) { rr(c, x, 70, cw, 110, 12); c.fillStyle = lg(c, 0, 70, 0, 180, '#ff9ec7', '#e8689f'); c.fill(); c.strokeStyle = '#b8467a'; c.lineWidth = 3; c.stroke(); c.fillStyle = '#ffe27a'; c.fillRect(x + cw / 2 - 2, 76, 4, 98); c.beginPath(); c.arc(x + cw / 2 - 16, 126, 6, 0, TAU); c.arc(x + cw / 2 + 16, 126, 6, 0, TAU); c.fill(); }
  const wx = W * 0.4, ww = Math.min(150, W * 0.16); rr(c, wx, 80, ww, ww, 10); c.fillStyle = lg(c, 0, 80, 0, 80 + ww, '#9fe0ff', '#e0f6ff'); c.fill(); c.strokeStyle = '#fff'; c.lineWidth = 7; c.stroke(); c.beginPath(); c.moveTo(wx + ww / 2, 80); c.lineTo(wx + ww / 2, 80 + ww); c.moveTo(wx, 80 + ww / 2); c.lineTo(wx + ww, 80 + ww / 2); c.stroke();
  const cy = fy - 120; rr(c, 0, cy, W, 120, 0); c.fillStyle = lg(c, 0, cy, 0, fy, '#7ec8ff', '#4ea6e8'); c.fill(); c.fillStyle = '#e8f6ff'; c.fillRect(0, cy - 12, W, 14);
  c.fillStyle = 'rgba(255,255,255,0.22)'; for (let x = 20; x < W; x += 120) { rr(c, x, cy + 16, 90, 88, 10); c.fill(); }
  const tile = 70; for (let y = fy, k = 0; y < H; y += tile * 0.5, k++) for (let x = (k % 2) * tile; x < W + tile; x += tile * 2) { c.fillStyle = '#fff'; c.fillRect(x, y, tile, tile * 0.5); c.fillStyle = '#ff9ec7'; c.fillRect(x + tile, y, tile, tile * 0.5); }
  c.fillStyle = 'rgba(0,0,0,0.12)'; c.fillRect(0, fy, W, 6);
};
ROOM_DRAW.jungle = (c, W, H, fy, R) => {
  c.fillStyle = lg(c, 0, 0, 0, fy, '#7fe0a0', '#2f9a5a'); c.fillRect(0, 0, W, fy);
  glow(c, W * 0.7, 40, 280, 'rgba(255,250,170,0.7)');
  for (let i = 0; i < 6; i++) { const x = W * (i + 0.5) / 6 + (R() - 0.5) * 60, w = 30 + R() * 24; c.fillStyle = i % 2 ? '#6a4a2a' : '#7a5632'; rr(c, x - w / 2, 0, w, fy, 10); c.fill(); c.fillStyle = 'rgba(0,0,0,0.12)'; c.fillRect(x + w * 0.1, 0, w * 0.3, fy); }
  const leaf = (x, y, s, rot, col) => { c.save(); c.translate(x, y); c.rotate(rot); c.scale(s, s); c.beginPath(); c.moveTo(0, 0); c.quadraticCurveTo(50, -40, 110, 0); c.quadraticCurveTo(50, 36, 0, 0); c.fillStyle = col; c.fill(); c.strokeStyle = 'rgba(0,60,20,0.35)'; c.lineWidth = 3; c.beginPath(); c.moveTo(0, 0); c.lineTo(100, 0); c.stroke(); c.restore(); };
  for (let i = 0; i < 18; i++) leaf(R() * W, R() * fy * 0.9, 0.8 + R() * 0.9, R() * TAU, ['#35b86a', '#4fd882', '#27a05a'][i % 3]);
  c.strokeStyle = '#2a7a3a'; c.lineWidth = 6; for (let i = 0; i < 7; i++) { const x = R() * W; c.beginPath(); c.moveTo(x, 0); c.quadraticCurveTo(x + 30, fy * 0.3, x - 10, fy * (0.3 + R() * 0.4)); c.stroke(); }
  c.fillStyle = '#ff5d8f'; for (let i = 0; i < 7; i++) { const x = R() * W, y = fy * (0.2 + R() * 0.5); for (let k = 0; k < 5; k++) { c.beginPath(); c.arc(x + Math.cos(k * 1.26) * 9, y + Math.sin(k * 1.26) * 9, 7, 0, TAU); c.fill(); } c.fillStyle = '#ffd23f'; c.beginPath(); c.arc(x, y, 5, 0, TAU); c.fill(); c.fillStyle = '#ff5d8f'; }
  c.fillStyle = lg(c, 0, fy, 0, H, '#5ac86a', '#2f8f45'); c.fillRect(0, fy, W, H - fy);
  c.fillStyle = '#3aa855'; for (let x = 0; x < W; x += 14) { c.beginPath(); c.moveTo(x, fy + 4); c.lineTo(x + 7, fy - 12 - R() * 10); c.lineTo(x + 14, fy + 4); c.fill(); }
  c.fillStyle = 'rgba(0,60,20,0.2)'; for (let i = 0; i < 8; i++) { c.beginPath(); c.ellipse(R() * W, fy + 20 + R() * (H - fy - 20), 40 + R() * 50, 8, 0, 0, TAU); c.fill(); }
};
ROOM_DRAW.candy = (c, W, H, fy, R) => {
  c.fillStyle = lg(c, 0, 0, 0, fy, '#ffc4e8', '#fff0fa'); c.fillRect(0, 0, W, fy);
  cloud(c, W * 0.12, fy * 0.14, 1.3, 0.9); cloud(c, W * 0.58, fy * 0.1, 1.0, 0.8);
  const cols = ['#ff5d8f', '#ffd23f', '#3ec6ff', '#58d68d', '#b57bff'];
  for (let i = 0; i < 6; i++) { const x = W * (i + 0.4) / 6, h = 110 + R() * 90; c.strokeStyle = '#fff'; c.lineWidth = 8; c.beginPath(); c.moveTo(x, fy); c.lineTo(x, fy - h); c.stroke(); c.beginPath(); c.arc(x, fy - h - 30, 34, 0, TAU); c.fillStyle = cols[i % 5]; c.fill(); c.strokeStyle = 'rgba(255,255,255,0.8)'; c.lineWidth = 7; c.beginPath(); c.arc(x, fy - h - 30, 22, 0, 5); c.stroke(); c.beginPath(); c.arc(x, fy - h - 30, 9, 0, 4.5); c.stroke(); }
  for (const x of [W * 0.08, W * 0.5, W * 0.9]) { c.strokeStyle = '#fff'; c.lineWidth = 16; c.lineCap = 'round'; c.beginPath(); c.moveTo(x, fy); c.lineTo(x, fy - 140); c.arc(x + 24, fy - 140, 24, Math.PI, 0.3 * Math.PI); c.stroke(); c.strokeStyle = '#ff4d6d'; c.lineWidth = 16; c.setLineDash([16, 16]); c.beginPath(); c.moveTo(x, fy); c.lineTo(x, fy - 140); c.arc(x + 24, fy - 140, 24, Math.PI, 0.3 * Math.PI); c.stroke(); c.setLineDash([]); }
  c.fillStyle = '#ffb3d9'; c.beginPath(); c.moveTo(0, fy); for (let x = 0; x <= W; x += 40) c.lineTo(x, fy - 40 - Math.sin(x * 0.012) * 26); c.lineTo(W, fy); c.fill();
  c.fillStyle = lg(c, 0, fy, 0, H, '#ffd9ec', '#ffa8d0'); c.fillRect(0, fy, W, H - fy);
  for (let i = 0; i < 90; i++) { c.save(); c.translate(R() * W, fy + 8 + R() * (H - fy)); c.rotate(R() * 3); c.fillStyle = cols[i % 5]; c.fillRect(-5, -2, 10, 4); c.restore(); }
  c.fillStyle = 'rgba(255,255,255,0.5)'; c.fillRect(0, fy, W, 5);
};
ROOM_DRAW.haunted = (c, W, H, fy, R) => {
  c.fillStyle = lg(c, 0, 0, 0, fy, '#1d1245', '#5a3a8a'); c.fillRect(0, 0, W, fy);
  glow(c, W * 0.8, fy * 0.2, 200, 'rgba(255,240,170,0.7)'); c.fillStyle = '#fff6c8'; c.beginPath(); c.arc(W * 0.8, fy * 0.2, 44, 0, TAU); c.fill(); c.fillStyle = 'rgba(200,180,120,0.4)'; c.beginPath(); c.arc(W * 0.8 - 12, fy * 0.2 + 8, 10, 0, TAU); c.fill();
  for (let i = 0; i < 40; i++) { c.fillStyle = `rgba(255,255,255,${0.3 + R() * 0.5})`; c.beginPath(); c.arc(R() * W, R() * fy * 0.6, 1 + R() * 1.4, 0, TAU); c.fill(); }
  const hx = W * 0.2, hw = Math.min(260, W * 0.3), hy = fy - 190; c.fillStyle = '#2b1a5a'; c.fillRect(hx, hy, hw, 190); c.beginPath(); c.moveTo(hx - 20, hy); c.lineTo(hx + hw / 2, hy - 110); c.lineTo(hx + hw + 20, hy); c.fill(); c.fillRect(hx + hw * 0.1, hy - 80, 30, 80);
  c.fillStyle = '#ffd23f'; for (const [x, y] of [[0.2, 0.25], [0.65, 0.25], [0.2, 0.62], [0.65, 0.62]]) { rr(c, hx + hw * x, hy + 190 * y, 36, 44, 8); c.fill(); }
  c.fillStyle = '#4a2a82'; rr(c, hx + hw / 2 - 20, fy - 70, 40, 70, 10); c.fill();
  c.strokeStyle = '#1a0f3a'; c.lineWidth = 8; for (const x of [W * 0.62, W * 0.9]) { c.beginPath(); c.moveTo(x, fy); c.lineTo(x, fy - 160); c.stroke(); c.lineWidth = 5; c.beginPath(); c.moveTo(x, fy - 100); c.lineTo(x + 36, fy - 140); c.moveTo(x, fy - 130); c.lineTo(x - 30, fy - 160); c.stroke(); c.lineWidth = 8; }
  c.fillStyle = '#1a0f3a'; for (let i = 0; i < 4; i++) { const x = W * (0.3 + i * 0.16), y = 60 + R() * 120; c.beginPath(); c.moveTo(x, y); c.quadraticCurveTo(x - 20, y - 18, x - 36, y); c.quadraticCurveTo(x - 20, y - 4, x, y + 10); c.quadraticCurveTo(x + 20, y - 4, x + 36, y); c.quadraticCurveTo(x + 20, y - 18, x, y); c.fill(); }
  c.strokeStyle = 'rgba(255,255,255,0.35)'; c.lineWidth = 2; c.beginPath(); c.moveTo(0, 0); c.lineTo(90, 90); c.moveTo(0, 0); c.lineTo(30, 100); c.moveTo(0, 0); c.lineTo(100, 30); c.stroke();
  c.fillStyle = lg(c, 0, fy, 0, H, '#4a3a6a', '#2a1f48'); c.fillRect(0, fy, W, H - fy); c.strokeStyle = 'rgba(0,0,0,0.3)'; c.lineWidth = 3; for (let x = 0; x < W; x += 80) { c.beginPath(); c.moveTo(x, fy); c.lineTo(x - 40, H); c.stroke(); }
  c.fillStyle = 'rgba(160,130,255,0.3)'; c.fillRect(0, fy, W, 4);
};

// ---- shirts (drawn inside the torso clip, torso local space) ----------------------------------------------
export const SHIRTS = [['yellow', 'Yellow Jersey', 0], ['stripes', 'Sailor Stripes', 500], ['hoodie', 'Red Hoodie', 700], ['hearts', 'Heart Tee', 800], ['polka', 'Minty Polka', 900], ['rainbow', 'Rainbow Tee', 1200], ['stars', 'Star Shirt', 1400], ['pirate', 'Pirate Top', 1600], ['tiger', 'Tiger Tee', 1800], ['space', 'Space Suit', 2200]];
export function drawShirt(c, id, w, h) {
  const top = -h * 0.2, bot = h * 0.55;
  const base = { yellow: '#ffd23f', stripes: '#ffffff', hoodie: '#ff5d6c', hearts: '#ffc4e0', polka: '#8fe8c8', rainbow: '#ffffff', stars: '#2a3a8a', pirate: '#ffffff', tiger: '#ff9f43', space: '#e8eefc' }[id] || '#ffd23f';
  c.fillStyle = base; c.fillRect(-w, top, w * 2, bot - top);
  c.save(); c.beginPath(); c.rect(-w, top, w * 2, bot - top); c.clip();
  if (id === 'yellow') { c.fillStyle = '#2a3a8a'; c.font = `900 ${w * 0.42}px ui-rounded,system-ui,sans-serif`; c.textAlign = 'center'; c.fillText('7', 0, h * 0.28); c.fillStyle = '#2a3a8a'; c.fillRect(-w, top + 6, w * 2, 5); }
  else if (id === 'stripes' || id === 'pirate') { c.fillStyle = id === 'pirate' ? '#2a2a3a' : '#3e8cff'; for (let y = top; y < bot; y += 16) c.fillRect(-w, y, w * 2, 8); }
  else if (id === 'hoodie') { c.fillStyle = '#d93a4a'; rr(c, -w * 0.3, h * 0.12, w * 0.6, h * 0.22, 8); c.fill(); c.strokeStyle = '#fff'; c.lineWidth = 3; c.beginPath(); c.moveTo(-6, top + 2); c.lineTo(-8, top + 26); c.moveTo(6, top + 2); c.lineTo(8, top + 26); c.stroke(); }
  else if (id === 'hearts') { c.fillStyle = '#ff4f94'; for (let i = 0; i < 6; i++) { const x = -w * 0.35 + (i % 3) * w * 0.35, y = top + 14 + Math.floor(i / 3) * 26, s = 5; c.beginPath(); c.moveTo(x, y + s); c.bezierCurveTo(x - s * 2, y - s * 0.3, x - s * 0.8, y - s * 1.5, x, y - s * 0.4); c.bezierCurveTo(x + s * 0.8, y - s * 1.5, x + s * 2, y - s * 0.3, x, y + s); c.fill(); } }
  else if (id === 'polka') { c.fillStyle = '#fff'; for (let i = 0; i < 8; i++) { c.beginPath(); c.arc(-w * 0.35 + (i % 4) * w * 0.24, top + 12 + Math.floor(i / 4) * 24, 5, 0, TAU); c.fill(); } }
  else if (id === 'rainbow') { ['#ff5d6c', '#ff9f43', '#ffd23f', '#58d68d', '#3ec6ff', '#b57bff'].forEach((col, i) => { c.fillStyle = col; c.fillRect(-w, top + i * ((bot - top) / 6), w * 2, (bot - top) / 6 + 1); }); }
  else if (id === 'stars') { c.fillStyle = '#ffd23f'; for (let i = 0; i < 5; i++) { starPath(c, -w * 0.3 + (i % 3) * w * 0.3, top + 14 + Math.floor(i / 3) * 24, 6, 2.6); c.fill(); } }
  else if (id === 'tiger') { c.fillStyle = '#3a1d4a'; for (let y = top + 8; y < bot; y += 16) { c.beginPath(); c.moveTo(-w * 0.55, y); c.quadraticCurveTo(-w * 0.3, y - 8, -w * 0.1, y + 2); c.quadraticCurveTo(w * 0.1, y - 8, w * 0.3, y + 2); c.quadraticCurveTo(w * 0.45, y - 6, w * 0.55, y); c.lineTo(w * 0.55, y + 5); c.lineTo(-w * 0.55, y + 5); c.fill(); } }
  else if (id === 'space') { c.fillStyle = '#ff5d6c'; c.beginPath(); c.arc(-w * 0.2, top + 22, 8, 0, TAU); c.fill(); c.fillStyle = '#3ec6ff'; c.beginPath(); c.arc(w * 0.2, top + 22, 8, 0, TAU); c.fill(); c.fillStyle = '#9aa8cc'; c.fillRect(-w, top + 40, w * 2, 6); }
  c.restore();
  c.strokeStyle = 'rgba(0,0,0,0.18)'; c.lineWidth = 3; c.beginPath(); c.moveTo(-w, top); c.lineTo(w, top); c.stroke();
}
