import * as THREE from 'three';
import { Maestro, THEMES } from '../shared/maestro.js';
import { World, T, easeOutBack, easeOutCubic, yawForTile } from './world.js';
import { AVATARS, SETS, TILES, CARDS, STICKERS, RARITY, GOALS, rentFactor, upgradeCost, levelName } from './data.js';
import { glyph, stickerCanvas, faceCanvas } from './icons.js';

const $ = (s) => document.querySelector(s);
const qs = new URLSearchParams(location.search);
const store = { get(k, d) { try { const v = localStorage.getItem('tt_' + k); return v == null ? d : JSON.parse(v); } catch (e) { return d; } }, set(k, v) { try { localStorage.setItem('tt_' + k, JSON.stringify(v)); } catch (e) {} } };
const rnd = (a, b) => a + Math.random() * (b - a), pick = (a) => a[Math.floor(Math.random() * a.length)];
const money = (n) => '$' + Math.round(n).toLocaleString('en-US');

// ---------- icons ----------
const IC = {
  dice: '<svg viewBox="0 0 48 48"><rect x="5" y="5" width="38" height="38" rx="10" fill="#fff"/><circle cx="16" cy="16" r="4" fill="#ff5a7a"/><circle cx="32" cy="16" r="4" fill="#ff5a7a"/><circle cx="24" cy="24" r="4" fill="#ff5a7a"/><circle cx="16" cy="32" r="4" fill="#ff5a7a"/><circle cx="32" cy="32" r="4" fill="#ff5a7a"/></svg>',
  pause: '<svg viewBox="0 0 24 24"><rect x="5" y="4" width="5" height="16" rx="2" fill="#2b2f5a"/><rect x="14" y="4" width="5" height="16" rx="2" fill="#2b2f5a"/></svg>',
  play: '<svg viewBox="0 0 24 24"><path d="M7 4l13 8-13 8z" fill="#fff" stroke="#fff" stroke-width="2" stroke-linejoin="round"/></svg>',
  sndOn: '<svg viewBox="0 0 24 24" fill="none" stroke="#2b2f5a" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9h4l5-4v14l-5-4H4z" fill="#2b2f5a"/><path d="M16 8.5a5 5 0 010 7M18.5 6a8.5 8.5 0 010 12"/></svg>',
  sndOff: '<svg viewBox="0 0 24 24" fill="none" stroke="#2b2f5a" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9h4l5-4v14l-5-4H4z" fill="#2b2f5a"/><path d="M17 9l5 6M22 9l-5 6"/></svg>',
  ff: '<svg viewBox="0 0 24 24" fill="#2b2f5a"><path d="M3 5l8 7-8 7zM12 5l8 7-8 7z" stroke="#2b2f5a" stroke-width="1.6" stroke-linejoin="round"/></svg>',
  map: '<svg viewBox="0 0 24 24" fill="none" stroke="#2b2f5a" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><circle cx="10.5" cy="10.5" r="6.5"/><path d="M15.5 15.5L21 21M8 10.5h5"/></svg>',
  x: '<svg viewBox="0 0 24 24" stroke="#5a6288" stroke-width="3.2" stroke-linecap="round"><path d="M6 6l12 12M18 6L6 18"/></svg>',
  home: '<svg viewBox="0 0 24 24" fill="#fff"><path d="M3 12L12 4l9 8h-2.5v8h-4.5v-5h-4v5H5.5v-8z" stroke="#fff" stroke-width="1.5" stroke-linejoin="round"/></svg>',
  town: '<svg viewBox="0 0 48 48"><rect x="6" y="22" width="16" height="20" rx="3" fill="#fff"/><rect x="24" y="10" width="18" height="32" rx="3" fill="#ffe27a"/><path d="M4 23l10-10 10 10z" fill="#ff7a8a"/><rect x="10" y="28" width="4" height="4" fill="#6fd0ff"/><rect x="28" y="16" width="4" height="4" fill="#6fd0ff"/><rect x="34" y="16" width="4" height="4" fill="#6fd0ff"/><rect x="28" y="26" width="4" height="4" fill="#6fd0ff"/><rect x="34" y="26" width="4" height="4" fill="#6fd0ff"/><rect x="29" y="34" width="8" height="8" rx="2" fill="#a8683f"/></svg>',
  book: '<svg viewBox="0 0 24 24"><path d="M4 4h12a3 3 0 013 3v13H7a3 3 0 01-3-3z" fill="#fff"/><path d="M4 17a3 3 0 013-3h12" fill="none" stroke="#a56cf0" stroke-width="2"/><path d="M12 6.5l1.1 2.3 2.5.3-1.8 1.7.5 2.5-2.3-1.2-2.3 1.2.5-2.5-1.8-1.7 2.5-.3z" fill="#ffc61a"/></svg>',
  trophy: '<svg viewBox="0 0 24 24"><path d="M7 3h10v6a5 5 0 01-10 0z" fill="#ffd93b"/><path d="M7 5H3c0 4 1.5 6 4 6M17 5h4c0 4-1.5 6-4 6" fill="none" stroke="#ffb21c" stroke-width="2"/><rect x="10.5" y="13" width="3" height="4" fill="#ffb21c"/><rect x="7" y="17" width="10" height="3.5" rx="1.5" fill="#ff9f1c"/></svg>',
  restart: '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M4 12a8 8 0 108-8H8M8 4L4.5 7.5 8 11"/></svg>',
  shovel: '<svg viewBox="0 0 24 24"><rect x="11" y="2" width="2.4" height="12" rx="1.2" fill="#a8683f" transform="rotate(25 12 8)"/><path d="M7 13l4 -2 5 8-4 3z" fill="#cfd6e0" stroke="#8a95a8" stroke-width="1.2" stroke-linejoin="round" transform="rotate(-4 12 16)"/></svg>',
  star: '<svg viewBox="0 0 24 24"><path d="M12 2l2.9 6.3 6.9.8-5.1 4.7 1.4 6.8L12 17.1 5.9 20.6l1.4-6.8L2.2 9.1l6.9-.8z" fill="#ffc928" stroke="#ff9f1c" stroke-width="1.2" stroke-linejoin="round"/></svg>',
  starE: '<svg viewBox="0 0 24 24"><path d="M12 2l2.9 6.3 6.9.8-5.1 4.7 1.4 6.8L12 17.1 5.9 20.6l1.4-6.8L2.2 9.1l6.9-.8z" fill="#d6dcee"/></svg>',
};

// ---------- audio ----------
const music = new Maestro(); let muted = !!store.get('mute', false); music.muted = muted;
const BOARD = { ...THEMES.board, bpm: 108 };
let musicStarted = false;
const sfx = (n, o) => { try { music.sfx(n, o); } catch (e) {} };
function unlockAudio() { try { music.unlock(); if (!musicStarted) { musicStarted = true; music.play(BOARD); music.setIntensity(0.45); } } catch (e) {} }
const setIntensity = (x) => { try { music.setIntensity(x); } catch (e) {} };

// ---------- world ----------
let world;
try { world = new World($('#c')); } catch (e) { document.body.insertAdjacentHTML('beforeend', '<div style="position:fixed;inset:0;display:grid;place-items:center;background:#8fd4ff;font-size:24px;text-align:center;padding:20px">Tycoon Town needs WebGL.<br>Please try a newer browser.</div>'); throw e; }
world.sfxHook = sfx;
window.addEventListener('resize', () => world.resize()); window.addEventListener('orientationchange', () => setTimeout(() => world.resize(), 200));
if (qs.get('speed')) T.speed = parseFloat(qs.get('speed')) || 1;
const AUTO = qs.has('auto');

