-- Fail the migration if any required Green Day relation was not created.
do $$
declare
  required_relation text;
begin
  foreach required_relation in array array[
    'profiles', 'daily_entries', 'daily_checkins', 'relapse_logs', 'urge_logs',
    'goals', 'community_posts', 'community_supports', 'subscriptions', 'notifications',
    'notification_preferences', 'push_subscriptions', 'badges', 'user_badges'
  ] loop
    if to_regclass('public.' || required_relation) is null then
      raise exception 'Required Green Day relation public.% is missing', required_relation;
    end if;

    if not exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = required_relation
        and c.relrowsecurity
    ) then
      raise exception 'RLS is not enabled on public.%', required_relation;
    end if;

    if not exists (
      select 1
      from pg_policy p
      join pg_class c on c.oid = p.polrelid
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname = required_relation
    ) then
      raise exception 'No RLS policy exists for public.%', required_relation;
    end if;
  end loop;

  if not exists (
    select 1 from pg_trigger
    where tgname = 'on_auth_user_created' and not tgisinternal
  ) then
    raise exception 'Auth profile provisioning trigger is missing';
  end if;
end;
$$;
