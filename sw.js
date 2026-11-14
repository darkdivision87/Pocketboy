// Caches the whole game so it opens instantly and works offline. VERSION is replaced with the commit id at build time.
const VERSION = '8bb4d685760050a3951748255a1b048932dd710f';
const CACHE = 'pocketboy-' + VERSION;
const FILES = ['./', 'index.html', 'app.js', 'engine.js', 'style.css', 'pocketweb.wasm', 'manifest.webmanifest', 'icon-180.png', 'icon-512.png',
  'ipad/', 'ipad/index.html', 'ipad/ipad.css', 'ipad/ipad.js', 'ipad/manifest.webmanifest', 'ipad/icon-180.png', 'ipad/icon-512.png'];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(FILES)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k.startsWith('pocketboy-') && k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// Network first: always pick up the newest game when online, and fall back to the saved copy when offline.
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  if (new URL(event.request.url).origin !== location.origin) return;
  event.respondWith(
    fetch(event.request).then((resp) => {
      if (resp && resp.ok) {
        const copy = resp.clone();
        caches.open(CACHE).then((cache) => cache.put(event.request, copy));
      }
      return resp;
    }).catch(() => caches.match(event.request))
  );
});
