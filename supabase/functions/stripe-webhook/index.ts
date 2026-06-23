import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, { apiVersion: '2023-10-16' })
const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

Deno.serve(async req => {
  const signature = req.headers.get('stripe-signature')
  if (!signature) return new Response('Missing signature', { status: 400 })
  try {
    const body = await req.text()
    const event = await stripe.webhooks.constructEventAsync(body, signature, Deno.env.get('STRIPE_WEBHOOK_SECRET')!)
    if (['checkout.session.completed','customer.subscription.updated','customer.subscription.deleted'].includes(event.type)) {
      const object = event.data.object as Stripe.Checkout.Session | Stripe.Subscription
      let userId = 'client_reference_id' in object ? object.client_reference_id : object.metadata.user_id
      let subscription: Stripe.Subscription | null = null
      if ('subscription' in object && object.subscription) subscription = await stripe.subscriptions.retrieve(String(object.subscription))
      else if (object.object === 'subscription') subscription = object
      const status = subscription?.status === 'canceled' ? 'cancelled' : (subscription?.status || 'active')
      await admin.from('subscriptions').upsert({
        user_id: userId, plan_name: object.metadata?.plan || subscription?.metadata.plan || 'premium',
        billing_cycle: object.metadata?.plan || subscription?.metadata.plan || 'lifetime', status,
        currency: subscription?.currency?.toUpperCase() || ('currency' in object ? object.currency?.toUpperCase() : 'USD'),
        amount: subscription?.items.data[0]?.price.unit_amount ? subscription.items.data[0].price.unit_amount! / 100 : ('amount_total' in object ? (object.amount_total || 0) / 100 : 0),
        stripe_customer_id: String(object.customer), stripe_subscription_id: subscription?.id || null,
        current_period_start: subscription ? new Date(subscription.current_period_start * 1000).toISOString() : new Date().toISOString(),
        current_period_end: subscription ? new Date(subscription.current_period_end * 1000).toISOString() : null,
        updated_at: new Date().toISOString(),
      }, { onConflict: 'user_id' })
    }
    return Response.json({ received: true })
  } catch (error) { return new Response(error.message, { status: 400 }) }
})
