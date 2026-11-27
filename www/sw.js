/* Service worker MorseLab (version web uniquement).
   Réseau d'abord pour tous les fichiers de l'app (les mises à jour arrivent tout de suite),
   copie en cache pour fonctionner hors ligne. Les appels Supabase (autre domaine) ne passent pas par ici. */
const CACHE = 'morselab-v2';
const SHELL = ['./', './index.html', './config.js', './vendor/supabase.js', './manifest.webmanifest',
  './icons/icon-192.png', './icons/icon-512.png', './icons/apple-touch-icon.png', './icons/favicon-32.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return;
  const key = req.mode === 'navigate' ? './index.html' : req;
  e.respondWith(fetch(req).then(r => {
    if (r.ok) { const copy = r.clone(); caches.open(CACHE).then(c => c.put(key, copy)); }
    return r;
  }).catch(() => caches.match(key).then(hit => hit || caches.match('./index.html'))));
});