// ---------- state ----------
let G = null; // current game
const progress = () => store.get('goals', { p: {}, c: {} });
function bump(id, n = 1) { const g = progress(); g.p[id] = (g.p[id] || 0) + n; store.set('goals', g); const goal = GOALS.find((x) => x.id === id); if (goal && g.p[id] >= goal.need && !g.c[id] && !g.notified?.[id]) { g.notified = g.notified || {}; g.notified[id] = 1; store.set('goals', g); toastGoal(goal); } }
function toastGoal(goal) { banner('Goal done: ' + goal.name + '! Tap Goals', '#a56cf0'); sfx('powerup'); }
const stickers = () => store.get('stickers', {});
function addSticker(id) { const s = stickers(); const isNew = !s[id]; s[id] = (s[id] || 0) + 1; store.set('stickers', s); return isNew; }
function rollStickerId(boost = 0) { const r = Math.random() * 100 - boost * 15; const rar = r < 1 ? 3 : r < 8 ? 2 : r < 32 ? 1 : 0; const pool = STICKERS.filter((s) => s.rar === rar); return pick(pool.length ? pool : STICKERS).id; }

function netWorth(p) { let n = p.cash; for (const t of G.tiles) if (t.owner === p.id) n += t.price + t.invest; return Math.round(n); }
const tileData = (i) => TILES[i];
function ownedCount(p, set) { return G.tiles.filter((t) => t.owner === p.id && t.set === set).length; }
const hasSet = (p, set) => SETS[set] && set !== 'station' && set !== 'util' && ownedCount(p, set) === SETS[set].size;
function rentFor(i, roll) {
  const d = TILES[i], t = G.tiles[i], o = G.players[t.owner];
  if (d.type === 'station') return [0, 25, 50, 100, 200][ownedCount(o, 'station')];
  if (d.type === 'util') return roll * (ownedCount(o, 'util') === 2 ? 10 : 4);
  return Math.round((d.price * rentFactor[t.level] * (hasSet(o, d.set) ? 2 : 1)) / 5) * 5;
}

// ---------- ui helpers ----------
const hud = $('#hud'), modalEl = $('#modal'), bannerEl = $('#banner'), hintEl = $('#hint');
function hydrate(root) {
  root.querySelectorAll('canvas[data-g]').forEach((c) => { c.width = c.height = 128; glyph(c.getContext('2d'), c.dataset.g, 64, 64, 56); });
  root.querySelectorAll('canvas[data-s]').forEach((c) => { const d = STICKERS.find((s) => s.id === c.dataset.s); c.width = c.height = 160; c.getContext('2d').drawImage(stickerCanvas(d, 160, c.dataset.lock === '1'), 0, 0); });
  root.querySelectorAll('canvas[data-f]').forEach((c) => { const a = AVATARS.find((s) => s.id === c.dataset.f); c.width = c.height = 128; c.getContext('2d').drawImage(faceCanvas(a, 128), 0, 0); });
}
function mkSheet(html, cls = '') { const d = document.createElement('div'); d.className = 'sheet ' + cls; d.innerHTML = html; hydrate(d); return d; }
function showModal(node) { modalEl.innerHTML = ''; modalEl.appendChild(node); modalEl.classList.add('show'); sfx('pop'); }
function closeModal() { modalEl.classList.remove('show'); modalEl.innerHTML = ''; }
// show a sheet and resolve with the data-v of the clicked button
function ask(node, dismissible = false) {
  return new Promise((res) => {
    showModal(node);
    const h = (e) => { const b = e.target.closest('[data-v]'); if (b && !b.disabled) { sfx('click'); done(b.dataset.v); } };
    const done = (v) => { node.removeEventListener('click', h); if (modalEl.firstChild === node) closeModal(); res(v); };
    node.addEventListener('click', h);
    if (dismissible) modalEl.onclick = (e) => { if (e.target === modalEl) { modalEl.onclick = null; done('x'); } }; else modalEl.onclick = null;
    if (AUTO) { const b = node.querySelector('[data-def]') || node.querySelector('[data-v]'); if (b) setTimeout(() => b.click(), 150); }
  });
}
const xbtn = '<button class="xbtn" data-v="x" aria-label="Close">' + IC.x + '</button>';
let bannerT = 0;
function banner(text, color = '#4fb4f0', face) {
  bannerEl.style.background = color; bannerEl.innerHTML = (face ? '<canvas width="96" height="96"></canvas>' : '') + '<span>' + text + '</span>';
  if (face) bannerEl.querySelector('canvas').getContext('2d').drawImage(faceCanvas(face, 96), 0, 0);
  bannerEl.classList.remove('show'); void bannerEl.offsetWidth; bannerEl.classList.add('show');
}
const tmpV = new THREE.Vector3(), scr = { x: 0, y: 0, vis: true };
function floatText(v3, text, cls = 'y') { world.toScreen(v3, scr); const d = document.createElement('div'); d.className = 'fl ' + cls; d.textContent = text; d.style.left = scr.x + 'px'; d.style.top = scr.y + 'px'; document.body.appendChild(d); setTimeout(() => d.remove(), 1700); }
function hint(key, text, ms = 5000) {
  const seen = store.get('hints', {}); if (seen[key] && !AUTO) return; seen[key] = 1; store.set('hints', seen);
  hintEl.textContent = text; hintEl.classList.remove('hidden'); clearTimeout(hint.t); hint.t = setTimeout(() => hintEl.classList.add('hidden'), ms);
}
const hideHint = () => hintEl.classList.add('hidden');

// ---------- HUD ----------
const playersEl = $('#players'), goalEl = $('#goalbar'), tbtns = $('#tbtns'), rollBtn = $('#roll'), townBtn = $('#town'), turnLbl = $('#turnlbl');
rollBtn.innerHTML = '<div class="in">' + IC.dice + '<span>ROLL!</span></div>';
townBtn.innerHTML = IC.town + '<span>My Town</span>';
function buildTopButtons() {
  tbtns.innerHTML = `<button class="rb" id="bSpeed" aria-label="Speed">${IC.ff}</button><button class="rb" id="bView" aria-label="View">${IC.map}</button><button class="rb" id="bSnd" aria-label="Sound">${muted ? IC.sndOff : IC.sndOn}</button><button class="rb" id="bPause" aria-label="Pause">${IC.pause}</button>`;
  $('#bSpeed').onclick = () => { unlockAudio(); const sp = [1, 2, 4]; const base = parseFloat(qs.get('speed')) || 1; G.speed = ((G.speed || 0) + 1) % 3; T.speed = base * sp[G.speed]; $('#bSpeed').classList.toggle('on', G.speed > 0); sfx('click'); banner('Speed x' + sp[G.speed], '#4fb4f0'); };
  $('#bView').onclick = () => { world.view.zoomOut = !world.view.zoomOut; $('#bView').classList.toggle('on', world.view.zoomOut); sfx('click'); };
  $('#bSnd').onclick = toggleMute; $('#bPause').onclick = openPause;
}
function toggleMute() { muted = !muted; store.set('mute', muted); try { music.setMuted(muted); } catch (e) {} const b = $('#bSnd'); if (b) b.innerHTML = muted ? IC.sndOff : IC.sndOn; }
function buildPlayers() {
  playersEl.innerHTML = '';
  G.players.forEach((p) => {
    const d = document.createElement('div'); d.className = 'pc' + (p.human ? ' me' : ''); d.style.setProperty('--c', p.css); d.innerHTML = `<canvas width="96" height="96"></canvas><div class="info"><div class="nm">${p.human ? 'You' : p.name}</div><div class="cash"><i></i><span>0</span></div><div class="bar"><b></b></div></div>`;
    d.querySelector('canvas').getContext('2d').drawImage(faceCanvas(p.av, 96), 0, 0); p.el = d; p.cashEl = d.querySelector('.cash span'); p.barEl = d.querySelector('.bar b'); playersEl.appendChild(d);
  });
}
function updateGoalbar() {
  const lead = G.players.reduce((a, b) => (netWorth(b) > netWorth(a) ? b : a));
  goalEl.innerHTML = `<span>Round <b>${Math.min(G.round, G.maxRounds)}/${G.maxRounds}</b></span><span>Goal <b>${money(G.goal)}</b></span><span>Leader <b style="color:${lead.css}">${lead.human ? 'You' : lead.name}</b></span>`;
}
function tickHud(dt) {
  if (!G) return;
  for (const p of G.players) {
    if (Math.round(p.shown) !== p.cash) { const d = p.cash - p.shown; p.shown += Math.sign(d) * Math.max(1, Math.abs(d) * Math.min(1, dt * 7)); if (Math.abs(p.cash - p.shown) < 1) p.shown = p.cash; p.cashEl.textContent = money(p.shown); }
    const w = Math.min(100, (netWorth(p) / G.goal) * 100); if (p._w !== Math.round(w)) { p._w = Math.round(w); p.barEl.style.width = w + '%'; }
  }
}
function setCurrent(p) {
  G.players.forEach((q) => { q.el.classList.toggle('cur', q === p); q.token.mark.visible = q === p; });
  world.view.follow = (out) => out.copy(p.token.g.position);
  const mine = p.human && !AUTO;
  townBtn.classList.toggle('off', !mine);
  turnLbl.innerHTML = p.human ? '' : `<canvas width="64" height="64"></canvas><span>${p.name} is playing…</span>`;
  if (!p.human) turnLbl.querySelector('canvas').getContext('2d').drawImage(faceCanvas(p.av, 64), 0, 0);
  turnLbl.classList.toggle('off', p.human);
}
function updateTownBadge() {
  const me = G.players[0]; const n = G.tiles.filter((t) => t.owner === 0 && t.type === 'prop' && t.level < 3 && me.cash >= upgradeCost(TILES[t.i], t.level + 1)).length;
  townBtn.querySelector('.badge')?.remove(); if (n) townBtn.insertAdjacentHTML('beforeend', `<div class="badge">${n}</div>`);
}

