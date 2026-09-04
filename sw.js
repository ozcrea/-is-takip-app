self.addEventListener('install', () => self.skipWaiting())
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()))

// Uygulama her zaman canlı Supabase verisiyle çalışır; burada offline önbellekleme
// yapılmıyor, sadece PWA kurulabilirlik şartı için bir fetch handler tutuluyor.
self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request))
})
