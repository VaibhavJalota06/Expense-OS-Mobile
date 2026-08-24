const CACHE_NAME = 'expense-os-pwa-v3.9.4';
const STATIC_ASSETS = [
  './',
  './index.html',
  './style.css?v=3.9.4',
  './supabase-config.js?v=3.9.4',
  './js/state.js?v=3.9.4',
  './js/ui.js?v=3.9.4',
  './js/features.js?v=3.9.4',
  './js/gamification.js?v=3.9.4',
  './auth.js?v=3.9.4',
  './icon.png',
  './manifest.json'
];

// Install: Pre-cache core shell
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS).catch((err) => {
        console.warn('PWA: Some static assets failed to pre-cache:', err);
      });
    })
  );
  self.skipWaiting();
});

// Activate: Clean up old versions
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((name) => {
          if (name !== CACHE_NAME) {
            console.log('PWA: Purging old cache:', name);
            return caches.delete(name);
          }
        })
      );
    })
  );
  self.clients.claim();
});

// Fetch: Stale-while-revalidate for local assets, network-first for external APIs
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Skip non-GET requests and Supabase / Google OAuth API calls from cache
  if (event.request.method !== 'GET' || url.origin.includes('supabase.co') || url.origin.includes('googleapis.com') || url.origin.includes('api.emailjs.com')) {
    return;
  }

  // HTML Navigation: Network-First with Cache Fallback (for instant offline access)
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request)
        .then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            const copy = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
          }
          return networkResponse;
        })
        .catch(() => {
          return caches.match('./index.html') || caches.match('./');
        })
    );
    return;
  }

  // Static Assets (CSS, JS, Fonts, Images): Stale-While-Revalidate
  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      const fetchPromise = fetch(event.request).then((networkResponse) => {
        if (networkResponse && networkResponse.status === 200) {
          const copy = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
        }
        return networkResponse;
      }).catch((err) => {
        // Network failed, nothing to revalidate
      });

      return cachedResponse || fetchPromise;
    })
  );
});

// Listen for message events (e.g. skipWaiting from client UI update toast)
self.addEventListener('message', (event) => {
  if (event.data && event.data.action === 'skipWaiting') {
    self.skipWaiting();
  }
});
