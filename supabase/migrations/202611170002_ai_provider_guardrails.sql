create table if not exists public.ai_global_daily_usage (
  singleton boolean primary key default true check (singleton),
  usage_date date not null,
  request_count integer not null default 0
    check (request_count between 0 and 100000)
);

create table if not exists public.ai_user_daily_usage (
  user_id uuid primary key references auth.users(id) on delete cascade,
  usage_date date not null,
  request_count integer not null default 0
    check (request_count between 0 and 100000)
);

create table if not exists public.ai_provider_daily_usage (
  provider text primary key check (provider in (
    'gemini', 'groq', 'openrouter', 'mistral', 'cloudflare',
    'sambanova', 'cohere', 'nvidia', 'zai', 'huggingface'
  )),
  usage_date date not null,
  request_count integer not null default 0
    check (request_count between 0 and 100000)
);

create table if not exists public.ai_provider_runtime_state (
  provider text primary key check (provider in (
    'gemini', 'groq', 'openrouter', 'mistral', 'cloudflare',
    'sambanova', 'cohere', 'nvidia', 'zai', 'huggingface'
  )),
  consecutive_failures integer not null default 0
    check (consecutive_failures between 0 and 100000),
  circuit_open_until timestamptz,
  last_status text,
  last_attempt_at timestamptz,
  last_success_at timestamptz,
  probe_lease_until timestamptz,
  last_duration_ms integer
    check (last_duration_ms is null or last_duration_ms between 0 and 90000),
  updated_at timestamptz not null default now()
);

alter table public.ai_global_daily_usage enable row level security;
alter table public.ai_user_daily_usage enable row level security;
alter table public.ai_provider_daily_usage enable row level security;
alter table public.ai_provider_runtime_state enable row level security;

revoke all on public.ai_global_daily_usage, public.ai_user_daily_usage,
  public.ai_provider_daily_usage, public.ai_provider_runtime_state
  from public, anon, authenticated;
grant select on public.ai_global_daily_usage, public.ai_user_daily_usage,
  public.ai_provider_daily_usage, public.ai_provider_runtime_state
  to service_role;

create or replace function public.reserve_ai_provider_attempt(
  target_user_id uuid,
  target_provider text,
  target_global_limit integer,
  target_user_limit integer,
  target_provider_limit integer
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_time timestamptz;
  utc_today date;
  global_date date;
  global_count integer;
  user_date date;
  user_count integer;
  provider_date date;
  provider_count integer;
  provider_circuit_until timestamptz;
  provider_probe_until timestamptz;
begin
  if target_user_id is null
     or target_provider is null
     or target_provider not in (
       'gemini', 'groq', 'openrouter', 'mistral', 'cloudflare',
       'sambanova', 'cohere', 'nvidia', 'zai', 'huggingface'
     )
     or target_global_limit is null
     or target_global_limit not between 1 and 100000
     or target_user_limit is null
     or target_user_limit not between 1 and 100000
     or target_provider_limit is null
     or target_provider_limit not between 1 and 100000 then
    return 'budget_unconfigured';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('ai_provider_daily_budget', 0)
  );
  request_time := pg_catalog.clock_timestamp();
  utc_today := (request_time at time zone 'UTC')::date;

  insert into public.ai_global_daily_usage (
    singleton, usage_date, request_count
  )
  values (true, utc_today, 0)
  on conflict (singleton) do nothing;
  select usage_date, request_count
    into global_date, global_count
    from public.ai_global_daily_usage
   where singleton
   for update;
  if global_date <> utc_today then
    global_count := 0;
  end if;

  insert into public.ai_user_daily_usage (
    user_id, usage_date, request_count
  )
  values (target_user_id, utc_today, 0)
  on conflict (user_id) do nothing;
  select usage_date, request_count
    into user_date, user_count
    from public.ai_user_daily_usage
   where user_id = target_user_id
   for update;
  if user_date <> utc_today then
    user_count := 0;
  end if;

  insert into public.ai_provider_daily_usage (
    provider, usage_date, request_count
  )
  values (target_provider, utc_today, 0)
  on conflict (provider) do nothing;
  select usage_date, request_count
    into provider_date, provider_count
    from public.ai_provider_daily_usage
   where provider = target_provider
   for update;
  if provider_date <> utc_today then
    provider_count := 0;
  end if;

  insert into public.ai_provider_runtime_state (provider)
  values (target_provider)
  on conflict (provider) do nothing;
  select circuit_open_until, probe_lease_until
    into provider_circuit_until, provider_probe_until
    from public.ai_provider_runtime_state
   where provider = target_provider
   for update;
  if provider_circuit_until > request_time then
    return 'circuit_open';
  end if;
  if provider_probe_until > request_time then
    return 'circuit_open';
  end if;

  if global_count >= target_global_limit then
    return 'global_budget_exhausted';
  end if;
  if user_count >= target_user_limit then
    return 'user_budget_exhausted';
  end if;
  if provider_count >= target_provider_limit then
    return 'provider_budget_exhausted';
  end if;

  update public.ai_global_daily_usage
     set usage_date = utc_today,
         request_count = global_count + 1
   where singleton;
  update public.ai_user_daily_usage
     set usage_date = utc_today,
         request_count = user_count + 1
   where user_id = target_user_id;
  update public.ai_provider_daily_usage
     set usage_date = utc_today,
         request_count = provider_count + 1
   where provider = target_provider;
  update public.ai_provider_runtime_state
     set consecutive_failures = case
           when circuit_open_until is not null
             and circuit_open_until <= request_time
             then 0
           else consecutive_failures
         end,
         circuit_open_until = case
           when circuit_open_until <= request_time then null
           else circuit_open_until
         end,
         probe_lease_until = case
           when circuit_open_until is not null
             and circuit_open_until <= request_time
             then request_time + interval '90 seconds'
           else probe_lease_until
         end,
         last_status = 'in_flight',
         last_attempt_at = request_time,
         updated_at = request_time
   where provider = target_provider;

  return 'allowed';
