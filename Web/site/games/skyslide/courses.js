// Course definitions: four themed worlds. Colours are hex sRGB.
export const COURSES = [
  {
    id: 'island', name: 'Sunny Lagoon', sub: 'Palm islands and rainbows', seed: 7, length: 1050, twist: 1.0, pitch: 0.2, endY: 58,
    sky: { top: 0x1f63e0, mid: 0x4fb2f5, hor: 0xc4ecff, ground: 0x7fd0e8, sun: 0xfff0c4, sunElev: 0.3, sunYaw: 0.45, cloud: 0xffffff, cloudAmt: 0.75, stars: 0, aurora: 0, nebA: 0x000000, nebB: 0x000000 },
    sea: { deep: 0x0b66c4, shallow: 0x23d0cf, lagoon: 0x4ff2dc, foam: 0xffffff },
    fogDensity: 0.00135, hemi: [0xcfeaff, 0x6fc0a8, 1.05], sunInt: 2.3,
    slide: { bands: [0xff4d6d, 0xff9a3c, 0xffe14a, 0x4fe07a, 0x3fc4ff, 0x6a6bff, 0xc062ff], rim: 0xffffff, under: 0xbfe6ff, glow: 1.0 },
    deco: 'palm', gem: [0x35e0ff, 0xff7ac8], cloudCol: 0xffffff, ambient: { kind: 'sparkle', color: 0xfff2a0, size: 0.35 },
    music: { root: 'C', bpm: 124, seed: 11 }, flightRoot: 'F', stars: [2200, 5200, 10000], unlock: 0,
    card: ['#3aa0ff', '#8fe6ff', '#1fc9c4']
  },
  {
    id: 'candy', name: 'Candy Cloud Falls', sub: 'Sweet islands in pink skies', seed: 23, length: 1150, twist: 1.25, pitch: 0.21, endY: 60,
    sky: { top: 0x8a5cd8, mid: 0xf08fcf, hor: 0xffd5c8, ground: 0xffb8d8, sun: 0xfff1e0, sunElev: 0.26, sunYaw: -0.5, cloud: 0xffd3ee, cloudAmt: 0.9, stars: 0, aurora: 0, nebA: 0x000000, nebB: 0x000000 },
    sea: { deep: 0xb04fc4, shallow: 0xff98d0, lagoon: 0xffd0ec, foam: 0xfff4fa },
    fogDensity: 0.00135, hemi: [0xffd9f0, 0xc58ae0, 1.1], sunInt: 2.2,
    slide: { bands: [0xff6fae, 0xff9fd0, 0xffd36e, 0xb8f59a, 0x86e8ff, 0xa6a4ff, 0xe39cff], rim: 0xfff3fa, under: 0xffd0ea, glow: 1.0 },
    deco: 'candy', gem: [0xfff04a, 0xff5fb8], cloudCol: 0xffc6ea, ambient: { kind: 'sprinkle', color: 0xffffff, size: 0.28 },
    music: { root: 'D', bpm: 128, seed: 31 }, flightRoot: 'A', stars: [2800, 6500, 12500], unlock: 1,
    card: ['#c167ff', '#ffa8dc', '#ff7fb6']
  },
  {
    id: 'snow', name: 'Frosty Peaks', sub: 'Aurora skies and icy seas', seed: 41, length: 1200, twist: 1.1, pitch: 0.22, endY: 62,
    sky: { top: 0x2c66c0, mid: 0x7fbce6, hor: 0xe2f4ff, ground: 0xb8e4f4, sun: 0xfff6e0, sunElev: 0.2, sunYaw: 0.7, cloud: 0xf2fbff, cloudAmt: 0.65, stars: 0.0, aurora: 0.9, nebA: 0x000000, nebB: 0x000000 },
    sea: { deep: 0x0a4a86, shallow: 0x46c2cf, lagoon: 0xcdf8ff, foam: 0xffffff },
    fogDensity: 0.0015, hemi: [0xdff2ff, 0x8fb8d8, 1.1], sunInt: 2.0,
    slide: { bands: [0x5fd0ff, 0x8fe3ff, 0xffffff, 0xb7e8ff, 0x7fb6ff, 0xa7a4ff, 0xd9f5ff], rim: 0xffffff, under: 0xcfeeff, glow: 1.0 },
    deco: 'snow', gem: [0x8fefff, 0xffffff], cloudCol: 0xf6fcff, ambient: { kind: 'snow', color: 0xffffff, size: 0.3 },
    music: { root: 'E', bpm: 118, seed: 47 }, flightRoot: 'D', stars: [3200, 7500, 14000], unlock: 3,
    card: ['#4a8fe0', '#d6f2ff', '#58c8d8']
  },
  {
    id: 'space', name: 'Cosmic Splash', sub: 'Planets, stars and neon', seed: 59, length: 1250, twist: 1.35, pitch: 0.22, endY: 64,
    sky: { top: 0x05021a, mid: 0x1f0d52, hor: 0x5a2a9a, ground: 0x2a1060, sun: 0xffc8ff, sunElev: 0.28, sunYaw: -0.6, cloud: 0xb99aff, cloudAmt: 0.22, stars: 1, aurora: 0, nebA: 0xff3fa4, nebB: 0x2fd0ff },
    sea: { deep: 0x140a52, shallow: 0x8a3fe0, lagoon: 0x59f0ff, foam: 0xc8f8ff },
    fogDensity: 0.0012, hemi: [0xb8a0ff, 0x4a2a9a, 1.0], sunInt: 1.9,
    slide: { bands: [0xff3fa4, 0xff7a3c, 0xffe640, 0x3dffb0, 0x3fd0ff, 0x7a6bff, 0xd040ff], rim: 0xe8e0ff, under: 0x6a4ad0, glow: 1.9 },
    deco: 'space', gem: [0xffe640, 0x3dffb0], cloudCol: 0xc8a8ff, ambient: { kind: 'mote', color: 0x9fe8ff, size: 0.4 },
    music: { root: 'A', bpm: 132, seed: 67 }, flightRoot: 'E', stars: [3600, 8500, 16000], unlock: 6,
    card: ['#150a45', '#7a38d6', '#2fd0ff']
  }
];
