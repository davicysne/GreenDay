-- Green Day MVP schema. Run in the Supabase SQL editor.
create extension if not exists "uuid-ossp";

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  country text default 'US',
  age smallint check (age between 13 and 120),
  language text default 'en' check (language in ('en','pt-BR','es')),
  currency text default 'USD',
  timezone text default 'UTC',
  gambling_since text,
  weekly_spend numeric default 0,
  bet_free_since date,
  main_trigger text,
  main_goal text,
  recovery_status text check (recovery_status in ('already_stopped','start_today','relapsed_restart')),
  sober_days integer default 0 check (sober_days >= 0),
  average_gambling_spend numeric default 0 check (average_gambling_spend >= 0),
  main_objective text,
  biggest_difficulty text,
  financial_objective numeric default 0,
  current_urge_level smallint default 0 check (current_urge_level between 0 and 10),
  survey_completed_at timestamptz,
  created_at timestamptz default now()
);

create table public.daily_entries (
  id uuid primary key default uuid_generate_v4(), user_id uuid references public.profiles(id) on delete cascade not null,
  entry_date date default current_date, mood smallint check (mood between 0 and 10), urge_level smallint check (urge_level between 0 and 10),
  trigger text, notes text, gambled boolean default false, amount_lost numeric default 0, relapse_reason text, created_at timestamptz default now(), unique(user_id, entry_date)
);

create table public.relapse_logs (
  id uuid primary key default uuid_generate_v4(), user_id uuid references public.profiles(id) on delete cascade not null,
  occurred_at timestamptz not null, amount_lost numeric default 0, trigger text, notes text, created_at timestamptz default now()
);

create table public.urge_logs (
  id uuid primary key default uuid_generate_v4(), user_id uuid references public.profiles(id) on delete cascade not null,
  intensity smallint check (intensity between 0 and 10), feelings text, strategy text, overcome boolean default false, occurred_at timestamptz default now()
);

create table public.goals (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references auth.users(id) on delete cascade not null,
  title text not null,
  description text,
  category text default 'custom' check (category in ('financial','recovery','health','personal','custom')),
  custom_category_name text,
  target_value numeric default 0 check (target_value >= 0),
  current_value numeric default 0 check (current_value >= 0),
  progress_percentage numeric default 0 check (progress_percentage between 0 and 100),
  status text default 'not_started' check (status in ('not_started','in_progress','completed','cancelled')),
  deadline date,
  completed_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table public.community_posts (
  id uuid primary key default uuid_generate_v4(), user_id uuid references public.profiles(id) on delete cascade not null,
  body text not null, tag text, support_count integer default 0, created_at timestamptz default now()
);

create table public.subscriptions (
  id uuid primary key default uuid_generate_v4(), user_id uuid references public.profiles(id) on delete cascade not null unique,
  plan_name text not null, billing_cycle text not null,
  status text not null check (status in ('active','trialing','past_due','cancelled','expired','unpaid')),
  currency text default 'USD', amount numeric not null,
  stripe_customer_id text unique, stripe_subscription_id text unique,
  current_period_start timestamptz, current_period_end timestamptz,
  created_at timestamptz default now(), updated_at timestamptz default now()
);

create table public.notification_preferences (
  id uuid primary key default uuid_generate_v4(), user_id uuid references public.profiles(id) on delete cascade not null unique,
  enabled boolean default false, first_notification_time time default '09:00', second_notification_time time default '20:00',
  timezone text default 'UTC', created_at timestamptz default now(), updated_at timestamptz default now()
);

create table public.daily_checkins (
  id uuid primary key default uuid_generate_v4(), user_id uuid references public.profiles(id) on delete cascade not null,
  mood smallint check (mood between 0 and 10), felt_urge boolean default false,
  urge_level smallint check (urge_level between 0 and 10), note text, created_at timestamptz default now()
);

create table public.push_subscriptions (
  id uuid primary key default uuid_generate_v4(), user_id uuid references public.profiles(id) on delete cascade not null,
  endpoint text not null unique, p256dh text not null, auth text not null, created_at timestamptz default now()
);

alter table public.profiles enable row level security;
alter table public.daily_entries enable row level security;
alter table public.relapse_logs enable row level security;
alter table public.urge_logs enable row level security;
alter table public.goals enable row level security;
alter table public.community_posts enable row level security;
alter table public.subscriptions enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.daily_checkins enable row level security;
alter table public.push_subscriptions enable row level security;

create policy "Users manage own profile" on public.profiles for all using (auth.uid() = id) with check (auth.uid() = id);
create policy "Users manage own entries" on public.daily_entries for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users manage own relapses" on public.relapse_logs for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users manage own urges" on public.urge_logs for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users manage own goals" on public.goals for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Community posts are readable" on public.community_posts for select using (true);
create policy "Users create posts" on public.community_posts for insert with check (auth.uid() = user_id);
create policy "Users delete own posts" on public.community_posts for delete using (auth.uid() = user_id);
create policy "Users read own subscription" on public.subscriptions for select using (auth.uid() = user_id);
create policy "Users manage notification preferences" on public.notification_preferences for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users manage own checkins" on public.daily_checkins for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "Users manage own push devices" on public.push_subscriptions for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Future AI integration should read only user-authorized rows and write suggestions
-- to a separate table, never directly modifying journals or relapse records.
