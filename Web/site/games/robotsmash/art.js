// Procedural art for Robot Smash Lab: robot part sprites (cached offscreen canvases), skins and arena backgrounds.
export const R = 2; // sprite resolution (pixels per world unit)
export const PART = {
  head: { w: 44, h: 38 }, torso: { w: 54, h: 60 }, arm: { w: 16, h: 32 }, fore: { w: 18, h: 38 }, thigh: { w: 18, h: 34 }, shin: { w: 20, h: 40 },
};

export const SKINS = {
  classic: { name: 'Classic Tin', price: 0, hat: 'none', desc: 'The original toy bot. Every bot gets a different colour.' },
  astronaut: { name: 'Astro Bot', price: 150, hat: 'astro', desc: 'Bubble helmet for space adventures.', pal: { body: '#f1f5ff', accent: '#ff8a3c', plate: '#ffffff', dark: '#6b7aa8' } },
  knight: { name: 'Sir Clank', price: 220, hat: 'knight', desc: 'Shiny tin armour and a red plume.', pal: { body: '#aeb9cc', accent: '#e34b5a', plate: '#dfe6f2', dark: '#56627b' } },
  pirate: { name: 'Captain Bolt', price: 300, hat: 'pirate', desc: 'Ahoy! Tricorn hat and a star badge.', pal: { body: '#3b4a7a', accent: '#ffd23f', plate: '#f4efe2', dark: '#1d2646' } },
  chef: { name: 'Chef Whisk', price: 400, hat: 'chef', desc: 'A tall puffy hat. Cooking up chaos!', pal: { body: '#ffffff', accent: '#ff5d6c', plate: '#fff4e0', dark: '#8d8aa0' } },
};
export const CLASSIC_PALS = [
  { body: '#4aa8ff', accent: '#ffd23f', plate: '#e3f3ff', dark: '#1f5fb0' },
  { body: '#ff9a3c', accent: '#2fd0c0', plate: '#fff0dc', dark: '#b4570c' },
  { body: '#4cd68d', accent: '#ff6fa8', plate: '#e1fff0', dark: '#1b8a55' },
  { body: '#a77bff', accent: '#ffd23f', plate: '#f0e8ff', dark: '#5b34c2' },
  { body: '#ff6fa8', accent: '#4aa8ff', plate: '#ffe6f1', dark: '#b83369' },
  { body: '#ffd23f', accent: '#ff5d6c', plate: '#fff8d8', dark: '#b58a00' },
];

function hex(h) { return [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)]; }
export function shade(h, a) { const c = hex(h); const t = a < 0 ? 0 : 255, p = Math.abs(a); return 'rgb(' + c.map((v) => Math.round(v + (t - v) * p)).join(',') + ')'; }
function rr(g, x, y, w, h, r) { g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath(); }
function mk(uw, uh, fn) {
  const c = document.createElement('canvas'); c.width = Math.ceil(uw * R); c.height = Math.ceil(uh * R);
  const g = c.getContext('2d'); g.scale(R, R); g.translate(uw / 2, uh / 2); g.lineJoin = 'round'; g.lineCap = 'round'; fn(g);
  return { c, uw, uh };
}
function bolt(g, x, y, r = 2.4, col = '#cfd6e6') {
  g.fillStyle = col; g.strokeStyle = 'rgba(0,0,0,.35)'; g.lineWidth = 0.8; g.beginPath(); g.arc(x, y, r, 0, 6.3); g.fill(); g.stroke();
  g.strokeStyle = 'rgba(0,0,0,.45)'; g.lineWidth = 0.9; g.beginPath(); g.moveTo(x - r * .6, y - r * .3); g.lineTo(x + r * .6, y + r * .3); g.stroke();
}
function cyl(g, w, h, base, dark, r = 7) {
  const gr = g.createLinearGradient(-w / 2, 0, w / 2, 0); gr.addColorStop(0, shade(base, .3)); gr.addColorStop(.35, base); gr.addColorStop(1, shade(base, -.28));
  rr(g, -w / 2, -h / 2, w, h, r); g.fillStyle = gr; g.fill(); g.lineWidth = 2; g.strokeStyle = dark; g.stroke();
  g.fillStyle = 'rgba(255,255,255,.35)'; rr(g, -w / 2 + 2.5, -h / 2 + 3, 2.4, h - 7, 1.2); g.fill();
}

