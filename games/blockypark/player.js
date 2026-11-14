import { moveBody } from './physics.js';
import { damp, angDiff, clamp } from './util.js';
import { updateAvatar } from './avatar.js';

export const JUMP_V = 14.2, GRAV = 38;
// advance a walking character one step. P: {body, avatar, face, coyote, buf, stun, speed}
export function stepWalker(P, dt, mx, my, camYaw, wantJump, cols, grid, o = {}) {
  const b = P.body, sp = (o.speed || 9) * (P.speedMul || 1);
  P.ev = null;
  if (P.stun > 0) { P.stun -= dt; mx = my = 0; wantJump = false; }
  const sy = Math.sin(camYaw), cy = Math.cos(camYaw);
  // camera forward = (-sin, -cos); right = (cos, -sin)
  const dx = -sy * my + cy * mx, dz = -cy * my - sy * mx, len = Math.hypot(mx, my);
  const tx = dx * sp, tz = dz * sp, k = b.onGround ? 16 : 6;
  if (P.stun > 0) { b.vx = damp(b.vx, 0, 3, dt); b.vz = damp(b.vz, 0, 3, dt); } else { b.vx = damp(b.vx, tx, k, dt); b.vz = damp(b.vz, tz, k, dt); }
  if (len > 0.12) { const target = Math.atan2(dx, dz); P.face += angDiff(P.face, target) * Math.min(1, dt * 14); }
  if (wantJump) P.buf = 0.14; else P.buf = Math.max(0, (P.buf || 0) - dt);
  P.coyote = b.onGround ? 0.11 : Math.max(0, (P.coyote || 0) - dt);
  if (P.buf > 0 && P.coyote > 0) { b.vy = o.jump || JUMP_V; P.buf = 0; P.coyote = 0; b.onGround = false; P.ev = 'jump'; P.jumping = true; P.avatar.squash = -0.18; }
  if (P.jumping && !P.jumpHeld && b.vy > 5) { b.vy *= 0.5; P.jumping = false; }
  if (b.onGround) P.jumping = false;
  b.vy = Math.max(b.vy - GRAV * dt, -55);
  moveBody(b, dt, cols, grid);
  if (b.onGround && !b.wasGround && b.lastVy < -7) { P.ev = 'land'; P.avatar.squash = clamp(-b.lastVy / 70, 0.08, 0.3); }
  P.speed = Math.hypot(b.vx, b.vz);
}
export function syncAvatar(P, dt) {
  const b = P.body, A = P.avatar;
  A.root.position.set(b.x, b.y, b.z); A.root.rotation.y = P.face;
  updateAvatar(A, dt, P.speed, !b.onGround, b.vy);
}
