import * as THREE from 'three';

export const skyU = {
  uTop: { value: new THREE.Color() }, uMid: { value: new THREE.Color() }, uHor: { value: new THREE.Color() }, uGround: { value: new THREE.Color() },
  uSunDir: { value: new THREE.Vector3(0, 0.3, 1).normalize() }, uSunCol: { value: new THREE.Color() },
  uTime: { value: 0 }, uStars: { value: 0 }, uAurora: { value: 0 }, uCloud: { value: 0.7 }, uCloudCol: { value: new THREE.Color() },
  uNebA: { value: new THREE.Color() }, uNebB: { value: new THREE.Color() }
};
export const fogU = { uFogColor: { value: new THREE.Color() }, uFogDensity: { value: 0.0013 } };

const SKY_HEAD = `
uniform vec3 uTop, uMid, uHor, uGround, uSunDir, uSunCol;
vec3 skyColor(vec3 d){
  float h = d.y;
  vec3 c = mix(uHor, uMid, smoothstep(0.0, 0.2, h));
  c = mix(c, uTop, smoothstep(0.1, 0.9, h));
  c = mix(c, uGround, smoothstep(0.0, -0.35, h) * 0.5);
  float sd = max(dot(d, uSunDir), 0.0);
  c += uSunCol * (pow(sd, 6.0) * 0.18 + pow(sd, 48.0) * 0.4 + pow(sd, 400.0) * 0.8);
  return c;
}`;

export const skyMat = () => new THREE.ShaderMaterial({
  uniforms: skyU, side: THREE.BackSide, depthWrite: false, fog: false,
  vertexShader: `varying vec3 vDir; void main(){ vDir = position; vec4 p = modelViewMatrix * vec4(position, 1.0); gl_Position = projectionMatrix * p; gl_Position.z = gl_Position.w * 0.99999; }`,
  fragmentShader: `precision highp float; varying vec3 vDir; uniform float uTime, uStars, uAurora, uCloud; uniform vec3 uCloudCol, uNebA, uNebB;
  ${SKY_HEAD}
  float h31(vec3 p){ p = fract(p * 0.3183099 + .1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
  float n3(vec3 x){ vec3 i = floor(x), f = fract(x); f = f * f * (3. - 2. * f);
    return mix(mix(mix(h31(i), h31(i + vec3(1,0,0)), f.x), mix(h31(i + vec3(0,1,0)), h31(i + vec3(1,1,0)), f.x), f.y),
               mix(mix(h31(i + vec3(0,0,1)), h31(i + vec3(1,0,1)), f.x), mix(h31(i + vec3(0,1,1)), h31(i + vec3(1,1,1)), f.x), f.y), f.z); }
  float fbm3(vec3 p){ float a = .5, s = 0.; for (int i = 0; i < 4; i++) { s += a * n3(p); p *= 2.03; a *= .5; } return s; }
  void main(){
    vec3 d = normalize(vDir);
    vec3 col = skyColor(d);
    float sd = dot(d, uSunDir);
    col += uSunCol * smoothstep(0.9991, 0.9996, sd) * 7.0;
    if (uCloud > 0.01 && d.y > 0.0) {
      vec2 q = d.xz / (d.y + 0.14) * 1.25 + vec2(uTime * 0.012, 0.0);
      float n = fbm3(vec3(q, uTime * 0.02));
      float c = smoothstep(0.5, 0.82, n) * smoothstep(0.0, 0.2, d.y) * uCloud;
      float lit = 0.8 + 0.5 * pow(max(sd, 0.), 3.0);
      col = mix(col, uCloudCol * lit, c * 0.9);
    }
    if (uStars > 0.01) {
      vec3 p = d * 150.; vec3 ip = floor(p); float h = h31(ip); vec3 fp = fract(p) - .5;
      float st = step(0.972, h) * smoothstep(0.34, 0.0, length(fp)) * (.55 + .45 * sin(uTime * 2. + h * 80.));
      col += vec3(1.0, 0.95, 1.0) * st * uStars * 1.6 * smoothstep(-0.2, 0.1, d.y);
      float nb = fbm3(d * 2.2 + 3.1), nb2 = fbm3(d * 3.4 - 7.);
      col += mix(uNebA, uNebB, nb2) * smoothstep(0.42, 0.85, nb) * uStars * 0.85;
    }
    if (uAurora > 0.01 && d.y > 0.04) {
      float t = uTime * 0.05; float w = fbm3(vec3(d.x * 3., d.z * 3., t)) * 2.;
      float rib = pow(sin(d.x * 5. + w * 3. + t * 3.) * .5 + .5, 3.0);
      float band = smoothstep(0.07, 0.26, d.y) * smoothstep(0.85, 0.3, d.y);
      vec3 ac = mix(vec3(.15, 1., .6), vec3(.55, .35, 1.), smoothstep(.2, .7, d.y + w * 0.1));
      col += ac * rib * band * uAurora * 0.7;
    }
    gl_FragColor = vec4(col, 1.0);
  }`
});

