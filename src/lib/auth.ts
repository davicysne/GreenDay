import { supabase } from './supabase'

export type ProfileInput = {
  display_name: string
  country: string
  language: string
  currency: string
  timezone: string
}

export async function signIn(email: string, password: string) {
  if (!supabase) return { user: { id: 'demo-user', email }, demo: true }
  const { data, error } = await supabase.auth.signInWithPassword({ email, password })
  if (error) throw error
  return { user: data.user, demo: false }
}

export async function signUp(email: string, password: string, profile: ProfileInput) {
  if (!supabase) return { user: { id: 'demo-user', email }, demo: true }
  const { data, error } = await supabase.auth.signUp({ email, password, options: { data: profile } })
  if (error) throw error
  if (data.user) {
    const { error: profileError } = await supabase.from('profiles').upsert({ id: data.user.id, ...profile })
    if (profileError) throw profileError
  }
  return { user: data.user, demo: false }
}

export async function signOut() {
  if (supabase) await supabase.auth.signOut()
  localStorage.removeItem('gd-auth')
}
