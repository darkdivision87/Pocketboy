import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';

// ---------------------------------------------------------------- GPU-point particles (CPU simulated, capped)
export class Particles {
  constructor(scene, cap, additive) {
    this.cap = cap; this.i = 0;
    this.pos = new Float32Array(cap * 3); this.vel = new Float32Array(cap * 3);
    this.col = new Float32Array(cap * 3); this.size = new Float32Array(cap); this.alpha = new Float32Array(cap);
    this.life = new Float32Array(cap); this.max = new Float32Array(cap); this.grav = new Float32Array(cap); this.base = new Float32Array(cap);
    const g = new THREE.BufferGeometry();
    this.aPos = new THREE.BufferAttribute(this.pos, 3); this.aCol = new THREE.BufferAttribute(this.col, 3);
    this.aSize = new THREE.BufferAttribute(this.size, 1); this.aAlpha = new THREE.BufferAttribute(this.alpha, 1);
    for (const a of [this.aPos, this.aCol, this.aSize, this.aAlpha]) a.setUsage(THREE.DynamicDrawUsage);
    g.setAttribute('position', this.aPos); g.setAttribute('aColor', this.aCol); g.setAttribute('aSize', this.aSize); g.setAttribute('aAlpha', this.aAlpha);
    this.uniforms = { uScale: { value: 500 } };
    this.mat = new THREE.ShaderMaterial({
      uniforms: this.uniforms, transparent: true, depthWrite: false, blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending,
      vertexShader: `attribute vec3 aColor; attribute float aSize; attribute float aAlpha; uniform float uScale; varying vec3 vC; varying float vA;
        void main(){ vC=aColor; vA=aAlpha; vec4 mv=modelViewMatrix*vec4(position,1.); gl_Position=projectionMatrix*mv; gl_PointSize=min(aSize*uScale/max(-mv.z,0.5),0.12*uScale); }`,
      fragmentShader: `precision highp float; varying vec3 vC; varying float vA;
        void main(){ float d=length(gl_PointCoord-0.5)*2.; float a=smoothstep(1.,0.15,d)*vA; if(a<0.01) discard; gl_FragColor=vec4(vC,a); }`
    });
    this.points = new THREE.Points(g, this.mat); this.points.frustumCulled = false; this.points.renderOrder = additive ? 7 : 6;
    scene.add(this.points);
  }
  emit(x, y, z, vx, vy, vz, r, g, b, size, life, grav) {
    const i = this.i; this.i = (i + 1) % this.cap; const k = i * 3;
    this.pos[k] = x; this.pos[k + 1] = y; this.pos[k + 2] = z; this.vel[k] = vx; this.vel[k + 1] = vy; this.vel[k + 2] = vz;
    this.col[k] = r; this.col[k + 1] = g; this.col[k + 2] = b; this.base[i] = size; this.life[i] = life; this.max[i] = life; this.grav[i] = grav || 0;
  }
  update(dt, scale) {
    this.uniforms.uScale.value = scale;
    const { pos, vel, life, max, grav, size, alpha, base, cap } = this;
    const drag = Math.exp(-0.9 * dt);
    for (let i = 0; i < cap; i++) {
      if (life[i] <= 0) { if (alpha[i] !== 0) { alpha[i] = 0; size[i] = 0; } continue; }
      life[i] -= dt; const k = i * 3;
      vel[k + 1] -= grav[i] * dt; vel[k] *= drag; vel[k + 2] *= drag;
      pos[k] += vel[k] * dt; pos[k + 1] += vel[k + 1] * dt; pos[k + 2] += vel[k + 2] * dt;
      const t = Math.max(life[i] / max[i], 0);
      alpha[i] = Math.min(1, t * 2.2) * (t > 0 ? 1 : 0); size[i] = base[i] * (0.35 + 0.65 * Math.sqrt(t)) ;
    }
    this.aPos.needsUpdate = true; this.aCol.needsUpdate = true; this.aSize.needsUpdate = true; this.aAlpha.needsUpdate = true;
  }
  clear() { this.life.fill(0); }
}

