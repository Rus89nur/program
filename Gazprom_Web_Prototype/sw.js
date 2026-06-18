const CACHE_NAME = 'gazprom-web-v236';
const IS_LOCALHOST = self.location.hostname === 'localhost' || self.location.hostname === '127.0.0.1';
const STATIC_ASSETS = [
  './manifest.json',
  './css/app.css?v=224',
  './js/idb-connection.js?v=22',
  './js/file-utils.js?v=1',
  './js/data-store.js?v=28',
  './js/photo-store.js?v=31',
  './js/akt-utils.js?v=32',
  './js/toast.js?v=2',
  './js/mobile-overlay.js?v=36',
  './js/violation-search.js?v=3',
  './js/photo-lightbox.js?v=1',
  './js/wizard-violations-ui.js?v=2',
  './js/violation-templates.js?v=21',
  './js/violation-types.js?v=13',
  './js/violation-types-editor.js?v=12',
  './js/ml-image-service.js?v=6',
  './js/ml-training-wizard.js?v=10',
  './js/ui-bindings.js?v=37',
  './js/doc-generator.js?v=44',
  './js/template-builder-wizard.js?v=3',
  './js/defaults-bootstrap.js?v=14',
  './js/violation-registry.js?v=16',
  './js/catalog-service.js?v=2',
  './js/backup-import.js?v=32',
  './js/akt-search.js',
  './js/catalog-editor.js?v=13',
  './js/schedule-editor.js?v=2',
  './js/elimination-editor.js?v=12',
  './js/wizard-modals.js?v=50',
  './js/wizard.js?v=59',
  './js/spravka-utils.js?v=4',
  './js/spravka-wizard.js?v=12',
  './js/short-akt-form.js?v=4',
  './js/report-exporter.js?v=2',
  './js/reports-dashboard.js?v=17',
  './js/app.js?v=161',
  './assets/sample-demo.gazprombackup',
  './assets/defaults/manifest.json',
  './assets/defaults/violation-registry.json',
  './assets/defaults/akt-template.docx',
  './assets/defaults/Шаблон_справки_ПБ.docx',
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
      .then(() => self.clients.matchAll({ type: 'window', includeUncontrolled: true }))
      .then((clients) => {
        clients.forEach((client) => {
          client.postMessage({ type: 'GAZPROM_SW_ACTIVATED', cache: CACHE_NAME });
        });
      })
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
  const isAppAsset =
    isFreshShell ||
    request.destination === 'script' ||
    request.destination === 'style' ||
    /\.(js|css|html)(\?|$)/i.test(url.pathname);

  if (isAppAsset) {
    event.respondWith(
      fetch(request, { cache: 'no-store' })
        .then((response) => {
          if (response && response.status === 200 && response.type === 'basic' && !isFreshShell) {
            const clone = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(request, clone));
          }
          return response;
        })
        .catch(() => caches.match(request))
    );
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
