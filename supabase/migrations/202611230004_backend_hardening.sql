alter table public.user_settings
  add column if not exists scan_history_retention_days integer;

update public.user_settings
set scan_history_retention_days = 90
where scan_history_retention_days is null;

alter table public.user_settings
  alter column scan_history_retention_days set default 90,
  alter column scan_history_retention_days set not null;

do $migration$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'user_settings_scan_history_retention_check'
      and conrelid = 'public.user_settings'::regclass
  ) then
    alter table public.user_settings
      add constraint user_settings_scan_history_retention_check
      check (scan_history_retention_days in (30, 60, 90));
  end if;
end;
$migration$;

create or replace function public.delete_expired_scan_history()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_count integer;
begin
  delete from public.scan_records sr
  using public.user_settings us
  where sr.user_id = us.user_id
    and sr.created_at <
      pg_catalog.now() -
      pg_catalog.make_interval(days => us.scan_history_retention_days);

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

revoke all on function public.delete_expired_scan_history()
  from public, anon, authenticated;
grant execute on function public.delete_expired_scan_history()
  to service_role;

create table if not exists public.edge_request_windows (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null,
  request_count integer not null
    check (request_count between 0 and 100000)
);

alter table public.edge_request_windows enable row level security;
revoke all on public.edge_request_windows from public, anon, authenticated;
grant all on public.edge_request_windows to service_role;

create or replace function public.consume_edge_request_window(
  target_user_id uuid,
  target_window_seconds integer default 600,
  target_request_limit integer default 10
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_time timestamptz := pg_catalog.clock_timestamp();
  window_duration interval;
  current_window timestamptz;
  current_count integer;
begin
  if target_user_id is null
     or target_window_seconds <= 0
     or target_request_limit <= 0
     or target_request_limit > 100000 then
    return false;
  end if;

  window_duration := pg_catalog.make_interval(secs => target_window_seconds);

  insert into public.edge_request_windows (
    user_id,
    window_started_at,
    request_count
  )
  values (target_user_id, request_time, 0)
  on conflict (user_id) do nothing;

  select window_started_at, request_count
    into current_window, current_count
    from public.edge_request_windows
   where user_id = target_user_id
   for update;

  if current_window <= request_time - window_duration then
    current_window := request_time;
    current_count := 0;
  end if;

  if current_count >= target_request_limit then
    return false;
  end if;

  update public.edge_request_windows
     set window_started_at = current_window,
         request_count = current_count + 1
   where user_id = target_user_id;

  return true;
end;
$$;

revoke all on function public.consume_edge_request_window(uuid, integer, integer)
  from public, anon, authenticated;
grant execute on function public.consume_edge_request_window(uuid, integer, integer)
  to service_role;

do $migration$
begin
  if exists (
    select 1
    from pg_available_extensions
    where name = 'pg_cron'
  ) then
    execute 'create extension if not exists pg_cron with schema extensions';
  end if;
end;
$migration$;

notify pgrst, 'reload schema';
