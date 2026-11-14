// Caches the whole game so it opens instantly and works offline. VERSION is replaced with the commit id at build time.
const VERSION = 'dev';
const CACHE = 'pocketboy-' + VERSION;
const FILES = ['./', 'index.html', 'app.js', 'engine.js', 'style.css', 'pocketweb.wasm', 'manifest.webmanifest', 'icon-180.png', 'icon-512.png'];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(FILES)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k.startsWith('pocketboy-') && k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  event.respondWith(
    caches.match(event.request).then((hit) => hit || fetch(event.request).then((resp) => {
      if (resp && resp.ok && new URL(event.request.url).origin === location.origin) {
        const copy = resp.clone();
        caches.open(CACHE).then((cache) => cache.put(event.request, copy));
      }
      return resp;
    }))
  );
});
