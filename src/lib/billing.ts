import { supabase } from './supabase'
import { setUserItem } from './userStorage'

export type BillingPlan = 'monthly' | 'semiannual' | 'annual' | 'lifetime'

export const basePrices: Record<BillingPlan | 'free', number> = {
  free: 0, monthly: 4.99, semiannual: 24.99, annual: 39.99, lifetime: 79.99,
}

export function localizePrice(amount: number, currency: string, rate = 1) {
  return new Intl.NumberFormat(undefined, { style: 'currency', currency, maximumFractionDigits: 2 }).format(amount * rate)
}

export async function startCheckout(plan: BillingPlan, currency: string) {
  if (!supabase) {
    setUserItem('demo-user', 'premium', true)
    return { demo: true }
  }
  const { data, error } = await supabase.functions.invoke('create-checkout', {
    body: { plan, currency, successUrl: `${location.origin}/?checkout=success`, cancelUrl: `${location.origin}/pricing` },
  })
  if (error) throw error
  if (!data?.url) throw new Error('Stripe Checkout URL was not returned.')
  location.assign(data.url)
  return { demo: false }
}
