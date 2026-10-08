/**
 * sw.js - Ziva Finance Cache Hygiene Service Worker
 * Strictly excludes any private financial data and /api/ endpoints from caching.
 */

const CACHE_NAME = 'ziva-static-v1';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/favicon.svg'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS);
    })
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))
      );
    })
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // CRITICAL RULE: Never cache API requests, authentication routes, or receipts
  if (url.pathname.startsWith('/api') || event.request.method !== 'GET') {
    return; // Pass through directly to network
  }

  event.respondWith(
    caches.match(event.request).then((cached) => {
      return cached || fetch(event.request);
    })
  );
});

// Allow client to order immediate cache clearance (e.g., on logout)
self.addEventListener('message', (event) => {
  if (event.data && event.data.action === 'CLEAR_PRIVATE_CACHES') {
    caches.keys().then((keys) => {
      return Promise.all(keys.map((k) => caches.delete(k)));
    });
  }
});