function drawHead(g, pal, hat, mood) {
  const w = 44, h = 38;
  // antenna (classic only)
  if (hat === 'none') {
    g.strokeStyle = pal.dark; g.lineWidth = 2.4; g.beginPath(); g.moveTo(0, -h / 2 + 1); g.lineTo(0, -h / 2 - 9); g.stroke();
    g.fillStyle = pal.accent; g.strokeStyle = pal.dark; g.lineWidth = 1.8; g.beginPath(); g.arc(0, -h / 2 - 11, 4.2, 0, 6.3); g.fill(); g.stroke();
    g.fillStyle = 'rgba(255,255,255,.7)'; g.beginPath(); g.arc(-1.4, -h / 2 - 12.4, 1.4, 0, 6.3); g.fill();
  }
  // ears
  g.fillStyle = pal.accent; g.strokeStyle = pal.dark; g.lineWidth = 1.8;
  rr(g, -w / 2 - 4, -6, 6, 13, 3); g.fill(); g.stroke(); rr(g, w / 2 - 2, -6, 6, 13, 3); g.fill(); g.stroke();
  // shell
  const gr = g.createLinearGradient(-w / 2, -h / 2, w / 2, h / 2); gr.addColorStop(0, shade(pal.body, .35)); gr.addColorStop(.45, pal.body); gr.addColorStop(1, shade(pal.body, -.25));
  rr(g, -w / 2, -h / 2, w, h, 14); g.fillStyle = gr; g.fill(); g.lineWidth = 2.2; g.strokeStyle = pal.dark; g.stroke();
  g.fillStyle = 'rgba(255,255,255,.4)'; rr(g, -w / 2 + 5, -h / 2 + 3, 16, 4, 2); g.fill();
  // face plate
  const fp = g.createLinearGradient(0, -12, 0, 11); fp.addColorStop(0, '#2a3466'); fp.addColorStop(1, '#141a3d');
  rr(g, -17.5, -11, 35, 22, 9); g.fillStyle = fp; g.fill(); g.strokeStyle = 'rgba(0,0,0,.4)'; g.lineWidth = 1; g.stroke();
  const eyeY = -2;
  if (mood === 'dizzy') {
    g.strokeStyle = '#8ff3ff'; g.lineWidth = 1.6;
    for (const ex of [-8, 8]) { g.beginPath(); for (let a = 0; a < 11; a += .4) { const rad = .5 + a * .5; g.lineTo(ex + Math.cos(a) * rad, eyeY + Math.sin(a) * rad); } g.stroke(); }
    g.fillStyle = '#8ff3ff'; g.beginPath(); g.ellipse(0, 6.2, 2.6, 2, 0, 0, 6.3); g.fill();
  } else if (mood === 'happy') {
    g.strokeStyle = '#8ff3ff'; g.lineWidth = 2.4; for (const ex of [-8, 8]) { g.beginPath(); g.arc(ex, eyeY + 2, 3.8, 3.5, 5.9); g.stroke(); }
    g.strokeStyle = '#ffffff'; g.lineWidth = 2; g.beginPath(); g.arc(0, 2, 6, .25, 2.9); g.stroke();
  } else {
    for (const ex of [-8, 8]) { g.fillStyle = '#8ff3ff'; g.beginPath(); g.arc(ex, eyeY, 5, 0, 6.3); g.fill(); g.fillStyle = '#0e1330'; g.beginPath(); g.arc(ex + .6, eyeY + .6, 2.4, 0, 6.3); g.fill(); g.fillStyle = '#fff'; g.beginPath(); g.arc(ex - 1.2, eyeY - 1.6, 1.4, 0, 6.3); g.fill(); }
    g.strokeStyle = '#ffffff'; g.lineWidth = 1.8; g.beginPath(); g.arc(0, 3.2, 5, .3, 2.84); g.stroke();
  }
  // hats
  if (hat === 'astro') {
    g.fillStyle = 'rgba(190,235,255,.22)'; g.strokeStyle = 'rgba(255,255,255,.9)'; g.lineWidth = 2.4; g.beginPath(); g.arc(0, -2, 31, 0, 6.3); g.fill(); g.stroke();
    g.strokeStyle = 'rgba(255,255,255,.85)'; g.lineWidth = 3; g.beginPath(); g.arc(0, -2, 25, 3.5, 4.4); g.stroke();
    g.fillStyle = '#e8edff'; g.strokeStyle = pal.dark; g.lineWidth = 1.8; rr(g, -23, 14, 46, 9, 4); g.fill(); g.stroke();
    g.fillStyle = pal.accent; g.beginPath(); g.arc(-14, 18.5, 2.2, 0, 6.3); g.fill(); g.beginPath(); g.arc(14, 18.5, 2.2, 0, 6.3); g.fill();
  } else if (hat === 'knight') {
    const hg = g.createLinearGradient(-24, -26, 24, -2); hg.addColorStop(0, '#f2f6ff'); hg.addColorStop(.5, '#b4bfd4'); hg.addColorStop(1, '#6c7893');
    g.beginPath(); g.moveTo(-25, -4); g.quadraticCurveTo(-27, -30, 0, -31); g.quadraticCurveTo(27, -30, 25, -4); g.lineTo(18, -9); g.lineTo(-18, -9); g.closePath(); g.fillStyle = hg; g.fill(); g.strokeStyle = '#4a556e'; g.lineWidth = 2.2; g.stroke();
    g.fillStyle = '#4a556e'; rr(g, -14, -17, 28, 3.4, 1.6); g.fill();
    g.fillStyle = pal.accent; g.strokeStyle = '#8c2634'; g.lineWidth = 1.6; g.beginPath(); g.moveTo(-3, -30); g.quadraticCurveTo(-4, -46, 12, -42); g.quadraticCurveTo(4, -40, 5, -30); g.closePath(); g.fill(); g.stroke();
  } else if (hat === 'pirate') {
    g.fillStyle = '#ff5d6c'; g.beginPath(); g.moveTo(-22, -12); g.quadraticCurveTo(0, -22, 22, -12); g.lineTo(22, -18); g.quadraticCurveTo(0, -28, -22, -18); g.fill();
    g.fillStyle = '#20253f'; g.strokeStyle = '#0d1020'; g.lineWidth = 1.8; g.beginPath(); g.moveTo(-30, -14); g.quadraticCurveTo(-22, -24, -12, -26); g.quadraticCurveTo(0, -42, 12, -26); g.quadraticCurveTo(22, -24, 30, -14); g.quadraticCurveTo(0, -20, -30, -14); g.fill(); g.stroke();
    g.fillStyle = pal.accent; g.beginPath(); for (let i = 0; i < 10; i++) { const a = -1.57 + i * .628, rad = i % 2 ? 2.2 : 5; g.lineTo(Math.cos(a) * rad, -26 + Math.sin(a) * rad); } g.closePath(); g.fill();
    g.fillStyle = '#0d1020'; g.beginPath(); g.arc(8, -2, 6.8, 0, 6.3); g.fill(); g.strokeStyle = '#0d1020'; g.lineWidth = 1.6; g.beginPath(); g.moveTo(8, -8); g.lineTo(-20, -14); g.stroke();
  } else if (hat === 'chef') {
    g.fillStyle = '#fff'; g.strokeStyle = '#9aa0bd'; g.lineWidth = 2;
    for (const [x, y, r] of [[-12, -32, 9], [12, -32, 9], [0, -38, 11]]) { g.beginPath(); g.arc(x, y, r, 0, 6.3); g.fill(); g.stroke(); }
    rr(g, -17, -33, 34, 15, 4); g.fill(); g.stroke(); g.fillStyle = '#e9ecf8'; rr(g, -17, -24, 34, 6, 3); g.fill();
  }
}

