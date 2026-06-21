const BUILD = '5.3.0+1-422df63';
let isUpdate = false;

self.addEventListener('install', (event) => {
  isUpdate = !!self.registration.active;
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(keys.map((key) => caches.delete(key)));
    }).then(() => {
      return self.clients.claim();
    }).then(() => {
      if (isUpdate) {
        return self.clients.matchAll().then((clients) => {
          clients.forEach((client) => {
            client.postMessage({ type: 'NEW_VERSION', version: '5.3.0+1-422df63' });
          });
        });
      }
    })
  );
});

self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request));
});