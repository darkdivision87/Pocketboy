// Maestro: a procedural music and sound-effects engine built on Web Audio (no audio files needed).
// A "theme" describes tempo, key, chord progression and which instruments play; the engine schedules drums, bass, pad,
// arpeggio, lead melody and bells in real time and fades layers in and out with setIntensity(0..1).
//
//   const music = new Maestro();
//   startButton.onclick = () => { music.unlock(); music.play('sunny'); };   // must be called from a tap
//   music.setIntensity(0.8);  music.sfx('coin');  music.stop(1.5);
//
// Built-in themes: sunny, neon, calm, action, board, toy, boss, victory. Pass your own theme object to play().

const NOTE = { C: 0, 'C#': 1, Db: 1, D: 2, 'D#': 3, Eb: 3, E: 4, F: 5, 'F#': 6, Gb: 6, G: 7, 'G#': 8, Ab: 8, A: 9, 'A#': 10, Bb: 10, B: 11 };
const SCALES = {
  major: [0, 2, 4, 5, 7, 9, 11], minor: [0, 2, 3, 5, 7, 8, 10], dorian: [0, 2, 3, 5, 7, 9, 10],
  mixolydian: [0, 2, 4, 5, 7, 9, 10], lydian: [0, 2, 4, 6, 7, 9, 11], pentatonic: [0, 2, 4, 7, 9], minpent: [0, 3, 5, 7, 10],
};

export const THEMES = {
  sunny: { bpm: 124, root: 'C', scale: 'major', prog: [0, 4, 5, 3], seventh: false, swing: 0.0, seed: 11,
    drums: 'fourfloor', hats: true, bass: 'bounce', pad: true, arp: { pattern: [0, 2, 4, 2, 5, 4, 2, 1], wave: 'triangle', oct: 1 }, lead: { wave: 'square', oct: 1, density: 0.6 }, bell: true, level: 0.9 },
  neon: { bpm: 138, root: 'A', scale: 'minor', prog: [0, 5, 2, 6], seventh: true, swing: 0, seed: 23,
    drums: 'fourfloor', hats: true, bass: 'drive', pad: true, arp: { pattern: [0, 3, 5, 7, 5, 3, 2, 3], wave: 'sawtooth', oct: 1 }, lead: { wave: 'sawtooth', oct: 1, density: 0.55 }, bell: false, level: 0.85 },
  calm: { bpm: 84, root: 'F', scale: 'major', prog: [0, 2, 3, 4], seventh: true, swing: 0.1, seed: 5,
    drums: 'soft', hats: false, bass: 'sub', pad: true, arp: { pattern: [0, 1, 2, 4, 2, 1, 0, 2], wave: 'sine', oct: 1 }, lead: { wave: 'triangle', oct: 1, density: 0.35 }, bell: true, level: 0.8 },
  action: { bpm: 150, root: 'E', scale: 'minor', prog: [0, 0, 5, 6], seventh: false, swing: 0, seed: 41,
    drums: 'breakbeat', hats: true, bass: 'drive', pad: true, arp: { pattern: [0, 0, 2, 0, 4, 0, 2, 0], wave: 'square', oct: 1 }, lead: { wave: 'sawtooth', oct: 1, density: 0.7 }, bell: false, level: 0.9 },
  board: { bpm: 110, root: 'G', scale: 'major', prog: [0, 5, 1, 4], seventh: true, swing: 0.22, seed: 77,
    drums: 'swing', hats: true, bass: 'walk', pad: true, arp: { pattern: [0, 2, 4, 2], wave: 'triangle', oct: 1 }, lead: { wave: 'triangle', oct: 1, density: 0.5 }, bell: true, level: 0.85 },
  toy: { bpm: 132, root: 'D', scale: 'major', prog: [0, 3, 4, 0, 5, 3, 4, 4], seventh: false, swing: 0.12, seed: 91,
    drums: 'half', hats: true, bass: 'bounce', pad: false, arp: { pattern: [0, 4, 2, 4, 0, 5, 3, 5], wave: 'triangle', oct: 1 }, lead: { wave: 'square', oct: 1, density: 0.65 }, bell: true, level: 0.9 },
  boss: { bpm: 160, root: 'D', scale: 'minor', prog: [0, 0, 5, 4], seventh: false, swing: 0, seed: 7,
    drums: 'breakbeat', hats: true, bass: 'drive', pad: true, arp: { pattern: [0, 7, 0, 5, 0, 4, 0, 3], wave: 'sawtooth', oct: 1 }, lead: { wave: 'sawtooth', oct: 1, density: 0.8 }, bell: false, level: 0.95 },
  victory: { bpm: 120, root: 'C', scale: 'major', prog: [0, 3, 4, 0], seventh: false, swing: 0, seed: 3,
    drums: 'half', hats: true, bass: 'root', pad: true, arp: { pattern: [0, 2, 4, 7, 4, 2, 0, 2], wave: 'triangle', oct: 1 }, lead: { wave: 'square', oct: 1, density: 0.7 }, bell: true, level: 0.9 },
};