end;
$$;

create or replace function public.record_ai_provider_attempt(
  target_provider text,
  target_status text,
  target_duration_ms integer,
  target_http_status integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  recorded_at timestamptz := pg_catalog.clock_timestamp();
  current_failures integer;
  current_circuit_until timestamptz;
  current_probe_until timestamptz;
  was_half_open_probe boolean;
begin
  if target_provider is null
     or target_status is null
     or target_duration_ms is null
     or target_provider not in (
       'gemini', 'groq', 'openrouter', 'mistral', 'cloudflare',
       'sambanova', 'cohere', 'nvidia', 'zai', 'huggingface'
     )
     or target_status not in (
       'available', 'authentication_error', 'rate_limited',
       'billing_required', 'model_not_found', 'model_retired',
       'request_rejected', 'provider_error', 'invalid_response',
       'timeout', 'network_error'
     )
     or target_duration_ms not between 0 and 90000
     or (
       target_http_status is not null
       and target_http_status not between 100 and 599
     ) then
    raise exception using
      errcode = '22023',
      message = 'invalid_ai_provider_attempt';
  end if;

  select consecutive_failures, circuit_open_until, probe_lease_until
    into current_failures, current_circuit_until, current_probe_until
    from public.ai_provider_runtime_state
   where provider = target_provider
   for update;
  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'ai_provider_attempt_not_reserved';
  end if;
  was_half_open_probe := current_probe_until > recorded_at;

  if target_status = 'available' then
    update public.ai_provider_runtime_state
       set consecutive_failures = case
             when current_circuit_until > recorded_at
               then current_failures
             else 0
           end,
           circuit_open_until = case
             when current_circuit_until > recorded_at
               then current_circuit_until
             else null
           end,
           probe_lease_until = null,
           last_status = target_status,
           last_success_at = recorded_at,
           last_duration_ms = target_duration_ms,
           updated_at = recorded_at
     where provider = target_provider;
  elsif current_circuit_until > recorded_at then
    update public.ai_provider_runtime_state
       set last_status = target_status,
           last_duration_ms = target_duration_ms,
           probe_lease_until = null,
           updated_at = recorded_at
     where provider = target_provider;
  else
    current_failures := case
      when was_half_open_probe then 3
      else current_failures + 1
    end;
    update public.ai_provider_runtime_state
       set consecutive_failures = current_failures,
           circuit_open_until = case
             when current_failures >= 3
               then recorded_at + interval '15 minutes'
             else null
           end,
           probe_lease_until = null,
           last_status = target_status,
           last_duration_ms = target_duration_ms,
           updated_at = recorded_at
     where provider = target_provider;
  end if;

  return true;
end;
$$;

create or replace view public.ai_provider_health
with (security_invoker = true)
as
select
  state.provider,
  case
    when state.circuit_open_until > now() then 'circuit_open'
    when state.last_status = 'available' then 'available'
    when state.last_attempt_at is null then 'unknown'
    else 'unavailable'
  end as health_status,
  state.consecutive_failures,
  state.circuit_open_until,
  state.last_status,
  state.last_attempt_at,
  state.last_success_at,
  state.last_duration_ms,
  coalesce(usage.request_count, 0)::bigint as daily_request_count
from public.ai_provider_runtime_state state
left join public.ai_provider_daily_usage usage
  on usage.provider = state.provider
 and usage.usage_date = (now() at time zone 'UTC')::date;

revoke all on public.ai_provider_health from public, anon, authenticated;
grant select on public.ai_provider_health to service_role;

revoke all on function public.reserve_ai_provider_attempt(
  uuid, text, integer, integer, integer
) from public, anon, authenticated;
grant execute on function public.reserve_ai_provider_attempt(
  uuid, text, integer, integer, integer
) to service_role;

revoke all on function public.record_ai_provider_attempt(
  text, text, integer, integer
) from public, anon, authenticated;
grant execute on function public.record_ai_provider_attempt(
  text, text, integer, integer
) to service_role;

notify pgrst, 'reload schema';
