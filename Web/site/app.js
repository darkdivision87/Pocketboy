import { loadEngine } from './engine.js';

const $ = (sel) => document.querySelector(sel);
const TINTS = ['Classic Green', 'Pocket Gray', 'Backlit Teal', 'Amber'];
const SHELLS = {
  classic: { name: 'Dust Gray', c1: '#ccc8be', c2: '#a9a59b', accent: '#9e1f5c', print: '#3a3a8c' },
  grape: { name: 'Grape', c1: '#6c45a8', c2: '#4e2f82', accent: '#f0d84a', print: 'rgba(255,255,255,.85)' },
  banana: { name: 'Banana', c1: '#ebcb2e', c2: '#c4a41a', accent: '#2a64a8', print: '#3a3a8c' },
  teal: { name: 'Lagoon', c1: '#2ba59c', c2: '#1d7f78', accent: '#e04a8c', print: 'rgba(255,255,255,.85)' },
  cherry: { name: 'Cherry', c1: '#c8283a', c2: '#9c1a2a', accent: '#f4efe2', print: 'rgba(255,255,255,.85)' },
  midnight: { name: 'Midnight', c1: '#2b2e3c', c2: '#1a1c27', accent: '#5cc8c8', print: 'rgba(255,255,255,.85)' },
};

function load(key, fallback) {
  try { const v = localStorage.getItem(key); return v ? { ...fallback, ...JSON.parse(v) } : fallback; } catch (e) { return fallback; }
}
function save(key, value) { try { localStorage.setItem(key, JSON.stringify(value)); } catch (e) { /* private mode */ } }

const settings = load('pb.settings', { color: 1, tint: 0, grid: true, sound: true, shell: 'classic' });
const high = load('pb.high', {});
let engine = null;
let carts = [];
let filter = 'ALL';
let current = null;
let menuOpen = false;
let highDirty = 0;

// ---------- input ----------
const held = { dpad: 0, buttons: 0, keys: 0, pad: 0 };
let latch = 0;
function setHeld(group, value) {
  const before = held.dpad | held.buttons | held.keys | held.pad;
  held[group] = value;
  const after = held.dpad | held.buttons | held.keys | held.pad;
  latch |= after & ~before;
}
const currentButtons = () => held.dpad | held.buttons | held.keys | held.pad;

function bindControls() {
  const dpad = $('#dpad');
  const pointers = new Map();
  const updateDpad = (e) => {
    const r = dpad.getBoundingClientRect();
    const dx = e.clientX - (r.left + r.width / 2);
    const dy = e.clientY - (r.top + r.height / 2);
    const ax = Math.abs(dx), ay = Math.abs(dy);
    const dead = r.width * 0.1;
    let bits = 0;
    if (ax > dead || ay > dead) {
      if (ax > ay * 0.45) bits |= dx > 0 ? 8 : 4;
      if (ay > ax * 0.45) bits |= dy > 0 ? 2 : 1;
    }
    setHeld('dpad', bits);
    dpad.querySelectorAll('i').forEach((el) => {
      const bit = { u: 1, d: 2, l: 4, r: 8 }[el.className.split(' ')[0]];
      el.classList.toggle('on', (bits & bit) !== 0);
    });
  };
  dpad.addEventListener('pointerdown', (e) => { dpad.setPointerCapture(e.pointerId); pointers.set(e.pointerId, 1); updateDpad(e); e.preventDefault(); });
  dpad.addEventListener('pointermove', (e) => { if (pointers.has(e.pointerId)) updateDpad(e); });
  const endDpad = (e) => { pointers.delete(e.pointerId); setHeld('dpad', 0); dpad.querySelectorAll('i').forEach((el) => el.classList.remove('on')); };
  dpad.addEventListener('pointerup', endDpad);
  dpad.addEventListener('pointercancel', endDpad);

  const active = new Map(); // pointerId -> bit
  document.querySelectorAll('[data-btn]').forEach((el) => {
    const bit = Number(el.dataset.btn);
    el.addEventListener('pointerdown', (e) => {
      el.setPointerCapture(e.pointerId);
      active.set(e.pointerId, bit);
      el.classList.add('down');
      let bits = 0; active.forEach((b) => { bits |= b; });
      setHeld('buttons', bits);
      e.preventDefault();
    });
    const up = (e) => {
      active.delete(e.pointerId);
      el.classList.remove('down');
      let bits = 0; active.forEach((b) => { bits |= b; });
      setHeld('buttons', bits);
    };
    el.addEventListener('pointerup', up);
    el.addEventListener('pointercancel', up);
  });

  const keyMap = { ArrowUp: 1, ArrowDown: 2, ArrowLeft: 4, ArrowRight: 8, w: 1, s: 2, a: 4, d: 8, x: 16, z: 32, ' ': 16, Enter: 64, Shift: 128 };
  let keyBits = 0;
  window.addEventListener('keydown', (e) => { const b = keyMap[e.key]; if (b) { keyBits |= b; setHeld('keys', keyBits); e.preventDefault(); } if (e.key === 'Escape' && current) toggleMenu(true); });
  window.addEventListener('keyup', (e) => { const b = keyMap[e.key]; if (b) { keyBits &= ~b; setHeld('keys', keyBits); } });
  window.addEventListener('blur', () => { keyBits = 0; setHeld('keys', 0); });

  // Hardware controllers (Bluetooth pads work on iOS Safari).
  window.addEventListener('gamepadconnected', () => {});
}

