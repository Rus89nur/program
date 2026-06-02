const CACHE_NAME = 'gazprom-web-v7';
const IS_LOCALHOST = self.location.hostname === 'localhost' || self.location.hostname === '127.0.0.1';
const STATIC_ASSETS = [
  './',
  './index.html',
  './manifest.json',
  './css/app.css',
  './js/data-store.js',
  './js/photo-store.js',
  './js/akt-utils.js',
  './js/toast.js',
  './js/violation-templates.js',
  './js/violation-registry.js',
  './js/catalog-service.js',
  './js/backup-import.js',
  './js/akt-search.js',
  './js/ui-bindings.js',
  './js/catalog-editor.js',
  './js/schedule-editor.js',
  './js/elimination-editor.js',
  './js/wizard-modals.js',
  './js/wizard.js',
  './js/doc-generator.js',
  './js/report-exporter.js',
  './js/app.js',
  './assets/sample-demo.gazprombackup',
];

self.addEventListener('install', (event) => {
  if (IS_LOCALHOST) {
    event.waitUntil(self.skipWaiting());
    return;
  }
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(STATIC_ASSETS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  if (IS_LOCALHOST) {
    event.waitUntil(
      caches.keys()
        .then((keys) => Promise.all(keys.map((k) => caches.delete(k))))
        .then(() => self.registration.unregister())
        .then(() => self.clients.matchAll({ type: 'window', includeUncontrolled: true }))
        .then((clients) => Promise.all(clients.map((client) => client.navigate(client.url))))
    );
    return;
  }
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

// Стратегия: Network First — всегда берём свежий файл с сервера,
// кэш используется только если сеть недоступна (офлайн-режим).
self.addEventListener('fetch', (event) => {
  if (IS_LOCALHOST) return;
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  event.respondWith(
    fetch(request)
      .then((response) => {
        if (response && response.status === 200 && response.type === 'basic') {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
        }
        return response;
      })
      .catch(() => caches.match(request))
  );
});
