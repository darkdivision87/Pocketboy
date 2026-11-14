import * as THREE from 'three';
// pooled soft-dot particles (one Points object per scene) + DOM floaters for score pops
const MAXP = 500;
export class Particles {
  constructor() {
    this.pos = new Float32Array(MAXP * 3); this.col = new Float32Array(MAXP * 3); this.siz = new Float32Array(MAXP);
    this.vel = new Float32Array(MAXP * 3); this.life = new Float32Array(MAXP); this.max = new Float32Array(MAXP); this.base = new Float32Array(MAXP); this.grav = new Float32Array(MAXP);
    this.i = 0;
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3)); g.setAttribute('color', new THREE.BufferAttribute(this.col, 3)); g.setAttribute('size', new THREE.BufferAttribute(this.siz, 1));
    const m = new THREE.ShaderMaterial({
      transparent: true, depthWrite: false, vertexColors: true, uniforms: { px: { value: 600 } },
      vertexShader: 'attribute float size; varying vec3 vC; uniform float px; void main(){ vC=color; vec4 mv=modelViewMatrix*vec4(position,1.); gl_PointSize=size*px/max(.1,-mv.z); gl_Position=projectionMatrix*mv; }',
      fragmentShader: 'varying vec3 vC; void main(){ vec2 p=gl_PointCoord-.5; float d=length(p); if(d>.5) discard; float a=smoothstep(.5,.15,d); gl_FragColor=vec4(vC,a); #include <colorspace_fragment>\n}',
    });
    this.mat = m; this.points = new THREE.Points(g, m); this.points.frustumCulled = false; this.points.renderOrder = 5;
    this.c = new THREE.Color();
  }
  resize(h, pr) { this.mat.uniforms.px.value = h * pr * 0.9; }
  emit(x, y, z, vx, vy, vz, life, color, size, grav = 0) {
    const i = this.i = (this.i + 1) % MAXP, k = i * 3;
    this.pos[k] = x; this.pos[k + 1] = y; this.pos[k + 2] = z; this.vel[k] = vx; this.vel[k + 1] = vy; this.vel[k + 2] = vz;
    this.c.set(color); this.col[k] = this.c.r; this.col[k + 1] = this.c.g; this.col[k + 2] = this.c.b;
    this.life[i] = life; this.max[i] = life; this.base[i] = size; this.grav[i] = grav;
  }
  burst(x, y, z, n, color, speed = 4, life = 0.7, size = 0.35, grav = 8) {
    for (let i = 0; i < n; i++) {
      const a = Math.random() * 6.283, u = Math.random() * 2 - 1, s = speed * (0.4 + Math.random() * 0.6), r = Math.sqrt(1 - u * u);
      const col = Array.isArray(color) ? color[(Math.random() * color.length) | 0] : color;
      this.emit(x, y, z, Math.cos(a) * r * s, u * s * 0.8 + speed * 0.4, Math.sin(a) * r * s, life * (0.6 + Math.random() * 0.5), col, size * (0.6 + Math.random() * 0.6), grav);
    }
  }
  update(dt) {
    for (let i = 0; i < MAXP; i++) {
      if (this.life[i] <= 0) { this.siz[i] = 0; continue; }
      this.life[i] -= dt; const k = i * 3;
      this.vel[k + 1] -= this.grav[i] * dt;
      this.pos[k] += this.vel[k] * dt; this.pos[k + 1] += this.vel[k + 1] * dt; this.pos[k + 2] += this.vel[k + 2] * dt;
      const t = Math.max(0, this.life[i] / this.max[i]); this.siz[i] = this.base[i] * Math.min(1, t * 2.5);
    }
    const g = this.points.geometry; g.attributes.position.needsUpdate = true; g.attributes.color.needsUpdate = true; g.attributes.size.needsUpdate = true;
  }
}

const floaters = () => document.getElementById('floaters');
export function floatText(text, sx, sy, cls = '') {
  const el = document.createElement('div'); el.className = 'floater ' + cls; el.textContent = text;
  el.style.left = sx + 'px'; el.style.top = sy + 'px'; floaters().appendChild(el);
  setTimeout(() => el.remove(), 1100);
}