function pollGamepad() {
  const pads = navigator.getGamepads ? navigator.getGamepads() : [];
  let bits = 0;
  for (const p of pads) {
    if (!p) continue;
    const b = p.buttons;
    const on = (i) => b[i] && b[i].pressed;
    if (on(12) || p.axes[1] < -0.5) bits |= 1;
    if (on(13) || p.axes[1] > 0.5) bits |= 2;
    if (on(14) || p.axes[0] < -0.5) bits |= 4;
    if (on(15) || p.axes[0] > 0.5) bits |= 8;
    if (on(1) || on(3)) bits |= 16;
    if (on(0) || on(2)) bits |= 32;
    if (on(9)) bits |= 64;
    if (on(8)) bits |= 128;
  }
  if (bits !== held.pad) setHeld('pad', bits);
}

// ---------- audio ----------
let audioCtx = null;
function ensureAudio() {
  if (audioCtx) { if (audioCtx.state === 'suspended') audioCtx.resume(); return; }
  const Ctx = window.AudioContext || window.webkitAudioContext;
  if (!Ctx) return;
  try {
    audioCtx = new Ctx();
    engine.ex.pb_set_rate(Math.round(audioCtx.sampleRate));
    engine.ex.pb_set_muted(settings.sound && !menuOpen ? 0 : 1);
    const node = audioCtx.createScriptProcessor(2048, 0, 1);
    node.onaudioprocess = (e) => {
      const out = e.outputBuffer.getChannelData(0);
      out.set(engine.audio(out.length));
    };
    node.connect(audioCtx.destination);
    audioCtx.resume();
  } catch (err) { audioCtx = null; }
}
function applyMute() { if (engine) engine.ex.pb_set_muted(settings.sound && !menuOpen && current ? 0 : 1); }

// ---------- UI ----------
function applySettings() {
  const s = SHELLS[settings.shell] || SHELLS.classic;
  const root = document.documentElement.style;
  root.setProperty('--shell1', s.c1); root.setProperty('--shell2', s.c2);
  root.setProperty('--accent', s.accent); root.setProperty('--print', s.print);
  $('#lcdgrid').classList.toggle('on', !!settings.grid);
  if (engine) engine.ex.pb_set_mode(settings.color ? 1 : 0, settings.tint);
  applyMute();
  save('pb.settings', settings);
  document.querySelectorAll('#segColor button').forEach((b) => b.classList.toggle('on', Number(b.dataset.v) === Number(settings.color)));
  document.querySelectorAll('#segTint button').forEach((b) => b.classList.toggle('on', Number(b.dataset.v) === settings.tint));
  $('#tintRow').hidden = !!settings.color;
  $('#optGrid').checked = !!settings.grid;
  $('#optSound').checked = !!settings.sound;
  document.querySelectorAll('#swatches i').forEach((el) => el.classList.toggle('on', el.dataset.k === settings.shell));
}

