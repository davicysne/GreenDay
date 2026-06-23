const CACHE = 'green-day-v2'
const APP_SHELL = ['/', '/manifest.webmanifest', '/favicon.png']

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(APP_SHELL)))
  self.skipWaiting()
})

self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key)))))
  self.clients.claim()
})

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return
  event.respondWith(fetch(event.request).then(response => {
    const copy = response.clone()
    caches.open(CACHE).then(cache => cache.put(event.request, copy))
    return response
  }).catch(() => caches.match(event.request).then(hit => hit || caches.match('/'))))
})

self.addEventListener('push', event => {
  const fallback = { title: 'Green Day', body: 'Take a moment to check in with yourself.' }
  let data = fallback
  try { data = { ...fallback, ...event.data.json() } } catch { /* use fallback */ }
  event.waitUntil(self.registration.showNotification(data.title, {
    body: data.body,
    icon: '/favicon.png', badge: '/favicon.png', tag: 'green-day-checkin',
    data: { url: '/?page=journal&quick=true' }, vibrate: [100, 50, 100]
  }))
})

self.addEventListener('notificationclick', event => {
  event.notification.close()
  event.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then(windows => {
    const existing = windows.find(windowClient => 'focus' in windowClient)
    return existing ? existing.navigate('/?page=journal&quick=true').then(client => client.focus()) : clients.openWindow('/?page=journal&quick=true')
  }))
})