export const seaMat = (extra) => new THREE.ShaderMaterial({
  uniforms: Object.assign({ uDeep: { value: new THREE.Color() }, uShallow: { value: new THREE.Color() }, uTime: { value: 0 }, uSun: { value: 1 } }, skyU, fogU, extra || {}),
  fog: false,
  vertexShader: `varying vec3 vWorld; void main(){ vec4 w = modelMatrix * vec4(position, 1.0); vWorld = w.xyz; gl_Position = projectionMatrix * viewMatrix * w; }`,
  fragmentShader: `precision highp float; varying vec3 vWorld; uniform vec3 uDeep, uShallow, uFogColor; uniform float uTime, uFogDensity;
  ${SKY_HEAD}
  vec2 slope(vec2 p, float t, float fd){
    vec2 g = vec2(0.);
    p += vec2(sin(p.y * 0.07 + t * 0.2), cos(p.x * 0.06 - t * 0.17)) * 7.0 + vec2(sin(p.y * 0.31 + t * 0.5), cos(p.x * 0.27 - t * 0.4)) * 1.2;
    g += vec2(.80, .60) * 0.085 * cos(dot(vec2(.80, .60), p) * 0.33 + t * 1.2);
    g += vec2(-.55, .83) * 0.065 * cos(dot(vec2(-.55, .83), p) * 0.71 + t * 1.5);
    g += vec2(.30, -.95) * 0.05 * fd * cos(dot(vec2(.30, -.95), p) * 1.55 + t * 2.1);
    g += vec2(-.90, -.43) * 0.04 * fd * cos(dot(vec2(-.90, -.43), p) * 3.1 + t * 2.7);
    g += vec2(.6, .8) * 0.03 * fd * fd * cos(dot(vec2(.6, .8), p) * 6.3 + t * 3.3);
    return g;
  }
  void main(){
    vec3 toCam = cameraPosition - vWorld; float dist = length(toCam);
    vec3 V = toCam / dist;
    float fd = 1.0 - smoothstep(12., 120., dist);
    vec2 g = slope(vWorld.xz, uTime, fd) * (1.0 - 0.9 * smoothstep(60., 900., dist));
    vec3 N = normalize(vec3(-g.x, 1.0, -g.y));
    float nv = max(dot(N, V), 0.0);
    float fres = pow(1.0 - nv, 4.0) * 0.9 + 0.04;
    vec3 R = reflect(-V, N); R.y = abs(R.y);
    vec3 refl = skyColor(R);
    float ptch = 0.5 + 0.5 * sin(vWorld.x * 0.011 + sin(vWorld.z * 0.007) * 2.0 + uTime * 0.08);
    vec3 body = mix(uDeep, uShallow, clamp(pow(nv, 1.6) * 0.65 + 0.18 * ptch + 0.15 * (g.x + g.y) * 4.0, 0., 1.));
    vec3 col = mix(body, refl, fres);
    float sd = max(dot(R, uSunDir), 0.0);
    col += uSunCol * (pow(sd, 260.0) * 3.0 + pow(sd, 50.0) * 0.5 + pow(sd, 8.0) * 0.12);
    float crest = smoothstep(0.17, 0.3, g.x * .6 + g.y * .5 + 0.5 * sin(vWorld.x * 0.9 + vWorld.z * 0.7 + uTime * 2.0) * 0.05);
    col += vec3(1.) * crest * 0.1 * fd;
    float f = 1.0 - exp(-pow(uFogDensity * dist, 2.0));
    col = mix(col, uFogColor, clamp(f, 0., 1.));
    gl_FragColor = vec4(col, 1.0);
  }`
});