function cartHtml(c, large) {
  const best = high[c.id] ? String(high[c.id]) : '---';
  return `<div class="cart ${large ? 'large' : ''}"><div class="meta"><span class="era">${c.era}</span><span>${c.genre.toUpperCase()}</span></div>` +
    `<div class="label" style="background:linear-gradient(${c.top},${c.bottom})"><span class="t">${c.title}</span></div>` +
    `<div class="best">BEST ${best}</div></div>`;
}

function renderShelf() {
  const list = carts.filter((c) => filter === 'ALL' || c.era === filter);
  const grid = $('#grid');
  grid.innerHTML = '';
  list.forEach((c) => {
    const wrap = document.createElement('div');
    wrap.innerHTML = cartHtml(c, false);
    const el = wrap.firstChild;
    el.setAttribute('role', 'button');
    el.addEventListener('click', () => openDetail(c));
    grid.appendChild(el);
  });
  $('#count').textContent = carts.length + ' CARTRIDGES';
}

let detailCart = null;
function openDetail(c) {
  detailCart = c;
  $('#detailCart').innerHTML = cartHtml(c, true);
  const names = { GB: 'Game Boy', GBC: 'Game Boy Color', NES: 'Pocket NES', '64': 'Pocket 64' };
  $('#detailEra').textContent = names[c.era] || c.era;
  $('#detailBlurb').textContent = c.blurb;
  $('#detailControls').textContent = c.controls;
  $('#detail').hidden = false;
}

function toggleMenu(open) {
  menuOpen = open;
  $('#menu').hidden = !open;
  if (open) { $('#menuTitle').textContent = current ? current.title : ''; $('#menuBest').textContent = current ? 'BEST ' + (high[current.id] || 0) : ''; }
  applyMute();
}

function play(c) {
  ensureAudio();
  current = c;
  detailCart = null;
  $('#detail').hidden = true;
  $('#shelf').hidden = true;
  $('#console').hidden = false;
  setHeld('dpad', 0); setHeld('buttons', 0);
  latch = 0;
  engine.ex.pb_set_mode(settings.color ? 1 : 0, settings.tint);
  engine.ex.pb_insert(c.index);
  toggleMenu(false);
  applyMute();
  lastRender = -1;
}

function eject() {
  engine.ex.pb_eject();
  saveHigh(true);
  current = null;
  toggleMenu(false);
  $('#console').hidden = true;
  $('#shelf').hidden = false;
  renderShelf();
  applyMute();
}

function saveHigh(force) {
  if (highDirty && (force || ++highDirty > 120)) { save('pb.high', high); highDirty = 0; }
}

// ---------- main loop ----------
const canvas = $('#screen');
const ctx2d = canvas.getContext('2d', { alpha: false });
let lastRender = -1;
let lastTime = 0;

function frame(t) {
  requestAnimationFrame(frame);
  const dt = Math.min(100, lastTime ? t - lastTime : 16.7);
  lastTime = t;
  if (!current || !engine) return;
  pollGamepad();
  if (!menuOpen) {
    engine.ex.pb_tick(dt, currentButtons() | latch);
    latch = 0;
    const s = engine.ex.pb_score();
    if (!engine.ex.pb_booting() && s > (high[current.id] || 0)) { high[current.id] = s; highDirty = highDirty || 1; }
    saveHigh(false);
  }
  const rc = engine.ex.pb_render_count();
  if (rc !== lastRender) {
    lastRender = rc;
    const { w, h, data } = engine.frame();
    if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
    ctx2d.putImageData(new ImageData(data, w, h), 0, 0);
  }
}

