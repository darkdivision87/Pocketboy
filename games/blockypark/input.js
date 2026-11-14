import { clamp } from './util.js';
// Unified input: floating left joystick, right-side camera drag, keyboard/mouse. Taps are reported via onTap.
export class Input {
  constructor(canvas) {
    this.canvas = canvas; this.mx = 0; this.my = 0; this.jump = false; this.jumpEdge = false; this.camDX = 0; this.camDY = 0; this.zoom = 0;
    this.keys = {}; this.enabled = true; this.onTap = null; this.stickId = null; this.camIds = new Map(); this.stick = { x: 0, y: 0 }; this.touchSeen = false; this.btnJump = false;
    this.base = document.getElementById('stickBase'); this.knob = document.getElementById('stickKnob'); this.R = 62;
    this.hasStick = true; this.downs = new Map();
    canvas.addEventListener('pointerdown', (e) => this.down(e));
    addEventListener('pointermove', (e) => this.move(e));
    addEventListener('pointerup', (e) => this.up(e)); addEventListener('pointercancel', (e) => this.up(e));
    canvas.addEventListener('wheel', (e) => { this.zoom += e.deltaY * 0.01; e.preventDefault(); }, { passive: false });
    canvas.addEventListener('contextmenu', (e) => e.preventDefault());
    addEventListener('keydown', (e) => { if (e.repeat) return; this.keys[e.code] = true; if (e.code === 'Space') { this.jumpEdge = true; this.jump = true; e.preventDefault(); } if (e.code.startsWith('Arrow')) e.preventDefault(); });
    addEventListener('keyup', (e) => { this.keys[e.code] = false; if (e.code === 'Space') this.jump = false; });
    addEventListener('blur', () => { this.keys = {}; this.jump = false; });
    for (const ev of ['gesturestart', 'gesturechange']) document.addEventListener(ev, (e) => e.preventDefault());
    document.addEventListener('touchmove', (e) => { if (e.target.closest && e.target.closest('.scroll')) return; e.preventDefault(); }, { passive: false });
  }
  setJumpButton(el) {
    const on = (e) => { e.preventDefault(); e.stopPropagation(); this.btnJump = true; this.jump = true; this.jumpEdge = true; el.classList.add('down'); };
    const off = (e) => { this.btnJump = false; this.jump = false; el.classList.remove('down'); };
    el.addEventListener('pointerdown', on); el.addEventListener('pointerup', off); el.addEventListener('pointercancel', off); el.addEventListener('pointerleave', off);
  }
  down(e) {
    if (!this.enabled) return;
    const touch = e.pointerType !== 'mouse';
    if (touch && !this.touchSeen) { this.touchSeen = true; document.body.classList.add('touch'); }
    this.downs.set(e.pointerId, { x: e.clientX, y: e.clientY, t: performance.now(), moved: 0 });
    this.canvas.setPointerCapture && this.canvas.setPointerCapture(e.pointerId);
    if (touch && e.clientX < innerWidth * 0.5 && this.stickId === null && this.hasStick) {
      this.stickId = e.pointerId; this.ox = e.clientX; this.oy = e.clientY; this.base.style.left = this.ox + 'px'; this.base.style.top = this.oy + 'px'; this.base.classList.add('active'); this.knob.style.transform = 'translate(-50%,-50%)';
    } else this.camIds.set(e.pointerId, { x: e.clientX, y: e.clientY, btn: e.button });
  }
  move(e) {
    const d = this.downs.get(e.pointerId); if (!d) return;
    d.moved += Math.abs(e.clientX - d.x) + Math.abs(e.clientY - d.y);
    if (e.pointerId === this.stickId) {
      let dx = e.clientX - this.ox, dy = e.clientY - this.oy; const l = Math.hypot(dx, dy), R = this.R;
      if (l > R) { this.ox += dx / l * (l - R); this.oy += dy / l * (l - R); dx = dx / l * R; dy = dy / l * R; this.base.style.left = this.ox + 'px'; this.base.style.top = this.oy + 'px'; }
      this.knob.style.transform = `translate(calc(-50% + ${dx}px),calc(-50% + ${dy}px))`;
      let sx = dx / R, sy = -dy / R; const m = Math.hypot(sx, sy); if (m < 0.12) { sx = sy = 0; } this.stick.x = sx; this.stick.y = sy;
    } else { const c = this.camIds.get(e.pointerId); if (c) { this.camDX += e.clientX - c.x; this.camDY += e.clientY - c.y; c.x = e.clientX; c.y = e.clientY; } }
    d.x = e.clientX; d.y = e.clientY;
  }
  up(e) {
    const d = this.downs.get(e.pointerId); if (!d) return; this.downs.delete(e.pointerId);
    if (e.pointerId === this.stickId) { this.stickId = null; this.stick.x = this.stick.y = 0; this.base.classList.remove('active'); }
    this.camIds.delete(e.pointerId);
    if (performance.now() - d.t < 300 && d.moved < 14 && this.onTap && this.enabled) this.onTap(e.clientX, e.clientY, e);
  }
  poll() {
    const k = this.keys; let x = this.stick.x, y = this.stick.y;
    if (k.KeyA || k.ArrowLeft) x -= 1; if (k.KeyD || k.ArrowRight) x += 1; if (k.KeyW || k.ArrowUp) y += 1; if (k.KeyS || k.ArrowDown) y -= 1;
    const l = Math.hypot(x, y); if (l > 1) { x /= l; y /= l; }
    this.mx = this.enabled ? x : 0; this.my = this.enabled ? y : 0;
  }
  takeJump() { const j = this.jumpEdge; this.jumpEdge = false; return j && this.enabled; }
  takeCam() { const r = [this.camDX, this.camDY, this.zoom]; this.camDX = this.camDY = this.zoom = 0; return r; }
  reset() { this.stickId = null; this.stick.x = this.stick.y = 0; this.camIds.clear(); this.downs.clear(); this.base.classList.remove('active'); this.jump = false; this.jumpEdge = false; }
}