export const slideMat = (bands, rim, under, glow) => {
  const u = Object.assign({
    uBands: { value: bands.map((c) => new THREE.Color(c)) }, uRim: { value: new THREE.Color(rim) }, uUnder: { value: new THREE.Color(under) },
    uGlow: { value: glow }, uTime: { value: 0 }
  }, skyU, fogU);
  return new THREE.ShaderMaterial({
    uniforms: u, side: THREE.DoubleSide, fog: false,
    vertexShader: `attribute float aLat; attribute float aKind; attribute float aS; varying vec3 vW; varying vec3 vN; varying float vLat; varying float vKind; varying float vS;
      void main(){ vec4 w = modelMatrix * vec4(position, 1.0); vW = w.xyz; vN = normalize(mat3(modelMatrix) * normal); vLat = aLat; vKind = aKind; vS = aS; gl_Position = projectionMatrix * viewMatrix * w; }`,
    fragmentShader: `precision highp float; varying vec3 vW; varying vec3 vN; varying float vLat; varying float vKind; varying float vS;
      uniform vec3 uBands[7]; uniform vec3 uRim, uUnder, uFogColor; uniform float uGlow, uTime, uFogDensity;
      ${SKY_HEAD}
      void main(){
        vec3 toCam = cameraPosition - vW; float dist = length(toCam); vec3 V = toCam / dist;
        vec3 N = normalize(vN); if (dot(N, V) < 0.0) N = -N;
        vec3 base; float top = 0.0;
        if (vKind < 0.5) {
          top = 1.0;
          float x = clamp((vLat * 0.5 + 0.5) * 7.0, 0.0, 6.9999); int i = int(floor(x)); float f = fract(x);
          vec3 a = uBands[i]; vec3 b = uBands[min(i + 1, 6)];
          base = mix(a, b, smoothstep(0.82, 1.0, f));
          float fl = sin(vS * 0.8 - uTime * 9.0 + sin(vLat * 7.0 + vS * 0.13) * 2.4);
          base += vec3(1.0) * smoothstep(0.86, 1.0, fl) * 0.16;
          base *= uGlow;
        } else if (vKind < 1.5) base = uRim;
        else base = uUnder * (0.7 + 0.3 * N.y);
        float dif = 0.62 + 0.45 * max(dot(N, uSunDir), 0.0);
        float nv = max(dot(N, V), 0.0); float fres = pow(1.0 - nv, 3.0);
        vec3 R = reflect(-V, N);
        vec3 col = base * dif;
        col += skyColor(R) * (0.02 + fres * 0.3);
        col += uSunCol * pow(max(dot(R, uSunDir), 0.0), 50.0) * (top > 0.5 ? 1.1 : 0.35);
        float f = 1.0 - exp(-pow(uFogDensity * dist, 2.0));
        col = mix(col, uFogColor, clamp(f, 0., 1.));
        gl_FragColor = vec4(col, 1.0);
      }`
  });
};

export const padMat = () => new THREE.ShaderMaterial({
  uniforms: { uTime: { value: 0 }, uA: { value: new THREE.Color(0x35f5ff) }, uB: { value: new THREE.Color(0xffe94a) } },
  transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide,
  vertexShader: `varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
  fragmentShader: `varying vec2 vUv; uniform float uTime; uniform vec3 uA, uB;
    void main(){
      float a = abs(vUv.x - 0.5) * 2.0;
      float ch = fract(vUv.y * 3.0 - a * 0.55 - uTime * 1.8);
      float m = smoothstep(0.0, 0.12, ch) * smoothstep(0.55, 0.38, ch);
      float edge = (1.0 - pow(a, 3.0)) * smoothstep(0.0, 0.12, vUv.y) * smoothstep(1.0, 0.88, vUv.y);
      vec3 c = mix(uA, uB, vUv.y);
      float base = 0.22 * edge;
      gl_FragColor = vec4(c * (m * 3.2 + 0.6) , (m * 0.95 + base) * edge);
    }`
});