// ---------- money ----------
function tokenPos(p, dy = 1.4) { return tmpV.copy(p.token.g.position).setY(p.token.g.position.y + dy).clone(); }
function gain(p, amt, label) {
  p.cash += amt; const from = tokenPos(p, 3.2), to = tokenPos(p, 1.0);
  world.coinFly(from, to, Math.min(10, Math.max(3, Math.round(amt / 40))), 1.5); floatText(tokenPos(p, 2.0), '+' + money(amt), 'g'); sfx('coin'); if (label) { /* label shown by caller via banner */ }
}
function raiseCash(p, need) {
  // auto-sell lower buildings / properties so nobody is ever knocked out; returns notes
  const notes = [];
  while (p.cash < need) {
    const mine = G.tiles.filter((t) => t.owner === p.id).sort((a, b) => a.price - b.price); if (!mine.length) break; const t = mine[0];
    if (t.type === 'prop' && t.level > 1) { const refund = Math.round(upgradeCost(TILES[t.i], t.level) / 2); t.level--; t.invest -= upgradeCost(TILES[t.i], t.level + 1); p.cash += refund; world.setLevel(t.i, t.level, false); notes.push('Sold an upgrade at ' + t.name); }
    else { p.cash += Math.round(t.price / 2); t.owner = -1; t.level = 0; t.invest = 0; world.setOwner(t.i, -1); notes.push('Sold ' + t.name); }
  }
  return notes;
}
async function payTo(p, amt, to, why) {
  if (amt <= 0) return;
  const notes = raiseCash(p, amt); if (notes.length) { banner(notes[0], '#ff8a3d'); await T.wait(0.9); }
  const real = Math.min(p.cash, amt); p.cash -= real;
  const from = tokenPos(p, 1.4); floatText(from, '-' + money(real), 'r'); sfx('hurt');
  if (to) { await world.coinFly(from, tokenPos(to, 1.4), Math.min(10, Math.max(3, Math.round(real / 30))), 2); to.cash += real; floatText(tokenPos(to, 2.0), '+' + money(real), 'g'); sfx('coin'); if (to.human) bump('rent', real); } else { G.pot += real; await T.wait(0.5); }
  await T.wait(0.5);
}

// ---------- cards ----------
function rentTable(i) {
  const d = TILES[i]; const c = d.set ? SETS[d.set].css : '#888';
  if (d.type === 'station') return `<div class="rent">${[1, 2, 3, 4].map((n) => `<span class="lv">${'<i></i>'.repeat(n)}</span><span>${n} station${n > 1 ? 's' : ''}</span><b>${money([0, 25, 50, 100, 200][n])}</b>`).join('')}</div>`;
  if (d.type === 'util') return '<div class="rent"><span class="lv"><i></i></span><span>One power pal</span><b>dice × 4</b><span class="lv"><i></i><i></i></span><span>Both power pals</span><b>dice × 10</b></div>';
  return `<div class="rent">${[1, 2, 3].map((l) => `<span class="lv">${'<i></i>'.repeat(l)}</span><span>${levelName[l]}</span><b>${money(d.price * rentFactor[l])}</b>`).join('')}</div><div class="note">Own all ${SETS[d.set].size} ${SETS[d.set].name} homes for <b>double rent</b>!</div>`;
}
function propCardHTML(i, opts = {}) {
  const d = TILES[i], set = SETS[d.set]; const gl = d.type === 'station' ? 'rocket' : d.type === 'util' ? 'bolt' : 'house';
  const t = G && G.tiles[i]; const ownerLine = t && t.owner >= 0 ? `<small>Owned by ${G.players[t.owner].human ? 'you' : G.players[t.owner].name} · ${t.type === 'prop' ? levelName[t.level] : 'Ready'}</small>` : `<small>${set.name}</small>`;
  return `<div class="hd" style="background:linear-gradient(${set.css},${set.css}dd)"><div class="ic"><canvas data-g="${gl}"></canvas></div><h2>${d.name}</h2>${ownerLine}</div><div class="bd" style="--c:${set.css}">${opts.price !== false ? `<div class="price"><canvas data-g="coin" style="width:1.8rem;height:1.8rem"></canvas>${money(d.price)}</div>` : ''}${rentTable(i)}${opts.extra || ''}</div>`;
}
async function offerBuy(p, i) {
  const d = TILES[i]; const can = p.cash >= d.price;
  if (p.human && !AUTO) {
    const sh = mkSheet(propCardHTML(i, { extra: `<div class="row"><button class="btn gray" data-v="skip">Skip</button><button class="btn" data-v="buy" data-def ${can ? '' : 'disabled'}>${can ? 'Buy ' + money(d.price) : 'Need ' + money(d.price - p.cash) + ' more'}</button></div>` }), 'pcard');
    const v = await ask(sh); return v === 'buy';
  }
  const set = d.set; const after = p.cash - d.price; const partner = G.tiles.some((t) => t.set === set && t.owner === p.id);
  if (!can || after < 60) return false; if (after < 250 && !partner) return Math.random() < 0.4; return Math.random() < 0.9;
}
async function doBuy(p, i) {
  const t = G.tiles[i]; p.cash -= t.price; t.owner = p.id; t.level = TILES[i].type === 'prop' ? 1 : 0; t.invest = 0; floatText(tokenPos(p, 2.0), '-' + money(t.price), 'r');
  sfx('powerup'); world.flashTile(i, p.color); world.setOwner(i, p.id, p.color, true); world.confetti(world.tiles[i].pos.clone().setY(3), 24, 0.6);
  if (t.type === 'prop') await world.setLevel(i, 1, true); else { world.sparkle(world.tiles[i].pos.clone().setY(1.4), 20); await T.wait(0.5); }
  if (p.human) bump('buy', 1);
  if (t.type === 'prop' && hasSet(p, t.set)) {
    banner(`${SETS[t.set].name} complete! Double rent!`, '#ff6fae', p.av); sfx('win'); world.confetti(world.tiles[i].pos.clone().setY(2), 90, 1); gain(p, 100);
    for (const o of G.tiles) if (o.set === t.set) world.flashTile(o.i, SETS[t.set].hex); if (p.human) { bump('sets', 1); await T.wait(1.2); await giveSticker(p, 1); } else await T.wait(1.2);
  }
}
async function doUpgrade(p, i, free = false) {
  const t = G.tiles[i]; if (t.type !== 'prop' || t.level >= 3) return false; const lv = t.level + 1, cost = free ? 0 : upgradeCost(TILES[i], lv);
  if (p.cash < cost) return false; p.cash -= cost; t.invest += cost; t.level = lv; if (cost) floatText(tokenPos(p, 2.0), '-' + money(cost), 'r');
  const prevFollow = world.view.follow; if (!p.human || world.view.follow) world.view.follow = (out) => out.copy(world.tiles[i].pos); world.view.tYaw = yawForTile(i);
  await world.setLevel(i, lv, true); world.view.follow = prevFollow;
  if (lv === 3 && p.human) bump('sky', 1);
  return true;
}
function bestUpgrade(p, budget, ) {
  const c = G.tiles.filter((t) => t.owner === p.id && t.type === 'prop' && t.level < 3 && upgradeCost(TILES[t.i], t.level + 1) <= budget);
  c.sort((a, b) => (hasSet(p, b.set) - hasSet(p, a.set)) || (b.price - a.price)); return c[0];
}
async function openTown(p) {
  for (;;) {
    const mine = G.tiles.filter((t) => t.owner === p.id);
    let rows = '';
    if (!mine.length) rows = '<p>You do not own any buildings yet. Land on a property and tap <b>Buy</b>!</p>';
    else for (const t of mine.sort((a, b) => a.i - b.i)) {
      const set = SETS[t.set]; let act = '';
      if (t.type === 'prop') { if (t.level >= 3) act = '<span class="pill">MAX</span>'; else { const c = upgradeCost(TILES[t.i], t.level + 1); act = `<button class="btn ${p.cash >= c ? '' : 'gray'}" data-v="up${t.i}" ${p.cash >= c ? '' : 'disabled'}>${levelName[t.level + 1]} ${money(c)}</button>`; } }
      rows += `<div class="tr" style="--c:${set.css}"><div class="cd"></div><div class="t"><b>${t.name}</b><span>${t.type === 'prop' ? levelName[t.level] + ' · rent ' + money(rentFor(t.i, 7)) : 'Rent ' + money(rentFor(t.i, 7))}</span></div>${act}</div>`;
    }
    const sh = mkSheet(`${xbtn}<h2>My Town</h2><p>Cash ${money(p.cash)} · Build bigger for more rent!</p><div class="town">${rows}</div>`, 'wide');
    const v = await ask(sh, true); if (!v.startsWith('up')) return;
    const i = +v.slice(2); await doUpgrade(p, i); sfx('win'); setCurrent(p);
  }
}

