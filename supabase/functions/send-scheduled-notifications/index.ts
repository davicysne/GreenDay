import webpush from 'https://esm.sh/web-push@3.6.7'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
webpush.setVapidDetails(Deno.env.get('VAPID_SUBJECT')!, Deno.env.get('VAPID_PUBLIC_KEY')!, Deno.env.get('VAPID_PRIVATE_KEY')!)
const messages = [
  'How are you feeling right now?', 'Take a moment to check in with yourself.',
  'You are building a better version of yourself today.', 'One more day of progress. Stay strong.', 'Remember why you started.',
]

Deno.serve(async req => {
  if (req.headers.get('x-cron-secret') !== Deno.env.get('CRON_SECRET')) return new Response('Unauthorized', { status: 401 })
  const { data: preferences, error } = await admin.from('notification_preferences').select('user_id,first_notification_time,second_notification_time,timezone').eq('enabled', true)
  if (error) return Response.json({ error: error.message }, { status: 500 })
  let sent = 0
  for (const preference of preferences || []) {
    const localTime = new Intl.DateTimeFormat('en-GB', { timeZone: preference.timezone, hour: '2-digit', minute: '2-digit', hour12: false }).format(new Date())
    const localDate = new Intl.DateTimeFormat('en-CA', { timeZone: preference.timezone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(new Date())
    const first = preference.first_notification_time.slice(0,5), second = preference.second_notification_time.slice(0,5)
    if (localTime !== first && localTime !== second) continue
    const body = messages[Math.floor(Math.random()*messages.length)]
    const { data: notification, error: notificationError } = await admin.from('notifications').insert({
      user_id: preference.user_id, kind: 'reminder', title: 'Green Day', body,
      scheduled_for: new Date().toISOString(), dedupe_key: `${preference.user_id}:${localDate}:${localTime}`,
    }).select('id').single()
    if (notificationError?.code === '23505') continue
    if (notificationError) console.error('Could not create notification history', notificationError)
    const { data: devices } = await admin.from('push_subscriptions').select('endpoint,p256dh,auth').eq('user_id', preference.user_id)
    let delivered = false
    for (const device of devices || []) {
      try {
        await webpush.sendNotification({ endpoint: device.endpoint, keys: { p256dh: device.p256dh, auth: device.auth } }, JSON.stringify({ title: 'Green Day', body }))
        sent++; delivered = true
      } catch (pushError) {
        if ([404,410].includes(pushError.statusCode)) await admin.from('push_subscriptions').delete().eq('endpoint', device.endpoint)
      }
    }
    if (notification?.id && delivered) await admin.from('notifications').update({ delivered_at: new Date().toISOString() }).eq('id', notification.id)
  }
  return Response.json({ sent })
})