function drawTorso(g, pal, skin) {
  const w = 54, h = 60;
  const gr = g.createLinearGradient(-w / 2, -h / 2, w / 2, h / 2); gr.addColorStop(0, shade(pal.body, .32)); gr.addColorStop(.5, pal.body); gr.addColorStop(1, shade(pal.body, -.27));
  rr(g, -w / 2, -h / 2, w, h, 13); g.fillStyle = gr; g.fill(); g.lineWidth = 2.4; g.strokeStyle = pal.dark; g.stroke();
  g.fillStyle = 'rgba(255,255,255,.38)'; rr(g, -w / 2 + 5, -h / 2 + 4, 20, 4.5, 2.2); g.fill();
  if (skin === 'pirate') { g.fillStyle = pal.plate; for (let i = 0; i < 4; i++) { rr(g, -w / 2 + 2, -h / 2 + 10 + i * 13, w - 4, 5.5, 2); g.fill(); } }
  if (skin === 'chef') { g.fillStyle = '#fff'; rr(g, -19, -24, 38, 44, 9); g.fill(); g.strokeStyle = '#b9bdd4'; g.lineWidth = 1.6; g.stroke(); g.fillStyle = pal.accent; for (const y of [-10, 2, 14]) { g.beginPath(); g.arc(0, y, 2.6, 0, 6.3); g.fill(); } }
  else {
    const pg = g.createLinearGradient(0, -20, 0, 8); pg.addColorStop(0, shade(pal.plate, .1)); pg.addColorStop(1, shade(pal.plate, -.12));
    rr(g, -18, -20, 36, 30, 8); g.fillStyle = pg; g.fill(); g.lineWidth = 1.6; g.strokeStyle = pal.dark; g.stroke();
    if (skin === 'knight') { g.fillStyle = pal.accent; rr(g, -3, -16, 6, 22, 2); g.fill(); rr(g, -10, -9, 20, 6, 2); g.fill(); }
    else if (skin === 'astro') { g.fillStyle = '#3b6bff'; g.beginPath(); g.arc(-8, -8, 5, 0, 6.3); g.fill(); g.fillStyle = pal.accent; rr(g, 0, -12, 13, 3.4, 1.6); g.fill(); rr(g, 0, -6, 13, 3.4, 1.6); g.fill(); }
    else {
      g.fillStyle = pal.accent; g.strokeStyle = pal.dark; g.lineWidth = 1.6; g.beginPath(); g.arc(0, -5, 8, 0, 6.3); g.fill(); g.stroke();
      g.fillStyle = 'rgba(255,255,255,.65)'; g.beginPath(); g.arc(-2.4, -7.4, 2.6, 0, 6.3); g.fill();
      g.fillStyle = '#ff5d6c'; g.beginPath(); g.arc(-12, 4, 2, 0, 6.3); g.fill(); g.fillStyle = '#4cd68d'; g.beginPath(); g.arc(12, 4, 2, 0, 6.3); g.fill();
    }
  }
  g.fillStyle = pal.dark; rr(g, -w / 2 + 3, 16, w - 6, 9, 3); g.fill();
  g.fillStyle = pal.accent; for (let i = 0; i < 5; i++) rr(g, -18 + i * 8, 18, 4, 5, 1); 
  bolt(g, -22, -25, 2.2); bolt(g, 22, -25, 2.2); bolt(g, -22, 25, 2.2, pal.accent); bolt(g, 22, 25, 2.2, pal.accent);
}