// ---------- stickers / minigames / wheel ----------
async function giveSticker(p, boost = 0) {
  const id = rollStickerId(boost); const isNew = addSticker(id); const d = STICKERS.find((s) => s.id === id); sfx('powerup'); world.confetti(tokenPos(p, 2), 40, 0.8);
  if (!p.human || AUTO) { return; }
  const sh = mkSheet(`<h2>Sticker!</h2><div class="stkbig"><canvas data-s="${id}"></canvas></div><p><b>${d.name}</b> · ${RARITY[d.rar]} ${isNew ? '<span class="new">NEW!</span>' : ''}</p><div class="row"><button class="btn" data-v="ok" data-def>Yay!</button></div>`);
  await ask(sh);
}
const PRIZES = [{ k: 'cash', v: 100, l: '$100', c: '#ff7ac0', w: 3 }, { k: 'cash', v: 250, l: '$250', c: '#4fb4f0', w: 2 }, { k: 'sticker', l: 'Sticker', c: '#ffc61a', g: 'star', w: 2 }, { k: 'cash', v: 50, l: '$50', c: '#5fd36b', w: 3 }, { k: 'up', l: 'Upgrade', c: '#ff9a3c', g: 'house', w: 1.5 }, { k: 'cash', v: 500, l: '$500', c: '#a56cf0', w: 0.7 }, { k: 'sticker', l: 'Sticker', c: '#ff6a6a', g: 'heart', w: 2 }, { k: 'cash', v: 150, l: '$150', c: '#2cc4b2', w: 2.5 }];
function wheelPrize() { const tot = PRIZES.reduce((a, b) => a + b.w, 0); let r = Math.random() * tot; for (let i = 0; i < PRIZES.length; i++) { r -= PRIZES[i].w; if (r <= 0) return i; } return 0; }
function drawWheel(cv) {
  const S = 640; cv.width = cv.height = S; const c = cv.getContext('2d'); const seg = (Math.PI * 2) / 8, m = S / 2;
  PRIZES.forEach((pz, i) => {
    const a0 = -Math.PI / 2 - seg / 2 + i * seg; c.beginPath(); c.moveTo(m, m); c.arc(m, m, m - 6, a0, a0 + seg); c.closePath(); c.fillStyle = pz.c; c.fill(); c.strokeStyle = '#fff'; c.lineWidth = 6; c.stroke();
    c.save(); c.translate(m, m); c.rotate(a0 + seg / 2 + Math.PI / 2); c.fillStyle = '#fff'; c.font = '900 56px ui-rounded, system-ui, sans-serif'; c.textAlign = 'center'; c.shadowColor = 'rgba(0,0,0,.35)'; c.shadowBlur = 0; c.shadowOffsetY = 4;
    if (pz.g) { glyph(c, pz.g, 0, -m * 0.7, 52); c.font = '900 30px ui-rounded, system-ui, sans-serif'; c.fillText(pz.l, 0, -m * 0.47); } else { c.fillText(pz.l, 0, -m * 0.55); }
    c.restore();
  });
  c.beginPath(); c.arc(m, m, m - 3, 0, 7); c.lineWidth = 12; c.strokeStyle = '#ffc61a'; c.stroke();
  for (let i = 0; i < 16; i++) { const a = (i / 16) * Math.PI * 2; c.fillStyle = i % 2 ? '#fff' : '#ff6fae'; c.beginPath(); c.arc(m + Math.cos(a) * (m - 3), m + Math.sin(a) * (m - 3), 9, 0, 7); c.fill(); }
}
async function wheelGame(p, ctx) { // returns prize
  const human = p.human && !AUTO; const idx = wheelPrize(), pz = PRIZES[idx];
  if (human) {
    const sh = mkSheet(`<h2>${ctx === 'daily' ? 'Daily Bonus Wheel' : 'Bonus Wheel!'}</h2><div class="wheelbox"><canvas id="wcv"></canvas><svg class="ptr" viewBox="0 0 30 36"><path d="M15 36L2 8Q15-6 28 8z" fill="#ff4b5c" stroke="#fff" stroke-width="3" stroke-linejoin="round"/></svg><button class="hub" data-spin>SPIN</button></div><p id="wmsg">Tap SPIN!</p><div class="row" id="wrow"></div>`);
    showModal(sh); drawWheel(sh.querySelector('#wcv'));
    await new Promise((res) => { sh.querySelector('[data-spin]').onclick = () => res(); if (AUTO) setTimeout(res, 100); });
    sh.querySelector('[data-spin]').style.pointerEvents = 'none'; sh.querySelector('#wmsg').textContent = 'Good luck…'; unlockAudio(); sfx('whoosh');
    const seg = Math.PI / 4, final = Math.PI * 2 * 5 - idx * seg + (Math.random() - 0.5) * seg * 0.6; const cv = sh.querySelector('#wcv'); let last = -1;
    await T.add(4.2, (u) => { const R = final * u; cv.style.transform = `rotate(${R}rad)`; const s = Math.floor((R + seg / 2) / seg); if (s !== last) { last = s; sfx('click'); } }, (u) => 1 - Math.pow(1 - u, 3.2));
    sfx('win'); world.confetti(world.view.target.clone().setY(2), 60, 1);
    sh.querySelector('#wmsg').innerHTML = `<b style="font-size:1.6rem">${pz.k === 'cash' ? 'You won ' + money(pz.v) + '!' : pz.k === 'sticker' ? 'A sticker!' : 'A free upgrade!'}</b>`;
    sh.querySelector('#wrow').innerHTML = '<button class="btn gold" data-v="ok" data-def>Collect!</button>'; modalEl.onclick = null;
    await new Promise((res) => { sh.addEventListener('click', (e) => { if (e.target.closest('[data-v]')) { sfx('click'); res(); } }); if (AUTO) setTimeout(res, 150); }); closeModal();
  } else { banner(`${p.name} spins the wheel!`, '#a56cf0', p.av); await T.wait(1.6); }
  return pz;
}
async function applyPrize(p, pz, ctx) {
  if (ctx === 'daily') return;
  if (pz.k === 'cash') gain(p, pz.v);
  else if (pz.k === 'sticker') await giveSticker(p);
  else { const t = bestUpgrade(p, 99999); if (t) { await doUpgrade(p, t.i, true); banner('Free upgrade!', '#ff9a3c'); } else gain(p, 200); }
  await T.wait(0.4);
}
async function digGame(p) {
  const human = p.human && !AUTO;
  const loot = [...Array(5).fill({ t: 'coin', v: 40 }), ...Array(2).fill({ t: 'chest', v: 120 }), { t: 'gem', v: 250 }, { t: 'star', v: 0, st: 1 }, ...Array(3).fill({ t: 'worm', v: 0 })]; loot.sort(() => Math.random() - 0.5);
  let total = 0, found = 0, sticker = false;
  if (human) {
    let left = 3;
    const sh = mkSheet(`<h2>Treasure Dig!</h2><p>Tap the mounds to dig. You have 3 shovels!</p><div class="shov" id="shov">${IC.shovel.repeat(3)}</div><div class="dig" id="dig">${loot.map((_, i) => `<button class="mound" data-i="${i}" aria-label="Dig"></button>`).join('')}</div><p id="dmsg">&nbsp;</p><div class="row" id="drow"></div>`);
    showModal(sh); modalEl.onclick = null; const reveal = (m, it, dim) => { m.classList.add('open'); if (dim) m.classList.add('dim'); m.innerHTML = `<canvas data-g="${it.t === 'star' ? 'star' : it.t}"></canvas>${it.v && !dim ? `<span class="amt">+${it.v}</span>` : ''}`; hydrate(m); };
    await new Promise((res) => {
      sh.querySelector('#dig').addEventListener('click', (e) => {
        const m = e.target.closest('.mound'); if (!m || m.classList.contains('open') || left <= 0) return; left--; sh.querySelectorAll('#shov svg')[left].classList.add('u'); const it = loot[+m.dataset.i]; reveal(m, it);
        if (it.t === 'worm') { sfx('squeak'); sh.querySelector('#dmsg').textContent = 'A wiggly worm says hi!'; } else { sfx(it.t === 'gem' ? 'sparkle' : 'coin'); found++; total += it.v; if (it.st) sticker = true; sh.querySelector('#dmsg').innerHTML = it.st ? 'A sticker!' : `<b>+${it.v}</b> coins!`; }
        if (left === 0) setTimeout(() => { sh.querySelectorAll('.mound:not(.open)').forEach((mm) => reveal(mm, loot[+mm.dataset.i], true)); sh.querySelector('#dmsg').innerHTML = `<b style="font-size:1.4rem">Total ${money(total)}${sticker ? ' + sticker' : ''}</b>`; sh.querySelector('#drow').innerHTML = '<button class="btn gold" data-v="ok" data-def>Collect!</button>'; sh.querySelector('#drow button').onclick = () => { sfx('click'); res(); }; if (AUTO) setTimeout(res, 100); }, 700);
      });
      if (AUTO) { let k = 0; const iv = setInterval(() => { const ms = sh.querySelectorAll('.mound:not(.open)'); if (!ms.length || k++ > 4) { clearInterval(iv); return; } ms[0].click(); }, 120); }
    });
    closeModal();
  } else {
    banner(`${p.name} digs for treasure!`, '#c98a3c', p.av); await T.wait(1.3); for (let k = 0; k < 3; k++) { const it = loot[k]; if (it.t !== 'worm') { total += it.v; found++; if (it.st) sticker = true; } }
  }
  if (total) gain(p, total); if (p.human) bump('dig', found); if (sticker) await giveSticker(p); await T.wait(0.3);
}

