// Touch layer for the iPad Edition: floating joystick, taps, swipes and long-press, with per-game profiles.
(() => {
  const body = document.body;
  const layer = document.getElementById('touchlayer');
  const stickUi = document.getElementById('stickui');
  const ring = stickUi.querySelector('.ring');
  const knob = stickUi.querySelector('.knob');
  const hint = document.getElementById('hint');

  // Games that feel best with swipes (lane/grid/turn-based) and racers that should keep the gas on.
  const SWIPE = new Set(['railrunner64', 'turbofox64', 'caveflap', 'roadhopper', 'serpentine', 'mazemuncher', 'blockdrop', 'cratepusher', 'minesweeper', 'tycoontown64']);
  const GAS = new Set(['kart64', 'hover64', 'jetski64', 'turbolane']);

  const load = (k, d) => { try { const v = localStorage.getItem(k); return v ? Object.assign({}, d, JSON.parse(v)) : d; } catch (e) { return d; } };
  const save = (k, v) => { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) { /* ignore */ } };

  const ui = load('pb.ipad', { lefty: false, size: 1, op: 0.8 });
  const profiles = load('pb.ipad.ctl', {});
  let cart = null;
  let scheme = 'stick';
  let autoGas = false;
  let stick = null;
  let pulse = 0;
  const gestures = new Map();

  // ---------- look-and-feel settings ----------
  function applyUi() {
    body.classList.toggle('lefty', !!ui.lefty);
    body.style.setProperty('--ctl', String(ui.size));
    body.style.setProperty('--ctl-op', String(ui.op));
    const lefty = document.getElementById('optLefty');
    if (lefty) lefty.checked = !!ui.lefty;
    document.querySelectorAll('#segSize button').forEach((b) => b.classList.toggle('on', Number(b.dataset.v) === ui.size));
    document.querySelectorAll('#segOp button').forEach((b) => b.classList.toggle('on', Number(b.dataset.v) === ui.op));
    save('pb.ipad', ui);
  }
  document.getElementById('optLefty').addEventListener('change', (e) => { ui.lefty = e.target.checked; applyUi(); });
  document.getElementById('segSize').addEventListener('click', (e) => { const v = e.target.dataset && e.target.dataset.v; if (v) { ui.size = Number(v); applyUi(); } });
  document.getElementById('segOp').addEventListener('click', (e) => { const v = e.target.dataset && e.target.dataset.v; if (v) { ui.op = Number(v); applyUi(); } });
  applyUi();

  // ---------- per-game control profile ----------
  function profileFor(id) {
    const p = profiles[id] || {};
    return { scheme: p.scheme || (SWIPE.has(id) ? 'swipe' : 'stick'), gas: p.gas !== undefined ? !!p.gas : GAS.has(id) };
  }
  function applyProfile() {
    if (!cart) return;
    const p = profileFor(cart.id);
    scheme = p.scheme;
    autoGas = p.gas;
    body.classList.toggle('scheme-swipe', scheme === 'swipe');
    document.querySelectorAll('#segScheme button').forEach((b) => b.classList.toggle('on', b.dataset.v === scheme));
    document.getElementById('optAutoGas').checked = autoGas;
  }
  document.getElementById('segScheme').addEventListener('click', (e) => {
    const v = e.target.dataset && e.target.dataset.v;
    if (!v || !cart) return;
    profiles[cart.id] = Object.assign({}, profiles[cart.id], { scheme: v });
    save('pb.ipad.ctl', profiles);
    applyProfile();
  });
  document.getElementById('optAutoGas').addEventListener('change', (e) => {
    if (!cart) return;
    profiles[cart.id] = Object.assign({}, profiles[cart.id], { gas: e.target.checked });
    save('pb.ipad.ctl', profiles);
    applyProfile();
  });

  // ---------- input plumbing ----------
  function refresh() {
    let bits = pulse;
    if (stick) bits |= stick.bits;
    if (autoGas && stick) bits |= 16;
    if (window.pb) window.pb.setExt(bits);
  }
  function firePulse(bit, ms) {
    pulse |= bit;
    refresh();
    setTimeout(() => { pulse &= ~bit; refresh(); }, ms);
  }
  function dirFrom(dx, dy, dead) {
    const ax = Math.abs(dx), ay = Math.abs(dy);
    let b = 0;
    if (ax > dead || ay > dead) {
      if (ax > ay * 0.45) b |= dx > 0 ? 8 : 4;
      if (ay > ax * 0.45) b |= dy > 0 ? 2 : 1;
    }
    return b;
  }
  function placeStick(x, y, dx, dy) {
    const r = layer.getBoundingClientRect();
    ring.style.left = (x - r.left) + 'px';
    ring.style.top = (y - r.top) + 'px';
    const len = Math.hypot(dx, dy) || 1;
    const k = Math.min(len, 56) / len;
    knob.style.left = (x - r.left + dx * k) + 'px';
    knob.style.top = (y - r.top + dy * k) + 'px';
  }
  function clearAll() {
    for (const g of gestures.values()) clearTimeout(g.longTimer);
    gestures.clear();
    stick = null;
    pulse = 0;
    stickUi.hidden = true;
    refresh();
  }

  layer.addEventListener('pointerdown', (e) => {
    if (!cart || (window.pb && window.pb.menuOpen)) return;
    try { layer.setPointerCapture(e.pointerId); } catch (err) { /* ignore */ }
    const r = layer.getBoundingClientRect();
    const onLeftSide = (e.clientX - r.left) < r.width * 0.5;
    const stickSide = ui.lefty ? !onLeftSide : onLeftSide;
    const g = { id: e.pointerId, x0: e.clientX, y0: e.clientY, t0: performance.now(), moved: false, longFired: false, isStick: false, bits: 0 };
    if (scheme === 'stick' && stickSide && !stick) {
      g.isStick = true;
      stick = g;
      stickUi.hidden = false;
      placeStick(g.x0, g.y0, 0, 0);
    }
    g.longTimer = setTimeout(() => {
      if (!g.moved) { g.longFired = true; firePulse(32, 140); }
    }, 450);
    gestures.set(e.pointerId, g);
    refresh();
    e.preventDefault();
  });

  layer.addEventListener('pointermove', (e) => {
    const g = gestures.get(e.pointerId);
    if (!g) return;
    const dx = e.clientX - g.x0, dy = e.clientY - g.y0;
    if (Math.hypot(dx, dy) > 14 && !g.moved) { g.moved = true; clearTimeout(g.longTimer); }
    if (g.isStick) {
      g.bits = dirFrom(dx, dy, 16);
      placeStick(g.x0, g.y0, dx, dy);
      refresh();
    } else if (scheme === 'swipe' && Math.hypot(dx, dy) > 30) {
      let bit;
      if (Math.abs(dx) > Math.abs(dy)) bit = dx > 0 ? 8 : 4; else bit = dy > 0 ? 2 : 1;
      firePulse(bit, 120);
      g.x0 = e.clientX; g.y0 = e.clientY;
    }
  });

  function endGesture(e) {
    const g = gestures.get(e.pointerId);
    if (!g) return;
    clearTimeout(g.longTimer);
    gestures.delete(e.pointerId);
    const quick = performance.now() - g.t0 < 300;
    if (g.isStick) {
      stick = null;
      stickUi.hidden = true;
    }
    if (!g.moved && !g.longFired && quick) firePulse(16, 110); // a tap is the A button
    refresh();
  }
  layer.addEventListener('pointerup', endGesture);
  layer.addEventListener('pointercancel', endGesture);

  // ---------- events from app.js ----------
  function showHint() {
    let n = 0;
    try { n = Number(localStorage.getItem('pb.ipad.hints') || 0); } catch (e) { /* ignore */ }
    if (n >= 8) return;
    try { localStorage.setItem('pb.ipad.hints', String(n + 1)); } catch (e) { /* ignore */ }
    hint.textContent = scheme === 'swipe'
      ? 'Swipe to move  |  Tap = A  |  Hold = B'
      : 'Drag the left side to move  |  Tap = A  |  Hold = B';
    hint.classList.add('show');
    setTimeout(() => hint.classList.remove('show'), 5500);
  }
  window.addEventListener('pb-play', (e) => { cart = e.detail; clearAll(); applyProfile(); showHint(); });
  window.addEventListener('pb-eject', () => { cart = null; clearAll(); });
  window.addEventListener('pb-menu', (e) => { clearAll(); if (e.detail) applyProfile(); });
  window.addEventListener('blur', clearAll);
})();