function sprites(pal, skin) {
  const hat = SKINS[skin].hat;
  const o = {};
  o.head = mk(84, 104, (g) => drawHead(g, pal, hat, 'ok'));
  o.headDizzy = mk(84, 104, (g) => drawHead(g, pal, hat, 'dizzy'));
  o.headHappy = mk(84, 104, (g) => drawHead(g, pal, hat, 'happy'));
  o.torso = mk(70, 76, (g) => drawTorso(g, pal, skin));
  const sleeve = skin === 'chef' ? '#ffffff' : (skin === 'pirate' ? '#f4efe2' : pal.body);
  o.arm = mk(30, 46, (g) => { cyl(g, 15, 32, sleeve, pal.dark, 7); bolt(g, 0, -11, 2, pal.accent); });
  o.fore = mk(36, 64, (g) => {
    g.save(); g.translate(0, -6); cyl(g, 16, 26, shade(pal.body, 0), pal.dark, 7); g.restore();
    const hg = g.createRadialGradient(-3, 6, 1, 0, 9, 12); hg.addColorStop(0, shade(pal.accent, .4)); hg.addColorStop(1, pal.accent);
    g.fillStyle = hg; g.strokeStyle = pal.dark; g.lineWidth = 2; g.beginPath(); g.arc(0, 9, 10, 0, 6.3); g.fill(); g.stroke();
    g.strokeStyle = 'rgba(0,0,0,.28)'; g.lineWidth = 1.6; g.beginPath(); g.moveTo(0, 11); g.lineTo(0, 17); g.stroke();
    g.fillStyle = 'rgba(255,255,255,.6)'; g.beginPath(); g.arc(-3.5, 5, 2.4, 0, 6.3); g.fill();
  });
  o.thigh = mk(32, 46, (g) => { cyl(g, 17, 34, pal.body, pal.dark, 7); bolt(g, 0, 10, 2, pal.accent); });
  o.shin = mk(44, 60, (g) => {
    g.save(); g.translate(0, -6); cyl(g, 18, 28, shade(pal.body, -.06), pal.dark, 7); g.restore();
    const bg = g.createLinearGradient(0, 6, 0, 20); bg.addColorStop(0, shade(pal.accent, .25)); bg.addColorStop(1, shade(pal.accent, -.2));
    rr(g, -13, 6, 26, 14, 7); g.fillStyle = bg; g.fill(); g.strokeStyle = pal.dark; g.lineWidth = 2; g.stroke();
    g.fillStyle = 'rgba(255,255,255,.45)'; rr(g, -9, 8.5, 10, 3, 1.5); g.fill();
  });
  return o;
}
const cache = new Map(), iceCache = new Map();
export function getSprites(skin, ci) {
  const pal = skin === 'classic' ? CLASSIC_PALS[ci % CLASSIC_PALS.length] : SKINS[skin].pal;
  const key = skin === 'classic' ? 'c' + (ci % CLASSIC_PALS.length) : skin;
  let s = cache.get(key); if (!s) { s = sprites(pal, skin); s.pal = pal; cache.set(key, s); } return s;
}
export function getIce(key, spr) {
  let c = iceCache.get(spr.c); if (c) return c;
  const o = document.createElement('canvas'); o.width = spr.c.width; o.height = spr.c.height; const g = o.getContext('2d');
  g.drawImage(spr.c, 0, 0); g.globalCompositeOperation = 'source-atop';
  const gr = g.createLinearGradient(0, 0, o.width, o.height); gr.addColorStop(0, 'rgba(235,252,255,.85)'); gr.addColorStop(.5, 'rgba(130,215,255,.7)'); gr.addColorStop(1, 'rgba(90,170,255,.75)');
  g.fillStyle = gr; g.fillRect(0, 0, o.width, o.height);
  c = { c: o, uw: spr.uw, uh: spr.uh }; iceCache.set(spr.c, c); return c;
}

// ---------------------------------------------------------------- arenas
export const ARENAS = {
  lab: { name: 'Test Lab', price: 0, gravity: 1.25, fric: 0.9, rest: 0.1, wallRest: 0.55, desc: 'Where every robot test begins.', c1: '#9fe3ff', c2: '#e8fbff' },
  space: { name: 'Space Station', price: 120, gravity: 0.55, fric: 0.8, rest: 0.1, wallRest: 0.7, desc: 'Low gravity! Everything floats.', c1: '#25205e', c2: '#5a3aa8' },
  candy: { name: 'Candy Factory', price: 260, gravity: 1.2, fric: 0.7, rest: 0.55, wallRest: 0.8, desc: 'Bouncy gummy floors!', c1: '#ffb8e0', c2: '#fff1d0' },
  snow: { name: 'Snowy Workshop', price: 420, gravity: 1.2, fric: 0.03, rest: 0.1, wallRest: 0.6, desc: 'Slippery ice floor. Wheee!', c1: '#2d3f86', c2: '#7eb4ee' },
};
function rnd(seed) { let a = seed; return () => { a = (a * 1664525 + 1013904223) >>> 0; return a / 4294967296; }; }