// ---------- turn flow ----------
let rollResolve = null;
function waitRoll() {
  hint('roll', 'Tap ROLL, or flick the screen!', 7000);
  return new Promise((res) => { rollResolve = res; rollBtn.classList.remove('off'); rollBtn.classList.add('ready'); if (AUTO) setTimeout(() => doRoll(1), 250); });
}
function doRoll(str = 1) { if (!rollResolve) return false; const r = rollResolve; rollResolve = null; rollBtn.classList.add('off'); rollBtn.classList.remove('ready'); hideHint(); unlockAudio(); r(str); return true; }

async function moveSteps(p, n, quick = false) {
  const dir = n >= 0 ? 1 : -1; for (let k = 0; k < Math.abs(n); k++) {
    const from = p.pos, to = (p.pos + dir + 40) % 40; world.view.tYaw = yawForTile(to); sfx('step'); await world.hop(p.token, from, to, quick ? 0.16 : 0.27, quick ? 0.55 : 0.9); p.pos = to;
    if (dir > 0 && to === 0) await passStart(p);
  }
}
async function moveTo(p, tile, quick = true) { const n = (tile - p.pos + 40) % 40; await moveSteps(p, n, quick); }
async function passStart(p) { p.lap++; world.flashTile(0, 0xffd93b); world.confetti(world.tiles[0].pos.clone().setY(2.5), 40, 0.7); banner('Passed START! +$200', '#4fc96a', p.av); gain(p, 200); sfx('win'); setIntensity(0.8); G.laps = Math.max(G.laps, p.lap); await T.wait(0.9); }

async function sendToNap(p) {
  banner(`${p.human ? 'You are' : p.name + ' is'} sleepy! Off to the Nap Corner`, '#8a96ff', p.av); await T.wait(0.7);
  const a = p.token.g.position.clone(); const b = world.lane(10, p.slot, new THREE.Vector3()); world.view.tYaw = yawForTile(10); sfx('whoosh'); p.token.hopping = true;
  await T.add(0.9, (u) => { p.token.g.position.lerpVectors(a, b, u); p.token.g.position.y += Math.sin(u * Math.PI) * 5; }); p.token.hopping = false; p.token.tile = 10; p.pos = 10; p.nap = 1; sfx('boing'); world.puff(b, 6); await T.wait(0.5);
}

