self.addEventListener('install', () => self.skipWaiting())
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()))

// Uygulama her zaman canlı Supabase verisiyle çalışır; burada offline önbellekleme
// yapılmıyor, sadece PWA kurulabilirlik şartı için bir fetch handler tutuluyor.
self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request))
})

// Gün sonu bildirimi (otomatik, Edge Function üzerinden gönderiliyor).
self.addEventListener('push', (event) => {
  let data = { title: 'Atölye İş Takip', body: 'Neue Benachrichtigung' }
  try { data = event.data.json() } catch(e) {}
  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      icon: '/icons/icon-192.png',
      badge: '/icons/icon-192.png',
    })
  )
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  event.waitUntil(
    self.clients.matchAll({ type: 'window' }).then((clientsArr) => {
      const existing = clientsArr.find((c) => 'focus' in c)
      if (existing) return existing.focus()
      return self.clients.openWindow('/')
    })
  )
})
