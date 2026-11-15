create table if not exists public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  share_protection_status boolean not null default false,
  share_scan_results boolean not null default false,
  share_security_alerts boolean not null default false,
  family_activity_notifications boolean not null default false,
  push_notifications_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

alter table public.user_settings enable row level security;

drop policy if exists user_settings_select_self on public.user_settings;
create policy user_settings_select_self on public.user_settings
for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists user_settings_update_self on public.user_settings;
create policy user_settings_update_self on public.user_settings
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

revoke all on public.user_settings from anon, authenticated;
grant select, update on public.user_settings to authenticated;
grant all on public.user_settings to service_role;

create or replace function public.touch_user_settings_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := pg_catalog.now();
  return new;
end;
$$;

drop trigger if exists user_settings_touch_updated_at on public.user_settings;
create trigger user_settings_touch_updated_at
before update on public.user_settings
for each row execute function public.touch_user_settings_updated_at();

create or replace function public.initialize_user_settings()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists auth_user_initialize_settings on auth.users;
create trigger auth_user_initialize_settings
after insert on auth.users
for each row execute function public.initialize_user_settings();

insert into public.user_settings (user_id)
select id from auth.users
on conflict (user_id) do nothing;

revoke all on function public.touch_user_settings_updated_at()
  from public, anon, authenticated;
revoke all on function public.initialize_user_settings()
  from public, anon, authenticated;