export function drawArena(g, id, W, H, floorY) {
  const r = rnd(id.length * 977 + 13);
  const A = ARENAS[id];
  const sky = g.createLinearGradient(0, 0, 0, H); sky.addColorStop(0, A.c1); sky.addColorStop(1, A.c2); g.fillStyle = sky; g.fillRect(0, 0, W, H);
  if (id === 'lab') {
    g.strokeStyle = 'rgba(80,150,190,.18)'; g.lineWidth = 2; for (let x = 0; x < W; x += 100) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, floorY); g.stroke(); } for (let y = 0; y < floorY; y += 100) { g.beginPath(); g.moveTo(0, y); g.lineTo(W, y); g.stroke(); }
    // ceiling pipes
    for (const [py, col] of [[34, '#ff9a3c'], [74, '#4aa8ff']]) { const pg = g.createLinearGradient(0, py - 14, 0, py + 14); pg.addColorStop(0, shade(col, .35)); pg.addColorStop(.5, col); pg.addColorStop(1, shade(col, -.3)); g.fillStyle = pg; g.fillRect(0, py - 14, W, 28); for (let x = 90 + py; x < W; x += 260) { g.fillStyle = shade(col, -.2); g.fillRect(x, py - 19, 22, 38); } }
    // window
    const wx = W * 0.5 - 150, wy = 120, ww = 300, wh = 170; rr(g, wx - 12, wy - 12, ww + 24, wh + 24, 26); g.fillStyle = '#fff'; g.fill();
    const wg = g.createLinearGradient(0, wy, 0, wy + wh); wg.addColorStop(0, '#59b8ff'); wg.addColorStop(1, '#c4ecff'); rr(g, wx, wy, ww, wh, 18); g.fillStyle = wg; g.fill();
    g.save(); rr(g, wx, wy, ww, wh, 18); g.clip(); g.fillStyle = 'rgba(255,255,255,.9)'; for (const [cx, cy, cr] of [[wx + 70, wy + 120, 34], [wx + 105, wy + 110, 42], [wx + 150, wy + 124, 30], [wx + 235, wy + 70, 26], [wx + 262, wy + 78, 20]]) { g.beginPath(); g.arc(cx, cy, cr, 0, 6.3); g.fill(); } g.restore();
    g.strokeStyle = '#fff'; g.lineWidth = 6; g.beginPath(); g.moveTo(wx + ww / 2, wy); g.lineTo(wx + ww / 2, wy + wh); g.moveTo(wx, wy + wh / 2); g.lineTo(wx + ww, wy + wh / 2); g.stroke();
    // posters + shelves
    for (const [px, col, ic] of [[W * 0.14, '#ffd23f', 0], [W * 0.84, '#ff7aa8', 1], [W * 0.3, '#7ee0b0', 2]]) { if (Math.abs(px - W / 2) < 190) continue; const py = 150; g.save(); g.translate(px, py); g.rotate((ic - 1) * 0.04); rr(g, -48, -62, 96, 124, 10); g.fillStyle = '#fff'; g.fill(); rr(g, -40, -54, 80, 108, 8); g.fillStyle = col; g.fill(); g.fillStyle = 'rgba(255,255,255,.85)'; g.beginPath(); g.arc(0, -8, 22, 0, 6.3); g.fill(); g.fillStyle = col; g.beginPath(); g.arc(0, -8, 11, 0, 6.3); g.fill(); g.fillStyle = 'rgba(255,255,255,.85)'; rr(g, -26, 28, 52, 8, 4); g.fill(); g.restore(); }
    g.fillStyle = '#7a8aa8'; for (const sx of [W * 0.06, W * 0.92]) { rr(g, sx - 60, 330, 120, 12, 5); g.fill(); for (let i = 0; i < 3; i++) { g.fillStyle = ['#ff5d9e', '#4cd68d', '#ffd23f'][i]; rr(g, sx - 48 + i * 34, 296, 24, 34, 8); g.fill(); g.fillStyle = 'rgba(255,255,255,.5)'; rr(g, sx - 44 + i * 34, 302, 6, 22, 3); g.fill(); g.fillStyle = '#7a8aa8'; } }
  } else if (id === 'space') {
    for (let i = 0; i < 160; i++) { g.fillStyle = 'rgba(255,255,255,' + (0.3 + r() * .6) + ')'; const s = 1 + r() * 2.4; g.beginPath(); g.arc(r() * W, r() * floorY, s, 0, 6.3); g.fill(); }
    const px = W * 0.5, py = floorY * 0.38, pr = Math.min(190, W * 0.22);
    g.fillStyle = '#2b3a78'; g.beginPath(); g.arc(px, py, pr + 28, 0, 6.3); g.fill(); g.fillStyle = '#4b5a9a'; g.beginPath(); g.arc(px, py, pr + 18, 0, 6.3); g.fill();
    const pgr = g.createRadialGradient(px - pr * .3, py - pr * .3, 10, px, py, pr); pgr.addColorStop(0, '#6fd0ff'); pgr.addColorStop(1, '#1d5bd8'); g.fillStyle = pgr; g.beginPath(); g.arc(px, py, pr, 0, 6.3); g.fill();
    g.save(); g.beginPath(); g.arc(px, py, pr, 0, 6.3); g.clip(); g.fillStyle = '#5fd68a'; for (const [dx, dy, s] of [[-.4, -.2, .5], [.3, .2, .6], [-.1, .5, .4], [.5, -.4, .3]]) { g.beginPath(); g.ellipse(px + dx * pr, py + dy * pr, s * pr * .6, s * pr * .4, dx, 0, 6.3); g.fill(); } g.fillStyle = 'rgba(255,255,255,.55)'; for (const [dx, dy] of [[-.2, -.5], [.4, .5], [-.5, .3]]) { g.beginPath(); g.ellipse(px + dx * pr, py + dy * pr, pr * .4, pr * .1, 0, 0, 6.3); g.fill(); } g.restore();
    g.strokeStyle = '#8a95d6'; g.lineWidth = 10; g.beginPath(); g.arc(px, py, pr + 18, 0, 6.3); g.stroke();
    // wall panels
    g.fillStyle = 'rgba(255,255,255,.06)'; for (let x = 0; x < W; x += 180) { rr(g, x + 8, 10, 164, floorY - 20, 14); g.fill(); }
    for (const sx of [W * 0.07, W * 0.93]) { g.fillStyle = '#1b1650'; rr(g, sx - 40, 180, 80, 200, 12); g.fill(); for (let i = 0; i < 5; i++) { g.fillStyle = ['#59f0ff', '#ff6fd8', '#ffd23f', '#59ff9a', '#ff8a3c'][i]; rr(g, sx - 28, 194 + i * 36, 56, 12, 6); g.fill(); } }
  } else if (id === 'candy') {
    g.save(); g.beginPath(); g.rect(0, 0, W, floorY); g.clip(); for (let x = -H; x < W + H; x += 70) { g.fillStyle = 'rgba(255,255,255,.35)'; g.beginPath(); g.moveTo(x, 0); g.lineTo(x + 35, 0); g.lineTo(x + 35 - H * .5, H); g.lineTo(x - H * .5, H); g.fill(); } g.restore();
    const cane = (cx, cy, s) => { g.save(); g.translate(cx, cy); g.scale(s, s); g.lineCap = 'round'; for (const [w, c] of [[44, '#fff'], [34, '#ff4f87']]) { g.strokeStyle = c; g.lineWidth = w; g.beginPath(); g.moveTo(0, 220); g.lineTo(0, 0); g.arc(-46, 0, 46, 0, -Math.PI, true); g.stroke(); } g.strokeStyle = '#fff'; g.lineWidth = 12; g.setLineDash([14, 40]); g.beginPath(); g.moveTo(0, 220); g.lineTo(0, 0); g.arc(-46, 0, 46, 0, -Math.PI, true); g.stroke(); g.restore(); };
    cane(W * 0.1, floorY - 230, 1); cane(W * 0.92, floorY - 230, 1);
    const lolly = (cx, cy, rad, c1, c2) => { g.fillStyle = '#fff'; g.fillRect(cx - 4, cy, 8, 160); for (let i = 0; i < 7; i++) { g.fillStyle = i % 2 ? c1 : c2; g.beginPath(); g.moveTo(cx, cy); g.arc(cx, cy, rad, i * .9, i * .9 + .9); g.fill(); } g.strokeStyle = 'rgba(255,255,255,.7)'; g.lineWidth = 4; g.beginPath(); g.arc(cx, cy, rad, 0, 6.3); g.stroke(); };
    lolly(W * 0.28, 190, 62, '#ff6fa8', '#ffd23f'); lolly(W * 0.74, 150, 74, '#6fd0ff', '#b48aff'); lolly(W * 0.5, 230, 48, '#7ee0b0', '#fff');
    for (let i = 0; i < 40; i++) { g.fillStyle = ['#ff5d9e', '#ffd23f', '#4cd6c8', '#a77bff'][i % 4]; g.save(); g.translate(r() * W, r() * floorY * .8); g.rotate(r() * 3); rr(g, -8, -3, 16, 6, 3); g.fill(); g.restore(); }
  } else if (id === 'snow') {
    g.fillStyle = '#7a4a2b'; g.fillRect(0, 0, W, floorY); for (let x = 0; x < W; x += 64) { const pg = g.createLinearGradient(x, 0, x + 64, 0); pg.addColorStop(0, '#a8683a'); pg.addColorStop(.5, '#b87a46'); pg.addColorStop(1, '#8f5530'); g.fillStyle = pg; g.fillRect(x, 0, 62, floorY); } g.strokeStyle = 'rgba(60,30,10,.25)'; g.lineWidth = 2; for (let i = 0; i < 40; i++) { const x = r() * W, y = r() * floorY; g.beginPath(); g.moveTo(x, y); g.lineTo(x, y + 30 + r() * 50); g.stroke(); }
    const wx = W * 0.5 - 170, wy = 90, ww = 340, wh = 210; g.fillStyle = '#5a3319'; rr(g, wx - 18, wy - 18, ww + 36, wh + 36, 20); g.fill();
    const wg = g.createLinearGradient(0, wy, 0, wy + wh); wg.addColorStop(0, '#1d2a66'); wg.addColorStop(1, '#6c9fe0'); rr(g, wx, wy, ww, wh, 12); g.fillStyle = wg; g.fill();
    g.save(); rr(g, wx, wy, ww, wh, 12); g.clip(); g.fillStyle = '#fffbe0'; g.beginPath(); g.arc(wx + 250, wy + 55, 26, 0, 6.3); g.fill(); g.fillStyle = '#fff'; for (let i = 0; i < 40; i++) { g.beginPath(); g.arc(wx + r() * ww, wy + r() * wh * .7, 1 + r() * 2, 0, 6.3); g.fill(); } g.fillStyle = '#eef6ff'; g.beginPath(); g.moveTo(wx, wy + wh); g.quadraticCurveTo(wx + 90, wy + wh - 80, wx + 170, wy + wh - 40); g.quadraticCurveTo(wx + 260, wy + wh - 90, wx + ww, wy + wh - 20); g.lineTo(wx + ww, wy + wh); g.fill();
    g.fillStyle = '#2f7a55'; for (const [tx, ty] of [[wx + 60, wy + wh - 30], [wx + 290, wy + wh - 35]]) { g.beginPath(); g.moveTo(tx, ty - 80); g.lineTo(tx - 26, ty); g.lineTo(tx + 26, ty); g.fill(); } g.restore();
    g.strokeStyle = '#5a3319'; g.lineWidth = 10; g.beginPath(); g.moveTo(wx + ww / 2, wy); g.lineTo(wx + ww / 2, wy + wh); g.moveTo(wx, wy + wh / 2); g.lineTo(wx + ww, wy + wh / 2); g.stroke();
    // string lights
    g.strokeStyle = '#2a2a2a'; g.lineWidth = 3; g.beginPath(); g.moveTo(0, 20); const n = Math.ceil(W / 140); for (let i = 0; i < n; i++) g.quadraticCurveTo(i * 140 + 70, 70, (i + 1) * 140, 20); g.stroke();
    for (let i = 0; i < n; i++) for (let k = 1; k < 4; k++) { const t = k / 4, x = i * 140 + t * 140, y = 20 + 2 * t * (1 - t) * 50; g.fillStyle = ['#ff5d6c', '#ffd23f', '#4cd68d', '#59c8ff'][(i * 3 + k) % 4]; g.beginPath(); g.arc(x, y + 8, 7, 0, 6.3); g.fill(); g.fillStyle = 'rgba(255,255,255,.7)'; g.beginPath(); g.arc(x - 2, y + 5, 2, 0, 6.3); g.fill(); }
    // shelf with toys
    for (const sx of [W * 0.09, W * 0.91]) { g.fillStyle = '#5a3319'; rr(g, sx - 70, 340, 140, 14, 5); g.fill(); g.fillStyle = '#ff5d6c'; rr(g, sx - 52, 298, 38, 42, 8); g.fill(); g.fillStyle = '#ffd23f'; g.beginPath(); g.arc(sx + 20, 322, 20, 0, 6.3); g.fill(); g.fillStyle = '#4cd68d'; rr(g, sx + 36, 306, 24, 34, 6); g.fill(); }
  }
  // floor
  const fl = g.createLinearGradient(0, floorY, 0, H);
  if (id === 'lab') { fl.addColorStop(0, '#5f7a99'); fl.addColorStop(1, '#3a4d68'); }
  else if (id === 'space') { fl.addColorStop(0, '#6a5fb0'); fl.addColorStop(1, '#2c2468'); }
  else if (id === 'candy') { fl.addColorStop(0, '#9a5a3a'); fl.addColorStop(1, '#6e3a22'); }
  else { fl.addColorStop(0, '#f4fbff'); fl.addColorStop(1, '#a9cdf0'); }
  g.fillStyle = fl; g.fillRect(0, floorY, W, H - floorY);
  if (id === 'lab') { g.fillStyle = '#ffd23f'; g.fillRect(0, floorY, W, 14); g.fillStyle = '#2a3346'; for (let x = -20; x < W + 40; x += 56) { g.beginPath(); g.moveTo(x, floorY); g.lineTo(x + 28, floorY); g.lineTo(x + 14, floorY + 14); g.lineTo(x - 14, floorY + 14); g.fill(); } g.fillStyle = 'rgba(255,255,255,.12)'; for (let x = 0; x < W; x += 120) g.fillRect(x, floorY + 14, 60, H); }
  else if (id === 'space') { g.fillStyle = '#59f0ff'; g.fillRect(0, floorY, W, 6); g.fillStyle = 'rgba(89,240,255,.25)'; g.fillRect(0, floorY + 6, W, 10); g.strokeStyle = 'rgba(255,255,255,.12)'; g.lineWidth = 2; for (let x = 0; x < W; x += 140) { g.beginPath(); g.moveTo(x, floorY + 16); g.lineTo(x, H); g.stroke(); } }
  else if (id === 'candy') { g.fillStyle = '#ffd6ec'; g.beginPath(); g.moveTo(0, floorY + 8); for (let x = 0; x <= W; x += 40) g.quadraticCurveTo(x + 20, floorY + 34, x + 40, floorY + 8); g.lineTo(W, floorY - 4); g.lineTo(0, floorY - 4); g.fill(); for (let i = 0; i < 70; i++) { g.fillStyle = ['#ff5d9e', '#ffd23f', '#4cd6c8', '#a77bff', '#fff'][i % 5]; g.save(); g.translate(r() * W, floorY + 40 + r() * (H - floorY - 40)); g.rotate(r() * 3); rr(g, -7, -2.5, 14, 5, 2.5); g.fill(); g.restore(); } }
  else { g.fillStyle = '#fff'; g.beginPath(); g.moveTo(0, floorY + 10); for (let x = 0; x <= W; x += 70) g.quadraticCurveTo(x + 35, floorY + 30, x + 70, floorY + 10); g.lineTo(W, floorY - 3); g.lineTo(0, floorY - 3); g.fill(); g.fillStyle = 'rgba(255,255,255,.8)'; for (let i = 0; i < 30; i++) { g.beginPath(); g.arc(r() * W, floorY + 30 + r() * (H - floorY - 30), 2 + r() * 3, 0, 6.3); g.fill(); } }
  g.fillStyle = 'rgba(0,0,0,.14)'; g.fillRect(0, floorY - 2, W, 4);
  // vignette
  const vg = g.createRadialGradient(W / 2, H / 2, Math.min(W, H) * .4, W / 2, H / 2, Math.max(W, H) * .8); vg.addColorStop(0, 'rgba(0,0,0,0)'); vg.addColorStop(1, 'rgba(10,10,40,.28)'); g.fillStyle = vg; g.fillRect(0, 0, W, H);
}

