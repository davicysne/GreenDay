import { supabase } from './supabase'

export type GoalStatus = 'not_started' | 'in_progress' | 'completed' | 'cancelled'
export type GoalCategory = 'financial' | 'recovery' | 'health' | 'personal' | 'custom'
export type Goal = {
  id: string
  user_id: string
  title: string
  description: string
  category: GoalCategory
  custom_category_name: string | null
  target_value: number
  current_value: number
  progress_percentage: number
  status: GoalStatus
  deadline: string | null
  completed_at: string | null
  created_at: string
  updated_at: string
}

const demoKey = 'gd-goals'
const demoSeed: Goal[] = [{
  id: 'demo-goal-1', user_id: 'demo-user', title: 'Save $500', description: 'Build a small safety cushion with the money I no longer gamble.',
  category: 'financial', custom_category_name: null, target_value: 500, current_value: 180, progress_percentage: 36, status: 'in_progress',
  deadline: '2026-08-30', completed_at: null, created_at: new Date().toISOString(), updated_at: new Date().toISOString(),
}]

const readDemo = () => {
  const saved = localStorage.getItem(demoKey)
  if (saved) return JSON.parse(saved) as Goal[]
  const profile=JSON.parse(localStorage.getItem('gd-profile')||'null')
  const seeded=profile?[{...demoSeed[0],title:profile.main_objective==='pay_debt'?'Pay off gambling debt':profile.main_objective==='save_money'?`Save ${profile.financial_objective||500}`:profile.main_objective==='mental_health'?'Complete 7 mindful check-ins':'Stay 30 days without gambling',category:(profile.main_objective==='pay_debt'||profile.main_objective==='save_money'?'financial':'recovery') as GoalCategory,target_value:profile.main_objective==='pay_debt'||profile.main_objective==='save_money'?profile.financial_objective||500:30,current_value:0,progress_percentage:0,description:'Suggested from your onboarding answers.'}]:demoSeed
  localStorage.setItem(demoKey, JSON.stringify(seeded))
  return seeded
}

export async function listGoals(userId: string) {
  if (!supabase || userId === 'demo-user') return readDemo()
  const { data, error } = await supabase.from('goals').select('*').eq('user_id', userId).order('created_at', { ascending: false })
  if (error) throw error
  return data as Goal[]
}

export async function saveGoal(userId: string, values: Partial<Goal> & Pick<Goal, 'title'>) {
  const now = new Date().toISOString()
  const target = Number(values.target_value || 0), current = Number(values.current_value || 0)
  const progress = target > 0 ? Math.min(100, Math.round(current / target * 100)) : Number(values.progress_percentage || 0)
  const goal: Goal = {
    id: values.id || crypto.randomUUID(), user_id: userId, title: values.title, description: values.description || '',
    category: values.category || 'custom', custom_category_name: values.category === 'custom' ? values.custom_category_name || null : null, target_value: target, current_value: current, progress_percentage: progress,
    status: values.status || (progress > 0 ? 'in_progress' : 'not_started'), deadline: values.deadline || null,
    completed_at: values.status === 'completed' ? values.completed_at || now : null,
    created_at: values.created_at || now, updated_at: now,
  }
  if (!supabase || userId === 'demo-user') {
    const goals = readDemo(), next = goals.some(item => item.id === goal.id) ? goals.map(item => item.id === goal.id ? goal : item) : [goal, ...goals]
    localStorage.setItem(demoKey, JSON.stringify(next)); return goal
  }
  const { data, error } = await supabase.from('goals').upsert(goal).select().single()
  if (error) throw error
  return data as Goal
}

export async function removeGoal(userId: string, id: string) {
  if (!supabase || userId === 'demo-user') { localStorage.setItem(demoKey, JSON.stringify(readDemo().filter(goal => goal.id !== id))); return }
  const { error } = await supabase.from('goals').delete().eq('id', id).eq('user_id', userId)
  if (error) throw error
}
