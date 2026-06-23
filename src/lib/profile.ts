import { supabase } from './supabase'

export type SurveyAnswers = {
  display_name: string
  age: number
  country: string
  language: string
  currency: string
  main_objective: string
  recovery_status: 'already_stopped' | 'start_today' | 'relapsed_restart'
  sober_days: number
  average_gambling_spend: number
  main_trigger: string
  biggest_difficulty: string
  financial_objective: number
  current_urge_level: number
  bet_free_since: string
  survey_completed_at: string
}

export const getStoredProfile = () => JSON.parse(localStorage.getItem('gd-profile') || 'null') as SurveyAnswers | null

export async function saveSurvey(userId: string, answers: SurveyAnswers) {
  localStorage.setItem('gd-profile', JSON.stringify(answers))
  localStorage.removeItem('gd-goals')
  if (!supabase || userId === 'demo-user') return
  const { error } = await supabase.from('profiles').update(answers).eq('id', userId)
  if (error) throw error
}