async function landOn(p, depth = 0) {
  const i = p.pos, d = TILES[i], t = G.tiles[i]; world.flashTile(i, p.color); await T.wait(0.15);
  switch (d.type) {
    case 'prop': case 'station': case 'util': {
      if (t.owner === -1) { if (await offerBuy(p, i)) await doBuy(p, i); else if (!p.human) await T.wait(0.2); else await T.wait(0.1); if (!p.human && t.owner === p.id) { banner(`${p.name} bought ${d.name}!`, p.css); await T.wait(0.6); } }
      else if (t.owner === p.id) {
        if (d.type === 'prop' && t.level < 3) {
          const c = upgradeCost(d, t.level + 1);
          if (p.human && !AUTO) { const can = p.cash >= c; const sh = mkSheet(`<h2>Welcome home!</h2><p>Upgrade <b>${d.name}</b> to a ${levelName[t.level + 1]}? Rent grows to ${money(d.price * rentFactor[t.level + 1])}!</p><div class="row"><button class="btn gray" data-v="no">Not now</button><button class="btn" data-v="yes" data-def ${can ? '' : 'disabled'}>${can ? 'Upgrade ' + money(c) : 'Need ' + money(c - p.cash)}</button></div>`); if ((await ask(sh)) === 'yes') await doUpgrade(p, i); }
          else if (p.cash - c > 250 && Math.random() < 0.8) { await doUpgrade(p, i); banner(`${p.name} built a ${levelName[t.level]}!`, p.css); await T.wait(0.5); }
        } else { banner('Home sweet home!', '#4fc96a'); await T.wait(0.5); }
      } else {
        const o = G.players[t.owner]; const r = rentFor(i, G.lastRoll); banner(`${p.human ? 'You pay' : p.name + ' pays'} ${money(r)} rent`, '#ff7a5a', o.av); await T.wait(0.6); await payTo(p, r, o);
      }
      break;
    }
    case 'surprise': await drawCard(p, depth); break;
    case 'dig': banner('Treasure Dig!', '#c98a3c', p.av); await T.wait(0.6); await digGame(p); break;
    case 'tax': banner(`${d.name}: pay ${money(d.fee)}`, '#ff7a8a', p.av); await T.wait(0.7); await payTo(p, d.fee, null); break;
    case 'park': { const pot = G.pot; banner(pot ? `Picnic Park! Pot ${money(pot)}` : 'Picnic Park!', '#8ddc78', p.av); await T.wait(0.8); if (pot) { G.pot = 0; gain(p, pot); await T.wait(0.6); } const pz = await wheelGame(p, 'game'); await applyPrize(p, pz, 'game'); break; }
    case 'gonap': await sendToNap(p); break;
    case 'nap': banner('Just visiting the Nap Corner', '#8a96ff'); await T.wait(0.6); break;
    case 'start': banner('Landed on START! +$100 bonus', '#4fc96a', p.av); gain(p, 100); world.confetti(world.tiles[0].pos.clone().setY(2.5), 40, 0.7); await T.wait(0.8); break;
  }
}
async function drawCard(p, depth) {
  const c = pick(CARDS); sfx('powerup');
  const html = `<div class="cardflip sheet"><div class="gi"><canvas data-g="${c.glyph}"></canvas></div><h2>Surprise!</h2><p>${c.text}</p>${p.human && !AUTO ? '<div class="row"><button class="btn" data-v="ok" data-def>OK!</button></div>' : `<p><b>${p.name}</b> drew this card</p>`}</div>`;
  const wrap = document.createElement('div'); wrap.innerHTML = html; const sh = wrap.firstChild; hydrate(sh);
  if (p.human && !AUTO) await ask(sh); else { showModal(sh); modalEl.onclick = null; await T.wait(2.0); closeModal(); }
  if (c.cash > 0) { gain(p, c.cash); await T.wait(0.6); } else if (c.cash < 0) { await payTo(p, -c.cash, null); }
  else if (c.each) { for (const o of G.players) if (o !== p) await payTo(o, c.each, p); }
  else if (c.give) { for (const o of G.players) if (o !== p) await payTo(p, c.give, o); }
  else if (c.goto !== undefined) { await moveTo(p, c.goto, true); }
  else if (c.move) { await moveSteps(p, c.move, true); if (depth < 2) await landOn(p, depth + 1); }
  else if (c.station) { const st = [5, 15, 25, 35].find((s) => s > p.pos) ?? 5; await moveTo(p, st, true); if (depth < 2) await landOn(p, depth + 1); }
  else if (c.freeUp) { const t = bestUpgrade(p, 99999); if (t) { await doUpgrade(p, t.i, true); banner('Free upgrade!', '#ff9a3c'); await T.wait(0.5); } else { gain(p, 100); await T.wait(0.5); } }
  else if (c.sticker) { await giveSticker(p, 1); }
  else if (c.dig) { await digGame(p); }
  else if (c.wheel) { const pz = await wheelGame(p, 'game'); await applyPrize(p, pz, 'game'); }
}

async function takeTurn(p) {
  setCurrent(p); setIntensity(0.5); await T.wait(0.35); updateTownBadge();
  if (p.nap > 0) { p.nap--; banner(`${p.human ? 'You are' : p.name + ' is'} napping… Zzz`, '#8a96ff', p.av); sfx('squeak'); await T.wait(1.4); return; }
  banner(p.human ? 'Your turn!' : `${p.name}'s turn`, p.css, p.av); await T.wait(0.8);
  let doubles = 0;
  for (;;) {
    if (!G || G.over) return;
    if (p.human && !AUTO) {
      if (G.tiles.some((t) => t.owner === 0 && t.type === 'prop' && t.level < 3)) hint('town', 'Tap My Town to upgrade your buildings and earn more rent!', 6000);
      await waitRoll(); await T.wait(0.1);
    } else {
      if (!p.human || AUTO) { const up = bestUpgrade(p, p.cash - 300); if (up && Math.random() < 0.6 && doubles === 0) { world.view.follow = (out) => out.copy(world.tiles[up.i].pos); banner(`${p.name} builds!`, p.css, p.av); await T.wait(0.5); await doUpgrade(p, up.i); await T.wait(0.3); setCurrent(p); } }
      await T.wait(0.4);
    }
    const f = window.__tt?.force; let a = 1 + Math.floor(Math.random() * 6), b = 1 + Math.floor(Math.random() * 6); if (f) { [a, b] = f; window.__tt.force = null; }
    G.lastRoll = a + b; setIntensity(0.85); sfx('dice'); world.view.tYaw = yawForTile(p.pos);
    await world.rollDice([a, b], p.pos, rnd(0.9, 1.2)); sfx('boing');
    const ds = $('#dicesum'); ds.textContent = a + b; ds.classList.remove('show'); void ds.offsetWidth; ds.classList.add('show'); sfx('pop');
    await T.wait(0.55); await world.hideDice();
    await moveSteps(p, a + b); await landOn(p); updateTownBadge();
    for (const q of G.players) if (netWorth(q) >= G.goal) { await endGame(q); return; }
    if (a === b && p.nap === 0) { doubles++; if (doubles >= 3) { await sendToNap(p); return; } banner('Doubles! Roll again!', '#ffb21c', p.av); sfx('powerup'); await T.wait(0.9); continue; }
    break;
  }
}
async function gameLoop(run) {
  while (G && !G.over && G.run === run) {
    const p = G.players[G.turn]; await takeTurn(p); if (!G || G.run !== run || G.over) return;
    G.turn = (G.turn + 1) % G.players.length;
    if (G.turn === 0) { G.round++; updateGoalbar(); if (G.round > G.maxRounds) { await endGame(null); return; } if (G.round === G.maxRounds) banner('Final round!', '#ff6fae'); }
    updateGoalbar();
  }
}

// ---------- end ----------
async function endGame(winner) {
  if (!G || G.over) return; G.over = true; rollBtn.classList.add('off'); townBtn.classList.add('off'); hideHint();
  const ranks = [...G.players].sort((a, b) => netWorth(b) - netWorth(a)); const w = winner || ranks[0]; const youWon = w.human; const place = ranks.indexOf(G.players[0]) + 1;
  world.view.follow = (out) => out.copy(w.token.g.position); setCurrent(w);
  const prog = store.get('stats', { games: 0, wins: 0, best: 0 }); prog.games++; if (youWon) prog.wins++; prog.best = Math.max(prog.best, netWorth(G.players[0])); store.set('stats', prog);
  if (youWon) bump('win', 1);
  try { music.play(youWon ? THEMES.victory : { ...THEMES.calm, bpm: 92 }); setIntensity(youWon ? 1 : 0.6); } catch (e) {} sfx(youWon ? 'win' : 'lose');
  banner(youWon ? 'You win!' : `${w.name} wins!`, youWon ? '#4fc96a' : '#a56cf0', w.av);
  if (youWon) { for (let k = 0; k < 6; k++) { world.confetti(w.token.g.position.clone().setY(2), 60, 1.2); await T.wait(0.3); } } else await T.wait(1.2);
  let stk = ''; if (youWon || place === 2) { const id = rollStickerId(youWon ? 0.7 : 0); addSticker(id); stk = `<div class="row" style="align-items:center;margin-top:.3rem"><div style="width:5rem;height:5rem"><canvas data-s="${id}" style="width:100%;height:100%"></canvas></div><b>New sticker: ${STICKERS.find((s) => s.id === id).name}!</b></div>`; }
  const stars = [0, 1, 2].map((k) => (k < (place === 1 ? 3 : place === 2 ? 2 : 1) ? IC.star : IC.starE)).join('');
  const rows = ranks.map((q, k) => `<div class="sr ${q === w ? 'w' : ''}"><b>${k + 1}</b><canvas data-f="${q.av.id}"></canvas><div class="nm">${q.human ? 'You' : q.name}<small>${money(q.cash)} cash · ${G.tiles.filter((t) => t.owner === q.id).length} properties</small></div><b>${money(netWorth(q))}</b></div>`).join('');
  const sh = mkSheet(`<h2>${youWon ? 'You are the Tycoon!' : place === 2 ? 'So close!' : 'Good game!'}</h2><div class="stars">${stars}</div><div class="stand">${rows}</div>${stk}<div class="row"><button class="btn gray" data-v="home">Home</button><button class="btn big" data-v="again" data-def>Play again</button></div>`, 'wide');
  const v = await ask(sh); if (v === 'home') location.href = '../'; else { startSetup(true); }
}

