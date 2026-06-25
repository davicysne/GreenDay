-- Green Day baseline schema
-- Designed for a clean hosted or local Supabase project.

create extension if not exists pgcrypto with schema extensions;

-- Shared updated_at trigger.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- User profile and onboarding answers.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  age smallint check (age is null or age between 13 and 120),
  country text not null default 'US' check (char_length(country) = 2),
  language text not null default 'en' check (language in ('en', 'pt-BR', 'es')),
  currency text not null default 'USD' check (char_length(currency) = 3),
  timezone text not null default 'UTC',
  gambling_since text,
  weekly_spend numeric(14,2) not null default 0 check (weekly_spend >= 0),
  average_gambling_spend numeric(14,2) not null default 0 check (average_gambling_spend >= 0),
  bet_free_since date,
  recovery_status text check (recovery_status in ('already_stopped', 'start_today', 'relapsed_restart')),
  sober_days integer not null default 0 check (sober_days >= 0),
  main_trigger text,
  main_goal text,
  main_objective text,
  biggest_difficulty text,
  financial_objective numeric(14,2) not null default 0 check (financial_objective >= 0),
  current_urge_level smallint not null default 0 check (current_urge_level between 0 and 10),
  survey_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- Create the profile immediately after an Auth user is created. Metadata supplied
-- during sign-up is copied defensively; the client may update the remaining fields.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  requested_language text;
  requested_country text;
  requested_currency text;
begin
  requested_language := coalesce(new.raw_user_meta_data ->> 'language', 'en');
  if requested_language = 'pt' then requested_language := 'pt-BR'; end if;
  if requested_language not in ('en', 'pt-BR', 'es') then requested_language := 'en'; end if;
  requested_country := upper(coalesce(nullif(new.raw_user_meta_data ->> 'country', ''), 'US'));
  if char_length(requested_country) <> 2 then requested_country := 'US'; end if;
  requested_currency := upper(coalesce(nullif(new.raw_user_meta_data ->> 'currency', ''), 'USD'));
  if char_length(requested_currency) <> 3 then requested_currency := 'USD'; end if;

  insert into public.profiles (id, display_name, country, language, currency, timezone)
  values (
    new.id,
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'display_name', new.raw_user_meta_data ->> 'name', '')), ''),
    requested_country,
    requested_language,
    requested_currency,
    coalesce(nullif(new.raw_user_meta_data ->> 'timezone', ''), 'UTC')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Daily journal entries. Kept separate from quick notification check-ins.
create table public.daily_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_date date not null default current_date,
  mood smallint check (mood is null or mood between 0 and 10),
  urge_level smallint check (urge_level is null or urge_level between 0 and 10),
  trigger text,
  notes text,
  gambled boolean not null default false,
  amount_lost numeric(14,2) not null default 0 check (amount_lost >= 0),
  relapse_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, entry_date),
  check (gambled or amount_lost = 0)
);

create trigger daily_entries_set_updated_at
before update on public.daily_entries
for each row execute function public.set_updated_at();

create table public.daily_checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  mood smallint check (mood is null or mood between 0 and 10),
  felt_urge boolean not null default false,
  urge_level smallint check (urge_level is null or urge_level between 0 and 10),
  note text,
  created_at timestamptz not null default now(),
  check (felt_urge or coalesce(urge_level, 0) = 0)
);

create table public.relapse_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  occurred_at timestamptz not null default now(),
  amount_lost numeric(14,2) not null default 0 check (amount_lost >= 0),
  trigger text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger relapse_logs_set_updated_at
before update on public.relapse_logs
for each row execute function public.set_updated_at();

create table public.urge_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  intensity smallint check (intensity is null or intensity between 0 and 10),
  feelings text,
  strategy text,
  overcome boolean not null default false,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(trim(title)) between 1 and 160),
  description text,
  category text not null default 'custom' check (category in ('financial', 'recovery', 'health', 'personal', 'custom')),
  custom_category_name text,
  target_value numeric(14,2) not null default 0 check (target_value >= 0),
  current_value numeric(14,2) not null default 0 check (current_value >= 0),
  progress_percentage numeric(5,2) not null default 0 check (progress_percentage between 0 and 100),
  status text not null default 'not_started' check (status in ('not_started', 'in_progress', 'completed', 'cancelled')),
  deadline date,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (category <> 'custom' or nullif(trim(custom_category_name), '') is not null),
  check (status = 'completed' or completed_at is null)
);

create or replace function public.sync_goal_fields()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.target_value > 0 then
    new.progress_percentage := least(100, round((new.current_value / new.target_value) * 100, 2));
  else
    new.progress_percentage := greatest(0, least(100, new.progress_percentage));
  end if;

  if new.status = 'completed' then
    new.completed_at := coalesce(new.completed_at, now());
    new.progress_percentage := 100;
    if new.target_value > 0 then new.current_value := greatest(new.current_value, new.target_value); end if;
  else
    new.completed_at := null;
    if new.status = 'not_started' and new.progress_percentage > 0 then new.status := 'in_progress'; end if;
  end if;

  new.updated_at := now();
  return new;
