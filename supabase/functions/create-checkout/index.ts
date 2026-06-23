import Stripe from 'https://esm.sh/stripe@14.21.0?target=deno'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, { apiVersion: '2023-10-16' })
const prices: Record<string, string | undefined> = {
  monthly: Deno.env.get('STRIPE_PRICE_MONTHLY'), semiannual: Deno.env.get('STRIPE_PRICE_SEMIANNUAL'),
  annual: Deno.env.get('STRIPE_PRICE_ANNUAL'), lifetime: Deno.env.get('STRIPE_PRICE_LIFETIME'),
}

Deno.serve(async req => {
  const headers = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type' }
  if (req.method === 'OPTIONS') return new Response('ok', { headers })
  try {
    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: req.headers.get('Authorization')! } } })
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return new Response('Unauthorized', { status: 401, headers })
    const { plan, successUrl, cancelUrl } = await req.json()
    const price = prices[plan]
    if (!price) return new Response('Unknown plan', { status: 400, headers })
    const session = await stripe.checkout.sessions.create({
      mode: plan === 'lifetime' ? 'payment' : 'subscription',
      line_items: [{ price, quantity: 1 }], customer_email: user.email,
      client_reference_id: user.id, metadata: { user_id: user.id, plan },
      success_url: successUrl, cancel_url: cancelUrl,
      payment_method_types: ['card'], // Stripe Checkout surfaces Apple Pay / Google Pay automatically when eligible.
    })
    return Response.json({ url: session.url }, { headers })
  } catch (error) { return Response.json({ error: error.message }, { status: 500, headers }) }
})