// ---------- pause / album / goals / info ----------
async function openPause() {
  if (!G || modalEl.classList.contains('show')) return; T.paused = true; sfx('click');
  const sh = mkSheet(`<h2>Paused</h2><div class="row" style="flex-direction:column;align-items:center"><button class="btn big" data-v="resume" data-def>${IC.play} Resume</button><button class="btn blue" data-v="sound">${muted ? 'Music: Off' : 'Music: On'}</button><div class="row" style="margin:0"><button class="btn pink" data-v="album">Stickers</button><button class="btn gold" data-v="goals">Goals</button></div><div class="row" style="margin:0"><button class="btn gray" data-v="restart">Restart</button><button class="btn gray" data-v="home">Home</button></div></div>`);
  for (;;) {
    const v = await ask(sh); if (v === 'sound') { toggleMute(); sh.querySelector('[data-v=sound]').textContent = muted ? 'Music: Off' : 'Music: On'; showModal(sh); continue; }
    if (v === 'album') { await openAlbum(); showModal(sh); continue; } if (v === 'goals') { await openGoals(); showModal(sh); continue; }
    if (v === 'home') { location.href = '../'; return; } if (v === 'restart') { T.paused = false; startSetup(false, true); return; }
    break;
  }
  T.paused = false;
}
function modalOnly(promise) { return promise; }
async function openAlbum() {
  const s = stickers(); const have = STICKERS.filter((d) => s[d.id]).length;
  const grid = STICKERS.map((d) => `<div class="${s[d.id] ? '' : 'lk'}"><canvas data-s="${d.id}" data-lock="${s[d.id] ? 0 : 1}"></canvas>${s[d.id] > 1 ? `<span class="n">x${s[d.id]}</span>` : ''}${s[d.id] ? d.name : '???'}</div>`).join('');
  await ask(mkSheet(`${xbtn}<h2>Sticker Album</h2><p>${have} of ${STICKERS.length} collected</p><div class="pb"><i style="width:${(have / STICKERS.length) * 100}%"></i></div><div class="stk">${grid}</div><div class="row"><button class="btn" data-v="x">Close</button></div>`, 'wide'), true);
}
async function openGoals() {
  for (;;) {
    const g = progress(); const rows = GOALS.map((d) => { const n = Math.min(d.need, g.p[d.id] || 0), done = n >= d.need, claimed = g.c[d.id]; const st = STICKERS.find((s) => s.id === d.reward);
      return `<div class="goal"><canvas data-s="${d.reward}" data-lock="${claimed ? 0 : 1}"></canvas><div class="t"><b>${d.name}</b><span>${d.desc}</span><div class="pb"><i style="width:${(n / d.need) * 100}%"></i></div></div>${claimed ? '<span class="pill">Claimed</span>' : done ? `<button class="btn gold" data-v="claim-${d.id}">Claim!</button>` : `<span class="pill">${n}/${d.need}</span>`}</div>`; }).join('');
    const v = await ask(mkSheet(`${xbtn}<h2>Goals</h2><p>Finish goals to win rare stickers!</p>${rows}<div class="row"><button class="btn" data-v="x">Close</button></div>`, 'wide'), true);
    if (v.startsWith('claim-')) { const id = v.slice(6), d = GOALS.find((x) => x.id === id); g.c[id] = 1; store.set('goals', g); const isNew = addSticker(d.reward); sfx('win'); const st = STICKERS.find((s) => s.id === d.reward); await ask(mkSheet(`<h2>Goal complete!</h2><div class="stkbig"><canvas data-s="${d.reward}"></canvas></div><p><b>${st.name}</b> ${isNew ? '<span class="new">NEW!</span>' : ''}</p><div class="row"><button class="btn" data-v="ok" data-def>Yay!</button></div>`)); continue; }
    return;
  }
}
async function tapInfo(i) {
  if (!G || modalEl.classList.contains('show') || !TILES[i].price) return; sfx('click');
  await ask(mkSheet(`${xbtn}` + propCardHTML(i, { price: true, extra: '<div class="row"><button class="btn blue" data-v="x">Close</button></div>' }), 'pcard'), true);
}

// ---------- title / setup ----------
function showTitle() {
  hud.classList.add('hidden'); const t = $('#title'); t.classList.remove('hidden'); world.setMode('orbit'); world.view.zoomOut = false; world.tokens.forEach((o) => world.scene.remove(o.g)); world.tokens.length = 0;
  AVATARS.forEach((a, k) => { const o = world.addToken(a, k); world.placeToken(o, (38 + k) % 40); o.mark.visible = false; });
  const dailyReady = store.get('daily', '') !== new Date().toDateString(); const st = store.get('stats', { wins: 0, best: 0 });
  t.innerHTML = `<div class="logo"><div class="l1">TYCOON</div><div class="l2">TOWN</div><small>BUILD · COLLECT · HAVE FUN</small></div><div id="tmenu"><button class="btn big gold" id="tPlay">${IC.play} PLAY</button><div id="trow"><button class="btn blue" id="tDaily">Daily Spin${dailyReady ? '<i class="dot"></i>' : ''}</button><button class="btn pink" id="tAlbum">Stickers</button><button class="btn" id="tGoals">Goals</button></div></div><div style="position:absolute;bottom:calc(var(--sab) + .8rem);left:0;right:0;text-align:center;color:#fff;text-shadow:0 .1rem 0 rgba(43,47,90,.7);font-size:.95rem">${st.wins ? 'Wins: ' + st.wins + ' · ' : ''}Best fortune: ${money(st.best || 0)}</div><button class="rb" id="tSnd" style="position:absolute;right:calc(var(--sar) + 1rem);top:calc(var(--sat) + 1rem)">${muted ? IC.sndOff : IC.sndOn}</button><a href="../" class="rb" style="position:absolute;left:calc(var(--sal) + 1rem);top:calc(var(--sat) + 1rem);text-decoration:none" aria-label="Home"><svg viewBox="0 0 24 24" fill="#2b2f5a"><path d="M3 12L12 4l9 8h-2.5v8h-4.5v-5h-4v5H5.5v-8z" stroke="#2b2f5a" stroke-width="1.5" stroke-linejoin="round"/></svg></a>`;
  $('#tPlay').onclick = () => { unlockAudio(); sfx('click'); startSetup(); };
  $('#tAlbum').onclick = () => { unlockAudio(); openAlbum(); }; $('#tGoals').onclick = () => { unlockAudio(); openGoals(); };
  $('#tSnd').onclick = () => { unlockAudio(); toggleMute(); $('#tSnd').innerHTML = muted ? IC.sndOff : IC.sndOn; };
  $('#tDaily').onclick = async () => { unlockAudio(); if (store.get('daily', '') === new Date().toDateString()) { await ask(mkSheet(`${xbtn}<h2>Come back tomorrow!</h2><p>You already spun today. A fresh Daily Spin arrives every day.</p><div class="row"><button class="btn" data-v="ok" data-def>OK</button></div>`), true); return; }
    const pz = await wheelGame({ human: true, name: 'You', av: AVATARS[0] }, 'daily'); store.set('daily', new Date().toDateString());
    let msg = ''; if (pz.k === 'sticker') { const id = rollStickerId(1); addSticker(id); const d = STICKERS.find((s) => s.id === id); await ask(mkSheet(`<h2>Sticker!</h2><div class="stkbig"><canvas data-s="${id}"></canvas></div><p><b>${d.name}</b></p><div class="row"><button class="btn" data-v="ok" data-def>Yay!</button></div>`)); }
    else { const v = pz.k === 'cash' ? pz.v : 200; store.set('bonus', (store.get('bonus', 0) || 0) + v); await ask(mkSheet(`<h2>Bonus saved!</h2><p>You'll start your next game with <b>+${money(v)}</b> extra cash.</p><div class="row"><button class="btn" data-v="ok" data-def>Great!</button></div>`)); }
    showTitle(); };
  if (AUTO) setTimeout(() => $('#tPlay').click(), 300);
}
let setupCfg = store.get('setup', { av: 'fox', rivals: 2, mode: 1 });
async function startSetup(again = false, restart = false) {
  if (G) { G.over = true; } closeModal(); T.paused = false; T.list.length = 0; rollResolve = null; $('#title').classList.add('hidden');
  if (again && qs.has('auto')) { return launch(setupCfg); }
  const body = () => `<h2>Pick your buddy</h2><div class="avs">${AVATARS.map((a) => `<button class="av ${setupCfg.av === a.id ? 'sel' : ''}" data-av="${a.id}" style="--c:${a.css}"><canvas data-f="${a.id}"></canvas>${a.name}</button>`).join('')}</div><div class="lbl">Friendly rivals</div><div class="seg" id="sgR">${[1, 2, 3].map((n) => `<button data-r="${n}" class="${setupCfg.rivals === n ? 'sel' : ''}">${n}</button>`).join('')}</div><div class="lbl">Game length</div><div class="seg" id="sgM"><button data-m="0" class="${setupCfg.mode === 0 ? 'sel' : ''}">Quick</button><button data-m="1" class="${setupCfg.mode === 1 ? 'sel' : ''}">Normal</button></div><div class="row"><button class="btn gray" data-v="back">Back</button><button class="btn big" data-v="go" data-def>${IC.play} Let's go!</button></div>`;
  const sh = mkSheet(body(), 'wide'); showModal(sh);
  sh.addEventListener('click', (e) => {
    const a = e.target.closest('[data-av]'), r = e.target.closest('[data-r]'), m = e.target.closest('[data-m]');
    if (a || r || m) { if (a) setupCfg.av = a.dataset.av; if (r) setupCfg.rivals = +r.dataset.r; if (m) setupCfg.mode = +m.dataset.m; sfx('click'); sh.innerHTML = body(); hydrate(sh); }
  });
  const v = await new Promise((res) => { sh.addEventListener('click', (e) => { const b = e.target.closest('[data-v]'); if (b) res(b.dataset.v); }); if (AUTO) setTimeout(() => res('go'), 200); });
  closeModal(); store.set('setup', setupCfg); if (v === 'back') { showTitle(); return; } launch(setupCfg);
}