end;
$$;

create trigger goals_sync_fields
before insert or update on public.goals
for each row execute function public.sync_goal_fields();

-- Anonymous community. user_id is never granted for selection to clients.
create table public.community_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  body text not null check (char_length(trim(body)) between 1 and 2000),
  tag text,
  support_count integer not null default 0 check (support_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger community_posts_set_updated_at
before update on public.community_posts
for each row execute function public.set_updated_at();

create table public.community_supports (
  post_id uuid not null references public.community_posts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create or replace function public.refresh_community_support_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  affected_post_id uuid;
begin
  affected_post_id := case when tg_op = 'DELETE' then old.post_id else new.post_id end;
  update public.community_posts
  set support_count = (select count(*) from public.community_supports where post_id = affected_post_id)
  where id = affected_post_id;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger community_supports_refresh_count
after insert or delete on public.community_supports
for each row execute function public.refresh_community_support_count();

create view public.community_feed
with (security_invoker = true)
as
select id, body, tag, support_count, created_at
from public.community_posts;

-- Stripe is the authority for this table; clients can only read their row.
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  plan_name text not null,
  billing_cycle text not null check (billing_cycle in ('monthly', 'semiannual', 'annual', 'lifetime')),
  status text not null check (status in ('active', 'trialing', 'past_due', 'cancelled', 'expired', 'unpaid')),
  currency text not null default 'USD' check (char_length(currency) = 3),
  amount numeric(14,2) not null default 0 check (amount >= 0),
  stripe_customer_id text unique,
  stripe_subscription_id text unique,
  current_period_start timestamptz,
  current_period_end timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger subscriptions_set_updated_at
before update on public.subscriptions
for each row execute function public.set_updated_at();

-- Enforce the Free plan's single-goal limit at the database boundary. Premium
-- users with an active/trialing subscription may create unlimited goals.
create or replace function public.enforce_goal_plan_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (select auth.role()) = 'service_role' then return new; end if;

  perform pg_advisory_xact_lock(hashtextextended(new.user_id::text, 0));

  if exists (
    select 1 from public.subscriptions
    where user_id = new.user_id and status in ('active', 'trialing')
  ) then
    return new;
  end if;

  if exists (
    select 1 from public.goals
    where user_id = new.user_id and status <> 'cancelled'
  ) then
    raise exception using
      errcode = 'P0001',
      message = 'FREE_GOAL_LIMIT_REACHED',
      hint = 'Upgrade to Green Day Premium to create unlimited goals.';
  end if;

  return new;
end;
$$;

create trigger goals_enforce_plan_limit
before insert on public.goals
for each row execute function public.enforce_goal_plan_limit();

-- Persistent in-app and push notification history. Edge Functions create rows;
-- users can read them and update read_at.
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null default 'reminder' check (kind in ('reminder', 'milestone', 'community', 'goal', 'system')),
  title text not null check (char_length(trim(title)) between 1 and 160),
  body text not null check (char_length(trim(body)) between 1 and 1000),
  data jsonb not null default '{}'::jsonb,
  dedupe_key text unique,
  scheduled_for timestamptz,
  delivered_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.notification_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  enabled boolean not null default false,
  first_notification_time time not null default '09:00',
  second_notification_time time not null default '20:00',
  timezone text not null default 'UTC',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (first_notification_time <> second_notification_time)
);

create trigger notification_preferences_set_updated_at
before update on public.notification_preferences
for each row execute function public.set_updated_at();

create table public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  user_agent text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger push_subscriptions_set_updated_at
before update on public.push_subscriptions
for each row execute function public.set_updated_at();

-- Badge catalog and earned badge history.
create table public.badges (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  name text not null,
  description text not null,
  icon text,
  category text not null default 'recovery' check (category in ('recovery', 'savings', 'journal', 'urges', 'community', 'goals')),
  threshold numeric(14,2),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.user_badges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_id uuid not null references public.badges(id) on delete cascade,
  awarded_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  unique (user_id, badge_id)
);

insert into public.badges (slug, name, description, icon, category, threshold)
values
  ('first-day', 'First Step', 'Completed the first bet-free day.', 'leaf', 'recovery', 1),
  ('seven-days', 'One Week Strong', 'Reached seven bet-free days.', 'flame', 'recovery', 7),
  ('thirty-days', 'Thirty Days', 'Reached thirty bet-free days.', 'shield', 'recovery', 30),
  ('ten-urges', 'Urge Surfer', 'Overcame ten gambling urges.', 'wave', 'urges', 10),
  ('first-goal', 'Goal Getter', 'Completed the first personal goal.', 'target', 'goals', 1),
  ('seven-checkins', 'Showing Up', 'Completed seven daily check-ins.', 'calendar', 'journal', 7)
on conflict (slug) do nothing;

-- Query indexes used by the dashboard, reports, scheduler and feeds.
create index daily_entries_user_date_idx on public.daily_entries (user_id, entry_date desc);
create index daily_checkins_user_created_idx on public.daily_checkins (user_id, created_at desc);
create index relapse_logs_user_occurred_idx on public.relapse_logs (user_id, occurred_at desc);
create index urge_logs_user_occurred_idx on public.urge_logs (user_id, occurred_at desc);
create index goals_user_status_idx on public.goals (user_id, status, created_at desc);
create index goals_user_deadline_idx on public.goals (user_id, deadline) where deadline is not null;
create index community_posts_created_idx on public.community_posts (created_at desc);
create index notifications_user_created_idx on public.notifications (user_id, created_at desc);
create index notifications_user_unread_idx on public.notifications (user_id, created_at desc) where read_at is null;
create index notification_preferences_enabled_idx on public.notification_preferences (enabled) where enabled;
create index push_subscriptions_user_idx on public.push_subscriptions (user_id);
create index user_badges_user_awarded_idx on public.user_badges (user_id, awarded_at desc);

-- Row Level Security.
alter table public.profiles enable row level security;
alter table public.daily_entries enable row level security;
alter table public.daily_checkins enable row level security;
alter table public.relapse_logs enable row level security;
alter table public.urge_logs enable row level security;
alter table public.goals enable row level security;
alter table public.community_posts enable row level security;
alter table public.community_supports enable row level security;
alter table public.subscriptions enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.push_subscriptions enable row level security;
alter table public.badges enable row level security;
alter table public.user_badges enable row level security;

create policy profiles_select_own on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy profiles_insert_own on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy profiles_update_own on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create policy daily_entries_own on public.daily_entries for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy daily_checkins_own on public.daily_checkins for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy relapse_logs_own on public.relapse_logs for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy urge_logs_own on public.urge_logs for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy goals_own on public.goals for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

create policy community_posts_select_own on public.community_posts for select to authenticated using ((select auth.uid()) = user_id);
create policy community_posts_insert_own on public.community_posts for insert to authenticated with check ((select auth.uid()) = user_id);
create policy community_posts_update_own on public.community_posts for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy community_posts_delete_own on public.community_posts for delete to authenticated using ((select auth.uid()) = user_id);
create policy community_supports_read_own on public.community_supports for select to authenticated using ((select auth.uid()) = user_id);
create policy community_supports_insert_own on public.community_supports for insert to authenticated with check ((select auth.uid()) = user_id);
create policy community_supports_delete_own on public.community_supports for delete to authenticated using ((select auth.uid()) = user_id);

create policy subscriptions_select_own on public.subscriptions for select to authenticated using ((select auth.uid()) = user_id);
create policy notifications_select_own on public.notifications for select to authenticated using ((select auth.uid()) = user_id);
create policy notifications_update_own on public.notifications for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy notifications_delete_own on public.notifications for delete to authenticated using ((select auth.uid()) = user_id);
create policy notification_preferences_own on public.notification_preferences for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy push_subscriptions_own on public.push_subscriptions for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy badges_read_active on public.badges for select to authenticated using (is_active);
create policy user_badges_select_own on public.user_badges for select to authenticated using ((select auth.uid()) = user_id);

-- Explicit API grants. RLS still applies to every granted operation.
revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update, delete on public.daily_entries to authenticated;
grant select, insert, update, delete on public.daily_checkins to authenticated;
grant select, insert, update, delete on public.relapse_logs to authenticated;
grant select, insert, update, delete on public.urge_logs to authenticated;
grant select, insert, update, delete on public.goals to authenticated;
grant select (id, body, tag, support_count, created_at, updated_at) on public.community_posts to authenticated;
grant insert (user_id, body, tag) on public.community_posts to authenticated;
grant update (body, tag) on public.community_posts to authenticated;
grant delete on public.community_posts to authenticated;
grant select, insert, delete on public.community_supports to authenticated;
grant select on public.community_feed to authenticated;
grant select on public.subscriptions to authenticated;
grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;
grant delete on public.notifications to authenticated;
grant select, insert, update, delete on public.notification_preferences to authenticated;
grant select, insert, update, delete on public.push_subscriptions to authenticated;
grant select on public.badges to authenticated;
grant select on public.user_badges to authenticated;

grant usage on schema public to authenticated;
grant execute on function public.set_updated_at() to authenticated;
grant execute on function public.sync_goal_fields() to authenticated;

-- Service role is used by Stripe webhooks, push dispatch and badge awarding.
grant all on all tables in schema public to service_role;
grant all on all sequences in schema public to service_role;
grant execute on all functions in schema public to service_role;