// ---------- boot ----------
function showError(err) {
  const el = $('#error');
  el.hidden = false;
  el.textContent = 'Something went wrong: ' + (err && err.message ? err.message : err);
  $('#loading').hidden = true;
}

async function boot() {
  try {
    const resp = await fetch('pocketweb.wasm');
    if (!resp.ok) throw new Error('could not load pocketweb.wasm (' + resp.status + ')');
    engine = await loadEngine(await resp.arrayBuffer());
    engine.ex.pb_init(44100);
    carts = engine.cartridges();
    $('#chips').innerHTML = ['ALL', 'GB', 'GBC', 'NES', '64'].map((f) => `<button data-f="${f}" class="${f === filter ? 'on' : ''}">${f}</button>`).join('');
    $('#chips').addEventListener('click', (e) => {
      const f = e.target.dataset && e.target.dataset.f;
      if (!f) return;
      filter = f;
      document.querySelectorAll('#chips button').forEach((b) => b.classList.toggle('on', b.dataset.f === f));
      renderShelf();
    });
    $('#segTint').innerHTML = TINTS.map((n, i) => `<button data-v="${i}">${n}</button>`).join('');
    $('#swatches').innerHTML = Object.keys(SHELLS).map((k) => `<i data-k="${k}" style="background:${SHELLS[k].c1};--dot:${SHELLS[k].accent}" title="${SHELLS[k].name}"></i>`).join('');
    bindControls();
    bindUi();
    applySettings();
    renderShelf();
    $('#loading').hidden = true;
    $('#shelf').hidden = false;
    requestAnimationFrame(frame);
  } catch (err) { showError(err); }
}

function bindUi() {
  $('#playBtn').addEventListener('click', () => { if (detailCart) play(detailCart); });
  $('#detailClose').addEventListener('click', () => { $('#detail').hidden = true; });
  $('#detail').addEventListener('click', (e) => { if (e.target.id === 'detail') $('#detail').hidden = true; });
  $('#menuBtn').addEventListener('click', () => toggleMenu(true));
  $('#resumeBtn').addEventListener('click', () => toggleMenu(false));
  $('#restartBtn').addEventListener('click', () => { const c = current; if (c) { engine.ex.pb_insert(c.index); lastRender = -1; toggleMenu(false); } });
  $('#ejectBtn').addEventListener('click', eject);
  $('#settingsBtn').addEventListener('click', () => { $('#settings').hidden = false; });
  $('#shelfSettings').addEventListener('click', () => { $('#settings').hidden = false; });
  $('#settingsClose').addEventListener('click', () => { $('#settings').hidden = true; });
  $('#settings').addEventListener('click', (e) => { if (e.target.id === 'settings') $('#settings').hidden = true; });
  $('#segColor').addEventListener('click', (e) => { const v = e.target.dataset && e.target.dataset.v; if (v !== undefined) { settings.color = Number(v); applySettings(); lastRender = -1; } });
  $('#segTint').addEventListener('click', (e) => { const v = e.target.dataset && e.target.dataset.v; if (v !== undefined) { settings.tint = Number(v); applySettings(); lastRender = -1; } });
  $('#optGrid').addEventListener('change', (e) => { settings.grid = e.target.checked; applySettings(); });
  $('#optSound').addEventListener('change', (e) => { settings.sound = e.target.checked; if (settings.sound) ensureAudio(); applySettings(); });
  $('#swatches').addEventListener('click', (e) => { const k = e.target.dataset && e.target.dataset.k; if (k) { settings.shell = k; applySettings(); } });
  document.addEventListener('visibilitychange', () => { if (document.hidden && current) toggleMenu(true); });
  // iOS Safari: stop pinch/double-tap zoom and rubber-banding while playing.
  document.addEventListener('gesturestart', (e) => e.preventDefault());
  document.addEventListener('touchmove', (e) => { if (current && !menuOpen) e.preventDefault(); }, { passive: false });
}

boot();
