// Loads the PocketCore WebAssembly module and wraps its pb_* exports. Works in browsers and in Node.
const ERRNO_BADF = 8;
const ERRNO_NOSYS = 52;

export async function loadEngine(bytes) {
  const module = await WebAssembly.compile(bytes);
  let memory = null;
  const view = () => new DataView(memory.buffer);

  const impl = {
    random_get(ptr, len) {
      const out = new Uint8Array(memory.buffer, ptr, len);
      for (let i = 0; i < len; i++) out[i] = (Math.random() * 256) | 0;
      return 0;
    },
    clock_time_get(id, precision, outPtr) {
      const ns = BigInt(Math.floor((typeof performance !== 'undefined' ? performance.now() : Date.now()) * 1e6));
      view().setBigUint64(outPtr, ns, true);
      return 0;
    },
    clock_res_get(id, outPtr) { view().setBigUint64(outPtr, 1000n, true); return 0; },
    fd_write(fd, iovs, iovsLen, nwrittenPtr) {
      const v = view();
      let total = 0;
      for (let i = 0; i < iovsLen; i++) total += v.getUint32(iovs + i * 8 + 4, true);
      v.setUint32(nwrittenPtr, total, true);
      return 0;
    },
    environ_sizes_get(countPtr, sizePtr) { const v = view(); v.setUint32(countPtr, 0, true); v.setUint32(sizePtr, 0, true); return 0; },
    args_sizes_get(countPtr, sizePtr) { const v = view(); v.setUint32(countPtr, 0, true); v.setUint32(sizePtr, 0, true); return 0; },
    environ_get() { return 0; },
    args_get() { return 0; },
    fd_close() { return 0; },
    fd_fdstat_get(fd, ptr) { new Uint8Array(memory.buffer, ptr, 24).fill(0); return 0; },
    fd_prestat_get() { return ERRNO_BADF; },
    fd_prestat_dir_name() { return ERRNO_BADF; },
    fd_seek() { return ERRNO_BADF; },
    fd_read() { return ERRNO_BADF; },
    sched_yield() { return 0; },
    proc_exit(code) { throw new Error('proc_exit ' + code); },
  };

  const imports = {};
  for (const imp of WebAssembly.Module.imports(module)) {
    if (!imports[imp.module]) imports[imp.module] = {};
    if (imp.kind === 'function') {
      imports[imp.module][imp.name] = impl[imp.name] || (() => ERRNO_NOSYS);
    }
  }

  const instance = await WebAssembly.instantiate(module, imports);
  const ex = instance.exports;
  memory = ex.memory;
  if (ex._initialize) ex._initialize();

  const decoder = new TextDecoder();
  return {
    ex,
    get memory() { return memory; },
    text(index, field) {
      const len = ex.pb_cart_text(index, field);
      return decoder.decode(new Uint8Array(memory.buffer, ex.pb_scratch(), len));
    },
    cartridges() {
      const list = [];
      const n = ex.pb_cart_count();
      for (let i = 0; i < n; i++) {
        list.push({
          index: i,
          id: this.text(i, 0),
          title: this.text(i, 1),
          genre: this.text(i, 2),
          blurb: this.text(i, 3),
          controls: this.text(i, 4),
          era: this.text(i, 5),
          top: '#' + (ex.pb_cart_label(i, 0) >>> 0).toString(16).padStart(6, '0'),
          bottom: '#' + (ex.pb_cart_label(i, 1) >>> 0).toString(16).padStart(6, '0'),
        });
      }
      return list;
    },
    frame() {
      const w = ex.pb_width();
      const h = ex.pb_height();
      return { w, h, data: new Uint8ClampedArray(memory.buffer, ex.pb_frame_ptr(), w * h * 4) };
    },
    audio(frames) {
      ex.pb_audio(frames);
      return new Float32Array(memory.buffer, ex.pb_audio_ptr(), frames);
    },
  };
}
