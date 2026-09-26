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
      data: { url: data.url || '/' },
    })
  )
})

// Bildirime dokununca: açık bir uygulama penceresi varsa öne getirilir VE
// yeniden yüklenir (böylece her zaman en güncel sürüm açılır — ör.
// "Version 7.2" duyurusu veya 17:45 raporu); yoksa yeni pencere açılır.
self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const url = (event.notification.data && event.notification.data.url) || '/'
  event.waitUntil((async () => {
    const clientsArr = await self.clients.matchAll({ type: 'window', includeUncontrolled: true })
    const existing = clientsArr.find((c) => 'focus' in c)
    if (!existing) return self.clients.openWindow(url)
    try { await existing.focus() } catch (e) {}
    try { if ('navigate' in existing) await existing.navigate(url) } catch (e) {}
  })())
})
