const CACHE_NAME = 'cast-v1';
const SHELL_ASSETS = [
  '/apps/cast/',
  '/apps/cast/css/app.css',
  '/apps/cast/js/api.js',
  '/apps/cast/js/app.js',
  '/apps/cast/js/player.js',
  '/apps/cast/js/s3.js',
  '/apps/cast/js/discover.js',
];

self.addEventListener('install', (e) => {
  e.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(SHELL_ASSETS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const url = new URL(e.request.url);

  // Network only for API calls and pokes
  if (url.pathname.includes('/api/') || url.pathname.includes('/spider/')) {
    return;
  }

  // Skip audio streams
  if (e.request.url.includes('.mp3') || e.request.url.includes('.m4a') || e.request.url.includes('.ogg')) {
    return;
  }

  // Cache first for app shell, then network
  e.respondWith(
    caches.match(e.request).then(cached => {
      const fetched = fetch(e.request).then(response => {
        // Update cache with fresh version
        if (response.ok) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(e.request, clone));
        }
        return response;
      }).catch(() => cached);

      return cached || fetched;
    })
  );
});