// ---------------------------------------------------------------- post processing: bloom + sun rays + speed blur + vignette
const FX = {
  uniforms: { tDiffuse: { value: null }, sunUV: { value: new THREE.Vector2(0.5, 0.5) }, rays: { value: 0 }, aspect: { value: 1 }, speed: { value: 0 }, vig: { value: 0.35 }, tint: { value: new THREE.Color(1, 1, 1) }, flash: { value: 0 } },
  vertexShader: `varying vec2 vUv; void main(){ vUv=uv; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.); }`,
  fragmentShader: `uniform sampler2D tDiffuse; uniform vec2 sunUV; uniform float rays, aspect, speed, vig, flash; uniform vec3 tint; varying vec2 vUv;
    void main(){
      vec2 c = vUv - 0.5; vec3 col;
      if (speed > 0.01) {
        col = vec3(0.);
        for (int i = 0; i < 5; i++) { float t = float(i) / 4.; col += texture2D(tDiffuse, 0.5 + c * (1. - speed * 0.075 * t)).rgb; }
        col /= 5.;
      } else col = texture2D(tDiffuse, vUv).rgb;
      if (rays > 0.001) {
        vec2 d = (sunUV - vUv); vec2 stp = d / 14.; vec2 p = vUv + stp * fract(sin(dot(vUv, vec2(12.9898, 78.233))) * 43758.5453);
        vec3 acc = vec3(0.); float w = 1.;
        for (int i = 0; i < 14; i++) { p += stp; vec3 s = min(texture2D(tDiffuse, p).rgb, vec3(3.0)); float l = max(0., dot(s, vec3(.3, .55, .15)) - 1.25); acc += s * l * w; w *= 0.9; }
        float fall = 1.0 / (1.0 + 2.0 * length(d * vec2(aspect, 1.)));
        col += acc * rays * 0.03 * fall;
      }
      float r = length(c * vec2(aspect * 0.6 + 0.4, 1.));
      col *= 1.0 - vig * smoothstep(0.35, 0.95, r);
      col *= tint; col += flash;
      gl_FragColor = vec4(col, 1.);
    }`
};

export class Post {
  constructor(renderer, scene, camera, samples) {
    this.renderer = renderer; this.size = new THREE.Vector2();
    renderer.getSize(this.size);
    const rt = new THREE.WebGLRenderTarget(this.size.x, this.size.y, { type: THREE.HalfFloatType, samples });
    this.composer = new EffectComposer(renderer, rt);
    this.composer.addPass(new RenderPass(scene, camera));
    this.bloom = new UnrealBloomPass(new THREE.Vector2(this.size.x / 2, this.size.y / 2), 0.38, 0.55, 1.0);
    this.composer.addPass(this.bloom);
    this.fx = new ShaderPass(FX); this.composer.addPass(this.fx);
    this.composer.addPass(new OutputPass());
    this.u = this.fx.uniforms;
  }
  setSize(w, h, pr) { this.composer.setPixelRatio(pr); this.composer.setSize(w, h); this.u.aspect.value = w / h; }
  render(dt) { this.composer.render(dt); }
}

// ---------------------------------------------------------------- radial speed lines (2D overlay)
export class SpeedLines {
  constructor(canvas) {
    this.c = canvas; this.g = canvas.getContext('2d'); this.n = 38; this.seed = []; for (let i = 0; i < this.n; i++) this.seed.push({ a: Math.random() * 6.283, p: Math.random(), l: 0.1 + Math.random() * 0.22, w: 1 + Math.random() * 2.5 });
    this.last = 0;
  }
  resize(w, h) { this.c.width = Math.round(w * 0.6); this.c.height = Math.round(h * 0.6); }
  draw(dt, k, tintRGB) {
    const g = this.g, W = this.c.width, H = this.c.height;
    if (k < 0.04) { if (this.last > 0) g.clearRect(0, 0, W, H); this.last = 0; return; }
    this.last = k; g.clearRect(0, 0, W, H);
    const cx = W / 2, cy = H * 0.46, R = Math.hypot(W, H) * 0.5;
    g.lineCap = 'round';
    for (const s of this.seed) {
      s.p += dt * (1.3 + k * 2.2); if (s.p > 1) { s.p -= 1; s.a = Math.random() * 6.283; s.l = 0.1 + Math.random() * 0.25; }
      const r0 = R * (0.38 + 0.62 * s.p * s.p), r1 = r0 + R * s.l * (0.4 + s.p);
      const ca = Math.cos(s.a), sa = Math.sin(s.a);
      g.strokeStyle = `rgba(${tintRGB},${(0.5 * k * Math.sin(Math.min(1, s.p * 1.4) * 3.14)).toFixed(3)})`; g.lineWidth = s.w * (0.6 + s.p);
      g.beginPath(); g.moveTo(cx + ca * r0, cy + sa * r0 * 0.9); g.lineTo(cx + ca * r1, cy + sa * r1 * 0.9); g.stroke();
    }
  }
}