function mulberry(seed) { let a = seed >>> 0; return () => { a |= 0; a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }
const mtof = (m) => 440 * Math.pow(2, (m - 69) / 12);

export class Maestro {
  constructor() {
    this.ctx = null; this.master = null; this.musicBus = null; this.sfxBus = null; this.reverb = null; this.delay = null;
    this.muted = false; this.volume = 0.8; this.theme = null; this.intensity = 0.6; this.target = 0.6; this.playing = false;
    this.step = 0; this.nextTime = 0; this.timer = null; this._noise = null; this.rand = Math.random; this.offline = false;
    this.paused = false;
    document.addEventListener('visibilitychange', () => { if (document.hidden) this.pause(); else this.resume(); });
  }

  // Call from a user gesture (tap). Safe to call repeatedly.
  unlock() {
    this._ensure();
    if (this.ctx && this.ctx.state !== 'running') this.ctx.resume();
    return this.ctx;
  }

  _ensure(ctxOverride) {
    if (this.ctx && !ctxOverride) return;
    const Ctx = window.AudioContext || window.webkitAudioContext;
    this.ctx = ctxOverride || new Ctx({ latencyHint: 'interactive' });
    const c = this.ctx;
    this.master = c.createGain(); this.master.gain.value = this.muted ? 0 : this.volume;
    const comp = c.createDynamicsCompressor(); comp.threshold.value = -14; comp.knee.value = 18; comp.ratio.value = 4; comp.attack.value = 0.004; comp.release.value = 0.2;
    this.master.connect(comp); comp.connect(c.destination);
    this.musicBus = c.createGain(); this.musicBus.gain.value = 0.9; this.musicBus.connect(this.master);
    this.sfxBus = c.createGain(); this.sfxBus.gain.value = 1.0; this.sfxBus.connect(this.master);
    // shared reverb and delay sends
    this.reverb = c.createConvolver(); this.reverb.buffer = this._impulse(1.9, 2.4);
    const rg = c.createGain(); rg.gain.value = 0.32; this.reverb.connect(rg); rg.connect(this.master);
    this.reverbIn = c.createGain(); this.reverbIn.gain.value = 1; this.reverbIn.connect(this.reverb);
    this.delay = c.createDelay(1); this.delay.delayTime.value = 0.28; const fb = c.createGain(); fb.gain.value = 0.28;
    const df = c.createBiquadFilter(); df.type = 'lowpass'; df.frequency.value = 2400;
    this.delay.connect(df); df.connect(fb); fb.connect(this.delay); const dg = c.createGain(); dg.gain.value = 0.22; df.connect(dg); dg.connect(this.master);
    this.delayIn = c.createGain(); this.delayIn.connect(this.delay);
    // white-noise buffer used by drums and effects
    const len = c.sampleRate; const nb = c.createBuffer(1, len, c.sampleRate); const d = nb.getChannelData(0);
    for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    this._noise = nb;
  }

  _impulse(seconds, decay) {
    const c = this.ctx, len = Math.floor(c.sampleRate * seconds), b = c.createBuffer(2, len, c.sampleRate);
    for (let ch = 0; ch < 2; ch++) { const d = b.getChannelData(ch); for (let i = 0; i < len; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, decay); }
    return b;
  }

  setMuted(m) { this.muted = !!m; if (this.master) this.master.gain.setTargetAtTime(this.muted ? 0 : this.volume, this.ctx.currentTime, 0.05); }
  setVolume(v) { this.volume = Math.max(0, Math.min(1, v)); if (this.master && !this.muted) this.master.gain.setTargetAtTime(this.volume, this.ctx.currentTime, 0.05); }
  setIntensity(x) { this.target = Math.max(0, Math.min(1, x)); }
  pause() { this.paused = true; if (this.ctx && this.ctx.state === 'running') this.ctx.suspend(); }
  resume() { this.paused = false; if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume(); }
  duck(amount = 0.5, seconds = 0.4) { if (!this.musicBus) return; const t = this.ctx.currentTime; this.musicBus.gain.cancelScheduledValues(t); this.musicBus.gain.setTargetAtTime(0.9 * amount, t, 0.02); this.musicBus.gain.setTargetAtTime(0.9, t + seconds, 0.2); }

  play(theme, opts = {}) {
    this._ensure();
    const t = typeof theme === 'string' ? THEMES[theme] : theme;
    if (!t) return;
    this.theme = t; this.rand = mulberry(t.seed || 1); this._buildMelody();
    this.target = opts.intensity !== undefined ? opts.intensity : this.target; this.intensity = this.target;
    this.step = 0; this.nextTime = this.ctx.currentTime + 0.12; this.playing = true;
    this.musicBus.gain.cancelScheduledValues(this.ctx.currentTime); this.musicBus.gain.setTargetAtTime(0.9, this.ctx.currentTime, 0.1);
    if (!this.offline) { clearInterval(this.timer); this.timer = setInterval(() => this._tick(), 25); }
  }

  stop(fade = 1) {
    if (!this.ctx) return;
    this.playing = false; clearInterval(this.timer);
    const t = this.ctx.currentTime; this.musicBus.gain.cancelScheduledValues(t); this.musicBus.gain.setTargetAtTime(0, t, Math.max(0.05, fade / 4));
  }

  _tick() { if (!this.playing || this.paused) return; this.scheduleUntil(this.ctx.currentTime + 0.14); }

  // schedule every 16th-note step that starts before `until` (seconds of audio-clock time)
  scheduleUntil(until) {
    const th = this.theme; if (!th) return;
    const sixteenth = 60 / th.bpm / 4;
    while (this.nextTime < until) {
      this.intensity += (this.target - this.intensity) * 0.02;
      const swingOff = (this.step % 2 === 1) ? th.swing * sixteenth : 0;
      this._playStep(this.step, this.nextTime + swingOff, sixteenth);
      this.nextTime += sixteenth; this.step++;
    }
  }

  // ---- music generation -------------------------------------------------------------------------------
  _scaleNote(degree, octave = 0) {
    const th = this.theme, sc = SCALES[th.scale] || SCALES.major, n = sc.length, root = NOTE[th.root] || 0;
    const o = Math.floor(degree / n), idx = ((degree % n) + n) % n;
    return 48 + root + sc[idx] + 12 * (o + octave);
  }
  _chord(bar) {
    const th = this.theme, deg = th.prog[Math.floor(bar) % th.prog.length];
    const notes = [this._scaleNote(deg), this._scaleNote(deg + 2), this._scaleNote(deg + 4)];
    if (th.seventh) notes.push(this._scaleNote(deg + 6));
    return { deg, notes };
  }
  _buildMelody() {
    // an 8-bar phrase of eighth-note slots; strong beats prefer chord tones
    const th = this.theme, r = this.rand, phrase = [];
    let cur = 4 + Math.floor(r() * 3);
    for (let bar = 0; bar < 8; bar++) {
      const chord = this._chord(bar), bars = [];
      for (let e = 0; e < 8; e++) {
        const strong = e % 2 === 0, rest = r() > (strong ? 0.82 : th.lead && th.lead.density ? th.lead.density * 0.9 : 0.6);
        if (rest && e !== 0) { bars.push(null); continue; }
        const step = [-2, -1, -1, 0, 1, 1, 2][Math.floor(r() * 7)];
        cur = Math.max(2, Math.min(12, cur + step));
        if (strong) {
          const ct = [chord.deg, chord.deg + 2, chord.deg + 4].map((d) => ((d % 7) + 7) % 7 + 7);
          let best = ct[0], bd = 99; for (const c of ct) { const dd = Math.abs(c - cur); if (dd < bd) { bd = dd; best = c; } } cur = best;
        }
        bars.push(cur);
      }
      phrase.push(bars);
    }
    this.phrase = phrase;
  }

  _playStep(step, t, dur) {
    const th = this.theme, I = this.intensity, lv = (th.level || 1);
    const stepInBar = step % 16, bar = Math.floor(step / 16), chord = this._chord(bar);
    const beat = stepInBar % 4 === 0;
    // drums
    if (th.drums && th.drums !== 'none' && I > 0.15) {
      const d = th.drums, g = 0.55 * lv * Math.min(1, I * 1.4);
      if (d === 'fourfloor') { if (beat) this._kick(t, g); if (stepInBar % 8 === 4) this._snare(t, g * 0.8); }
      else if (d === 'half') { if (stepInBar === 0 || stepInBar === 10) this._kick(t, g); if (stepInBar === 8) this._snare(t, g * 0.8); }
      else if (d === 'breakbeat') { if ([0, 6, 10].includes(stepInBar)) this._kick(t, g); if (stepInBar === 4 || stepInBar === 12) this._snare(t, g * 0.9); if (stepInBar === 15 && I > 0.7) this._snare(t, g * 0.4); }
      else if (d === 'swing') { if (stepInBar === 0 || stepInBar === 8) this._kick(t, g * 0.8); if (stepInBar === 4 || stepInBar === 12) this._snare(t, g * 0.5); }
      else if (d === 'soft') { if (stepInBar === 0) this._kick(t, g * 0.6); if (stepInBar === 8) this._clap(t, g * 0.35); }
      if (th.hats && I > 0.35) { if (stepInBar % 2 === 0) this._hat(t, 0.18 * lv, stepInBar % 8 === 6); else if (I > 0.7) this._hat(t, 0.08 * lv, false); }
    }
    // bass
    if (th.bass && I > 0.1) {
      const root = chord.notes[0] - 12, g = 0.5 * lv, style = th.bass;
      if (style === 'root' && beat) this._bass(t, mtof(root), dur * 3.6, g, 'sawtooth');
      else if (style === 'bounce') { if (stepInBar % 4 === 0) this._bass(t, mtof(root), dur * 2.2, g, 'triangle'); else if (stepInBar % 4 === 2) this._bass(t, mtof(root + 12), dur * 1.2, g * 0.7, 'triangle'); }
      else if (style === 'drive') { if (stepInBar % 2 === 0) this._bass(t, mtof(root + (stepInBar % 8 === 6 ? 7 : 0)), dur * 1.7, g, 'sawtooth'); }
      else if (style === 'walk') { if (stepInBar % 4 === 0) { const w = [0, 2, 4, 5][(stepInBar / 4 | 0)]; this._bass(t, mtof(this._scaleNote(chord.deg + w, -1)), dur * 3.4, g, 'triangle'); } }
      else if (style === 'sub' && stepInBar === 0) this._bass(t, mtof(root), dur * 15, g * 0.9, 'sine');
    }
    // pad
    if (th.pad && stepInBar === 0 && I > 0.05) this._pad(t, chord.notes.map((n) => mtof(n + 12)), dur * 16, 0.12 * lv * Math.min(1, 0.5 + I));
    // arpeggio
    if (th.arp && I > 0.3) {
      const pat = th.arp.pattern, idx = pat[stepInBar % pat.length];
      const nn = this._scaleNote(chord.deg + idx, th.arp.oct || 1);
      this._pluck(t, mtof(nn), dur * 1.6, 0.16 * lv * Math.min(1, I), th.arp.wave || 'triangle');
    }
    // bell sparkle on chord change and offbeats
    if (th.bell && I > 0.45 && (stepInBar === 0 || stepInBar === 10)) this._bell(t, mtof(chord.notes[(stepInBar === 0 ? 2 : 1)] + 24), 0.1 * lv);
    // lead melody (every eighth note)
    if (th.lead && I > 0.55 && stepInBar % 2 === 0) {
      const bars = this.phrase[bar % 8], deg = bars[(stepInBar / 2) | 0];
      if (deg !== null && deg !== undefined) this._lead(t, mtof(this._scaleNote(deg, th.lead.oct || 1)), dur * 3.2, 0.17 * lv * Math.min(1, I), th.lead.wave || 'square');
    }
  }

  // ---- voices -------------------------------------------------------------------------------------------
  _out(node, wet = 0.2, echo = 0, bus) { node.connect(bus || this.musicBus); if (wet) { const g = this.ctx.createGain(); g.gain.value = wet; node.connect(g); g.connect(this.reverbIn); } if (echo) { const e = this.ctx.createGain(); e.gain.value = echo; node.connect(e); e.connect(this.delayIn); } }
  _env(g, t, a, d, s, r, peak, dur) { const p = g.gain; p.setValueAtTime(0.0001, t); p.linearRampToValueAtTime(peak, t + a); p.exponentialRampToValueAtTime(Math.max(0.0001, peak * s), t + a + d); p.setTargetAtTime(0.0001, t + dur, r); }
  _osc(type, f, t, stop, detune = 0) { const o = this.ctx.createOscillator(); o.type = type; o.frequency.setValueAtTime(f, t); o.detune.value = detune; o.start(t); o.stop(stop); return o; }
  _kick(t, g) { const c = this.ctx, o = c.createOscillator(), a = c.createGain(); o.type = 'sine'; o.frequency.setValueAtTime(150, t); o.frequency.exponentialRampToValueAtTime(42, t + 0.14); a.gain.setValueAtTime(g * 1.1, t); a.gain.exponentialRampToValueAtTime(0.001, t + 0.26); o.connect(a); this._out(a, 0); o.start(t); o.stop(t + 0.3); }
  _noiseSrc(t, dur) { const s = this.ctx.createBufferSource(); s.buffer = this._noise; s.loop = true; s.start(t, Math.random() * 0.5); s.stop(t + dur); return s; }
  _snare(t, g) { const c = this.ctx, n = this._noiseSrc(t, 0.2), f = c.createBiquadFilter(), a = c.createGain(); f.type = 'highpass'; f.frequency.value = 1400; a.gain.setValueAtTime(g * 0.8, t); a.gain.exponentialRampToValueAtTime(0.001, t + 0.18); n.connect(f); f.connect(a); this._out(a, 0.18);
    const o = c.createOscillator(), b = c.createGain(); o.type = 'triangle'; o.frequency.setValueAtTime(220, t); o.frequency.exponentialRampToValueAtTime(130, t + 0.08); b.gain.setValueAtTime(g * 0.6, t); b.gain.exponentialRampToValueAtTime(0.001, t + 0.12); o.connect(b); this._out(b, 0.1); o.start(t); o.stop(t + 0.15); }
  _clap(t, g) { for (let i = 0; i < 3; i++) { const c = this.ctx, n = this._noiseSrc(t + i * 0.012, 0.1), f = c.createBiquadFilter(), a = c.createGain(); f.type = 'bandpass'; f.frequency.value = 1500; a.gain.setValueAtTime(g * 0.6, t + i * 0.012); a.gain.exponentialRampToValueAtTime(0.001, t + i * 0.012 + 0.09); n.connect(f); f.connect(a); this._out(a, 0.3); } }
  _hat(t, g, open) { const c = this.ctx, n = this._noiseSrc(t, 0.2), f = c.createBiquadFilter(), a = c.createGain(); f.type = 'highpass'; f.frequency.value = 7000; a.gain.setValueAtTime(g, t); a.gain.exponentialRampToValueAtTime(0.001, t + (open ? 0.16 : 0.04)); n.connect(f); f.connect(a); this._out(a, 0.05); }
  _bass(t, f, dur, g, type) { const c = this.ctx, o = this._osc(type, f, t, t + dur + 0.2), lp = c.createBiquadFilter(), a = c.createGain(); lp.type = 'lowpass'; lp.frequency.setValueAtTime(type === 'sine' ? 400 : 700 + 600 * this.intensity, t); lp.frequency.exponentialRampToValueAtTime(220, t + dur); this._env(a, t, 0.008, 0.12, 0.7, 0.04, g, dur); o.connect(lp); lp.connect(a); this._out(a, 0); if (type !== 'sine') { const s = this._osc('sine', f, t, t + dur + 0.2), sg = c.createGain(); this._env(sg, t, 0.01, 0.1, 0.8, 0.04, g * 0.6, dur); s.connect(sg); this._out(sg, 0); } }
  _pad(t, freqs, dur, g) { const c = this.ctx; for (const f of freqs) for (const dt of [-9, 9]) { const o = this._osc('sawtooth', f, t, t + dur + 1.2, dt), lp = c.createBiquadFilter(), a = c.createGain(); lp.type = 'lowpass'; lp.frequency.setValueAtTime(500, t); lp.frequency.linearRampToValueAtTime(1500, t + dur * 0.5); lp.frequency.linearRampToValueAtTime(700, t + dur); this._env(a, t, 0.5, 0.4, 0.8, 0.5, g / freqs.length * 1.6, dur); o.connect(lp); lp.connect(a); this._out(a, 0.45); } }
  _pluck(t, f, dur, g, type) { const c = this.ctx, o = this._osc(type, f, t, t + dur + 0.2), lp = c.createBiquadFilter(), a = c.createGain(); lp.type = 'lowpass'; lp.frequency.setValueAtTime(3600, t); lp.frequency.exponentialRampToValueAtTime(700, t + dur); this._env(a, t, 0.004, 0.08, 0.35, 0.05, g, dur * 0.7); o.connect(lp); lp.connect(a); this._out(a, 0.25, 0.22); }
  _lead(t, f, dur, g, type) { const c = this.ctx, o = this._osc(type, f, t, t + dur + 0.3), lp = c.createBiquadFilter(), a = c.createGain(); const lfo = c.createOscillator(), lg = c.createGain(); lfo.frequency.value = 5.2; lg.gain.value = f * 0.006; lfo.connect(lg); lg.connect(o.frequency); lfo.start(t); lfo.stop(t + dur + 0.3); lp.type = 'lowpass'; lp.frequency.value = 2800; this._env(a, t, 0.015, 0.1, 0.65, 0.09, g, dur); o.connect(lp); lp.connect(a); this._out(a, 0.35, 0.3); }
  _bell(t, f, g) { const c = this.ctx; for (const [m, v] of [[1, 1], [2.76, 0.4], [5.4, 0.18]]) { const o = this._osc('sine', f * m, t, t + 1.6), a = c.createGain(); this._env(a, t, 0.002, 0.5, 0.1, 0.25, g * v, 0.35); o.connect(a); this._out(a, 0.6, 0.3); } }

  // ---- sound effects ------------------------------------------------------------------------------------
  // names: click coin jump hit boom laser pop whoosh win lose splash boing squeak powerup sparkle dice step hurt shoot swish
  sfx(name, o = {}) {
    if (!this.ctx || this.ctx.state === 'closed') return;
    const c = this.ctx, t = c.currentTime + 0.005, v = (o.volume === undefined ? 1 : o.volume), pitch = o.pitch || 1;
    const tone = (type, f0, f1, dur, g, a = 0.003) => { const os = c.createOscillator(), ga = c.createGain(); os.type = type; os.frequency.setValueAtTime(f0 * pitch, t); if (f1) os.frequency.exponentialRampToValueAtTime(Math.max(20, f1 * pitch), t + dur); ga.gain.setValueAtTime(0.0001, t); ga.gain.linearRampToValueAtTime(g * v, t + a); ga.gain.exponentialRampToValueAtTime(0.0001, t + dur); os.connect(ga); this._out(ga, 0.12, 0, this.sfxBus); os.start(t); os.stop(t + dur + 0.05); };
    const noise = (ft, f0, f1, dur, g) => { const n = this._noiseSrc(t, dur), fl = c.createBiquadFilter(), ga = c.createGain(); fl.type = ft; fl.frequency.setValueAtTime(f0, t); if (f1) fl.frequency.exponentialRampToValueAtTime(f1, t + dur); ga.gain.setValueAtTime(g * v, t); ga.gain.exponentialRampToValueAtTime(0.0001, t + dur); n.connect(fl); fl.connect(ga); this._out(ga, 0.15, 0, this.sfxBus); };
    switch (name) {
      case 'click': tone('square', 900, 700, 0.05, 0.12); break;
      case 'coin': tone('square', 988, 988, 0.07, 0.14); setTimeout(() => this.sfx('_coin2', o), 70); break;
      case '_coin2': tone('square', 1319, 1319, 0.28, 0.14); break;
      case 'jump': tone('sine', 300, 720, 0.18, 0.28); break;
      case 'hit': noise('lowpass', 2400, 300, 0.16, 0.5); tone('sine', 180, 60, 0.14, 0.4); break;
      case 'hurt': tone('sawtooth', 260, 90, 0.28, 0.3); noise('bandpass', 1500, 400, 0.2, 0.3); break;
      case 'boom': noise('lowpass', 1800, 80, 0.7, 0.9); tone('sine', 90, 28, 0.6, 0.8); break;
      case 'laser': tone('sawtooth', 1800, 220, 0.2, 0.22); break;
      case 'shoot': tone('square', 900, 150, 0.12, 0.2); noise('highpass', 3000, 3000, 0.06, 0.2); break;
      case 'pop': tone('sine', 700, 200, 0.09, 0.3); break;
      case 'whoosh': noise('bandpass', 400, 3200, 0.38, 0.35); break;
      case 'swish': noise('bandpass', 2500, 700, 0.2, 0.25); break;
      case 'splash': noise('bandpass', 1200, 500, 0.5, 0.45); noise('highpass', 5000, 2000, 0.3, 0.2); break;
      case 'boing': { const os = c.createOscillator(), ga = c.createGain(), lf = c.createOscillator(), lg = c.createGain(); os.type = 'sine'; os.frequency.setValueAtTime(220 * pitch, t); os.frequency.exponentialRampToValueAtTime(520 * pitch, t + 0.12); os.frequency.exponentialRampToValueAtTime(160 * pitch, t + 0.5); lf.frequency.value = 22; lg.gain.value = 30; lf.connect(lg); lg.connect(os.frequency); ga.gain.setValueAtTime(0.35 * v, t); ga.gain.exponentialRampToValueAtTime(0.0001, t + 0.55); os.connect(ga); this._out(ga, 0.12, 0, this.sfxBus); os.start(t); lf.start(t); os.stop(t + 0.6); lf.stop(t + 0.6); break; }
      case 'squeak': tone('triangle', 1400, 2400, 0.1, 0.22); setTimeout(() => this.sfx('_sq2', o), 90); break;
      case '_sq2': tone('triangle', 1800, 1200, 0.12, 0.2); break;
      case 'powerup': [0, 4, 7, 12, 16].forEach((s, i) => setTimeout(() => this.sfx('_note', { pitch: Math.pow(2, s / 12), volume: o.volume }), i * 55)); break;
      case '_note': tone('square', 523, 523, 0.16, 0.16); break;
      case 'sparkle': [0, 5, 9, 14, 17].forEach((s, i) => setTimeout(() => { const f = 1568 * Math.pow(2, s / 12); this._bell(c.currentTime + 0.002, f, 0.12 * v); }, i * 45)); break;
      case 'win': [0, 4, 7, 12, 7, 12, 16].forEach((s, i) => setTimeout(() => this.sfx('_note', { pitch: Math.pow(2, s / 12), volume: o.volume }), i * 110)); break;
      case 'lose': [0, -2, -4, -7].forEach((s, i) => setTimeout(() => this.sfx('_note', { pitch: Math.pow(2, (s - 5) / 12), volume: o.volume }), i * 160)); break;
      case 'dice': for (let i = 0; i < 6; i++) setTimeout(() => { tone('triangle', 500 + Math.random() * 500, 0, 0.04, 0.22); noise('bandpass', 2500, 0, 0.03, 0.18); }, i * 70 + Math.random() * 25); break;
      case 'step': noise('lowpass', 900, 200, 0.06, 0.18); break;
      default: tone('sine', 600, 0, 0.1, 0.2);
    }
  }

  // Renders `seconds` of a theme to an AudioBuffer without playing it (used by the automated tests).
  static async renderTheme(theme, seconds = 12, intensity = 0.9) {
    const sr = 44100, off = new OfflineAudioContext(2, sr * seconds, sr), m = new Maestro();
    m.offline = true; m._ensure(off); m.volume = 0.8; m.master.gain.value = 0.8;
    m.theme = typeof theme === 'string' ? THEMES[theme] : theme; m.rand = mulberry(m.theme.seed || 1); m._buildMelody();
    m.intensity = m.target = intensity; m.step = 0; m.nextTime = 0.05; m.playing = true; m.scheduleUntil(seconds - 0.2);
    return off.startRendering();
  }
}