// animated decorations drawn every frame (cheap)
export function drawArenaAnim(g, id, t, W, H, floorY) {
  if (id === 'lab') {
    g.save(); g.translate(W * 0.2, floorY - 120 > 300 ? 260 : 240); g.rotate(t * .5); gear(g, 54, '#ff9a3c'); g.restore();
    g.save(); g.translate(W * 0.2 + 76, 296); g.rotate(-t * .5 + .3); gear(g, 34, '#4aa8ff'); g.restore();
    g.fillStyle = Math.sin(t * 3) > 0 ? '#ff5d6c' : '#7a2a35'; g.beginPath(); g.arc(W * 0.9, 190, 9, 0, 6.3); g.fill();
  } else if (id === 'space') {
    g.fillStyle = '#fff'; for (let i = 0; i < 18; i++) { const a = .3 + .7 * Math.abs(Math.sin(t * 1.3 + i * 1.7)); g.globalAlpha = a; g.beginPath(); g.arc((i * 137.5) % W, ((i * 71) % (floorY - 40)) + 10, 2.4, 0, 6.3); g.fill(); } g.globalAlpha = 1;
  } else if (id === 'candy') {
    g.save(); g.translate(W * 0.28, 190); g.rotate(t * .4); g.strokeStyle = 'rgba(255,255,255,.9)'; g.lineWidth = 6; g.beginPath(); for (let a = 0; a < 18; a += .3) g.lineTo(Math.cos(a) * a * 3.2, Math.sin(a) * a * 3.2); g.stroke(); g.restore();
  } else if (id === 'snow') {
    g.fillStyle = 'rgba(255,255,255,.9)'; for (let i = 0; i < 46; i++) { const sp = 22 + (i % 5) * 9; const y = ((t * sp + i * 97) % (floorY + 40)) - 20, x = ((i * 131.7) % W) + Math.sin(t + i) * 16; g.beginPath(); g.arc(x, y, 1.8 + (i % 3), 0, 6.3); g.fill(); }
  }
}
function gear(g, r, col) {
  g.fillStyle = col; g.strokeStyle = shade(col, -.35); g.lineWidth = 3; g.beginPath();
  for (let i = 0; i < 12; i++) { const a = i * Math.PI / 6; g.lineTo(Math.cos(a - .12) * r, Math.sin(a - .12) * r); g.lineTo(Math.cos(a - .09) * (r + 9), Math.sin(a - .09) * (r + 9)); g.lineTo(Math.cos(a + .09) * (r + 9), Math.sin(a + .09) * (r + 9)); g.lineTo(Math.cos(a + .12) * r, Math.sin(a + .12) * r); }
  g.closePath(); g.fill(); g.stroke(); g.fillStyle = 'rgba(255,255,255,.35)'; g.beginPath(); g.arc(0, 0, r * .55, 0, 6.3); g.fill(); g.fillStyle = shade(col, -.3); g.beginPath(); g.arc(0, 0, r * .22, 0, 6.3); g.fill();
}
