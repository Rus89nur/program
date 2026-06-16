const CACHE_NAME = 'gazprom-web-v186';
const IS_LOCALHOST = self.location.hostname === 'localhost' || self.location.hostname === '127.0.0.1';
const STATIC_ASSETS = [
  './manifest.json',
  './css/app.css?v=161',
  './js/idb-connection.js?v=21',
  './js/data-store.js?v=25',
  './js/photo-store.js?v=31',
  './js/akt-utils.js?v=29',
  './js/toast.js',
  './js/mobile-overlay.js?v=34',
  './js/violation-search.js?v=3',
  './js/violation-templates.js?v=21',
  './js/violation-types.js?v=4',
  './js/violation-types-editor.js?v=6',
  './js/defaults-bootstrap.js?v=6',
  './js/violation-registry.js?v=13',
  './js/catalog-service.js',
  './js/backup-import.js?v=30',
  './js/akt-search.js',
  './js/ui-bindings.js?v=32',
  './js/catalog-editor.js?v=13',
  './js/schedule-editor.js?v=2',
  './js/elimination-editor.js?v=8',
  './js/wizard-modals.js?v=43',
  './js/wizard.js?v=56',
  './js/short-akt-form.js?v=3',
  './js/doc-generator.js?v=36',
  './js/report-exporter.js?v=2',
  './js/reports-dashboard.js?v=12',
  './js/app.js?v=137',
  './assets/sample-demo.gazprombackup',
  './assets/defaults/manifest.json',
  './assets/defaults/violation-registry.json',
  './assets/defaults/akt-template.docx',
  './assets/defaults/violation-registry.xlsx',
  './assets/vendor/xlsx.full.min.js',
  './assets/vendor/pizzip.min.js',
  './assets/vendor/docxtemplater.js',
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

  const isFreshShell =
    request.mode === 'navigate' ||
    request.destination === 'document' ||
    url.pathname.endsWith('/sw.js');
  if (isFreshShell) {
    event.respondWith(fetch(request, { cache: 'no-store' }));
    return;
  }

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