function launch(cfg) {
  unlockAudio(); try { music.play(BOARD); setIntensity(0.5); } catch (e) {}
  for (const t of world.tiles) if (t.d.price) { world.setOwner(t.i, -1); world.setLevel(t.i, 0, false); }
  world.tokens.forEach((o) => world.scene.remove(o.g)); world.tokens.length = 0; T.list.length = 0; T.paused = false; T.speed = parseFloat(qs.get('speed')) || 1;
  const me = AVATARS.find((a) => a.id === cfg.av) || AVATARS[0]; const others = AVATARS.filter((a) => a !== me).slice(0, cfg.rivals); const list = [me, ...others];
  const bonus = store.get('bonus', 0) || 0; store.set('bonus', 0);
  G = { run: (G ? G.run : 0) + 1, over: false, turn: 0, round: 1, maxRounds: cfg.mode === 0 ? 8 : 14, goal: cfg.mode === 0 ? 2800 : 3600, pot: 0, lastRoll: 7, laps: 0, speed: 0,
    tiles: TILES.map((d) => ({ i: d.i, type: d.type, set: d.set, name: d.name, price: d.price || 0, owner: -1, level: 0, invest: 0 })),
    players: list.map((a, k) => ({ id: k, av: a, name: a.name, human: k === 0, color: a.color, css: a.css, cash: 1500 + (k === 0 ? bonus : 0), shown: 1500 + (k === 0 ? bonus : 0), pos: 0, lap: 0, nap: 0, slot: k, token: null })) };
  G.players.forEach((p) => { p.token = world.addToken(p.av, p.slot); p.token.mark.visible = false; });
  buildPlayers(); buildTopButtons(); updateGoalbar(); hud.classList.remove('hidden'); G.players.forEach((p) => { p.cashEl.textContent = money(p.cash); });
  world.setMode('follow'); world.view.zoomOut = true; world.view.tYaw = yawForTile(0); setCurrent(G.players[0]); G.players.forEach((q) => (q.el.classList.remove('cur')));
  window.__tt.G = G;
  const run = G.run; (async () => { banner(bonus ? `Let's play! +${money(bonus)} daily bonus` : "Let's play!", '#4fb4f0', me); await T.wait(1.3); banner(`First to ${money(G.goal)} wins!`, '#ff9a3c'); world.view.zoomOut = false; await T.wait(1.4); if (G.run === run) gameLoop(run); })();
}

// ---------- input ----------
let ptr = null;
const cv = $('#c');
cv.addEventListener('pointerdown', (e) => { ptr = { x: e.clientX, y: e.clientY, t: performance.now() }; unlockAudio(); });
cv.addEventListener('pointerup', (e) => {
  if (!ptr) return; const dx = e.clientX - ptr.x, dy = e.clientY - ptr.y, dt = performance.now() - ptr.t, dist = Math.hypot(dx, dy); ptr = null;
  if (!G || modalEl.classList.contains('show')) return;
  if (rollResolve && dist > 80 && dt < 1600) { doRoll(Math.min(1.4, 0.8 + dist / 500)); return; }
  if (dist < 14 && dt < 500) { const i = world.pick(e.clientX, e.clientY); if (i >= 0) tapInfo(i); }
});
rollBtn.addEventListener('click', () => doRoll(1));
townBtn.addEventListener('click', async () => { if (!G || G.over || townBtn.classList.contains('off') || modalEl.classList.contains('show')) return; unlockAudio(); await openTown(G.players[0]); updateTownBadge(); });
window.addEventListener('keydown', (e) => {
  if (e.code === 'Space' || e.code === 'Enter') { e.preventDefault(); if (modalEl.classList.contains('show')) { const b = modalEl.querySelector('[data-def]'); if (b && !b.disabled) b.click(); } else if (!doRoll(1) && !G) $('#tPlay')?.click(); }
  else if (e.code === 'Escape') { if (modalEl.classList.contains('show')) modalEl.querySelector('.xbtn')?.click(); else openPause(); }
});
document.addEventListener('contextmenu', (e) => e.preventDefault()); document.addEventListener('gesturestart', (e) => e.preventDefault());
document.addEventListener('dblclick', (e) => e.preventDefault());
document.addEventListener('touchmove', (e) => { if (!e.target.closest('.sheet')) e.preventDefault(); }, { passive: false });
document.addEventListener('visibilitychange', () => { if (document.hidden && G && !G.over && !T.paused && !modalEl.classList.contains('show')) openPause(); });

// ---------- loop ----------
window.__tt = { noRender: qs.has('norender'), world, T, get G() { return G; }, set G(v) {}, force: null, doUpgrade: (p, i, f) => doUpgrade(G.players[p], i, f), buy: (p, i) => doBuy(G.players[p], i), giveSticker: (p) => giveSticker(G.players[p]), wheel: (p) => wheelGame(G.players[p], 'game'), openPause, openAlbum, openGoals, tapInfo, netWorth, music, endGame: (w) => endGame(w ? G.players[w] : null), gain: (i, n) => gain(G.players[i], n) };
let last = performance.now(), ema = 0.016, slow = 0; const adapt = !qs.has('noadapt') && !qs.has('lite');
function frame(now) {
  const dt = Math.min(0.1, (now - last) / 1000); last = now;
  if (adapt) { ema += (dt - ema) * 0.05; if (ema > 0.027 && !document.hidden && !T.paused) { if (++slow > 120 && (world.quality || 0) < 3) { world.setQuality((world.quality || 0) + 1); slow = 0; ema = 0.016; } } else slow = Math.max(0, slow - 2); }
  try { world.update(dt); if (G && G.over && G.players) { const w = G.players.reduce((a, b) => (netWorth(b) > netWorth(a) ? b : a)); if (netWorth(w) >= 0 && G.players[0] === w && Math.random() < 0.15) world.rain(world.view.target); } tickHud(dt); if (!window.__tt.noRender) world.render(); } catch (e) { console.error('frame error', e); }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
showTitle();
