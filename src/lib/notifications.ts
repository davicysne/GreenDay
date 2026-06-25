import { supabase } from './supabase'
import { setUserItem } from './userStorage'

const urlBase64ToUint8Array = (value: string) => {
  const padding = '='.repeat((4 - value.length % 4) % 4)
  const base64 = (value + padding).replace(/-/g, '+').replace(/_/g, '/')
  return Uint8Array.from(atob(base64), char => char.charCodeAt(0))
}

export async function enablePush(userId: string) {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) throw new Error('Push notifications are not supported on this device.')
  const permission = await Notification.requestPermission()
  if (permission !== 'granted') throw new Error('Notification permission was not granted.')
  const registration = await navigator.serviceWorker.ready
  const publicKey = import.meta.env.VITE_VAPID_PUBLIC_KEY
  if (!publicKey) return { demo: true, permission }
  const subscription = await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: urlBase64ToUint8Array(publicKey) })
  const json = subscription.toJSON()
  if (supabase) {
    const { error } = await supabase.from('push_subscriptions').upsert({
      user_id: userId, endpoint: json.endpoint, p256dh: json.keys?.p256dh, auth: json.keys?.auth,
    }, { onConflict: 'endpoint' })
    if (error) throw error
  }
  return { demo: !supabase, permission }
}

export async function saveNotificationPreferences(userId: string, values: { enabled: boolean, first_notification_time: string, second_notification_time: string, timezone: string }) {
  setUserItem(userId, 'notifications', values)
  if (!supabase) return
  const { error } = await supabase.from('notification_preferences').upsert({ user_id: userId, ...values }, { onConflict: 'user_id' })
  if (error) throw error
}
