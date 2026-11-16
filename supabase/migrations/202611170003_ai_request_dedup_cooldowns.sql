alter table public.ai_user_daily_usage
  add column if not exists last_request_at timestamptz;

create table if not exists public.ai_request_deduplication (
  user_id uuid not null references auth.users(id) on delete cascade,
  request_fingerprint text not null
    check (request_fingerprint ~ '^[0-9a-f]{64}$'),
  requested_at timestamptz not null,
  primary key (user_id, request_fingerprint)
);

create index if not exists ai_request_deduplication_requested_at_idx
  on public.ai_request_deduplication (requested_at);

create table if not exists public.ai_provider_attempt_leases (
  reservation_id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in (
    'gemini', 'groq', 'openrouter', 'mistral', 'cloudflare',
    'sambanova', 'cohere', 'nvidia', 'zai', 'huggingface'
  )),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists ai_provider_attempt_leases_expiry_idx
  on public.ai_provider_attempt_leases (expires_at);
create index if not exists ai_provider_attempt_leases_provider_expiry_idx
  on public.ai_provider_attempt_leases (provider, expires_at);

alter table public.ai_request_deduplication enable row level security;
alter table public.ai_provider_attempt_leases enable row level security;

revoke all on public.ai_request_deduplication,
  public.ai_provider_attempt_leases
  from public, anon, authenticated;
grant select on public.ai_request_deduplication,
  public.ai_provider_attempt_leases
  to service_role;

create or replace function public.reserve_ai_provider_attempt_v2(
  target_user_id uuid,
  target_provider text,
  target_global_limit integer,
  target_user_limit integer,
  target_provider_limit integer,
  target_request_fingerprint text,
  target_user_cooldown_seconds integer,
  target_duplicate_window_seconds integer,
  target_max_concurrent_requests integer,
  target_initial_attempt boolean
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_time timestamptz := pg_catalog.clock_timestamp();
  previous_request_at timestamptz;
  previous_fingerprint_at timestamptz;
  active_attempt_count bigint;
  reserve_result text;
  new_reservation_id uuid;
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
     or target_provider_limit not between 1 and 100000
     or target_request_fingerprint is null
     or target_request_fingerprint !~ '^[0-9a-f]{64}$'
     or target_user_cooldown_seconds is null
     or target_user_cooldown_seconds not between 1 and 3600
     or target_duplicate_window_seconds is null
     or target_duplicate_window_seconds not between 1 and 86400
     or target_max_concurrent_requests is null
     or target_max_concurrent_requests not between 1 and 100
     or target_initial_attempt is null then
    return 'budget_unconfigured';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('ai_provider_daily_budget', 0)
  );

  delete from public.ai_request_deduplication
   where requested_at <= request_time - interval '1 day';
  delete from public.ai_provider_attempt_leases
   where expires_at <= request_time;

  if target_initial_attempt then
    select last_request_at
      into previous_request_at
      from public.ai_user_daily_usage
     where user_id = target_user_id
     for update;
    if previous_request_at is not null
       and previous_request_at >
         request_time - pg_catalog.make_interval(
           secs => target_user_cooldown_seconds
         ) then
      return 'user_cooldown';
    end if;

    select requested_at
      into previous_fingerprint_at
      from public.ai_request_deduplication
     where user_id = target_user_id
       and request_fingerprint = target_request_fingerprint
     for update;
    if previous_fingerprint_at >
       request_time - pg_catalog.make_interval(
         secs => target_duplicate_window_seconds
       ) then
      return 'duplicate_request';
    end if;
  end if;

  select count(*)
    into active_attempt_count
    from public.ai_provider_attempt_leases
   where provider = target_provider
     and expires_at > request_time;
  if active_attempt_count >= target_max_concurrent_requests then
    return 'concurrency_limited';
  end if;

  reserve_result := public.reserve_ai_provider_attempt(
    target_user_id,
    target_provider,
    target_global_limit,
    target_user_limit,
    target_provider_limit
  );
  if reserve_result <> 'allowed' then
    return reserve_result;
  end if;

  if target_initial_attempt then
    insert into public.ai_request_deduplication (
      user_id, request_fingerprint, requested_at
    )
    values (
      target_user_id, target_request_fingerprint, request_time
    )
    on conflict (user_id, request_fingerprint) do update
      set requested_at = excluded.requested_at;

    update public.ai_user_daily_usage
       set last_request_at = request_time
     where user_id = target_user_id;
  end if;

  insert into public.ai_provider_attempt_leases (
    user_id, provider, expires_at
  )
  values (
    target_user_id, target_provider, request_time + interval '120 seconds'
  )
  returning reservation_id into new_reservation_id;

  return 'allowed:' || new_reservation_id::text;
end;
$$;

create or replace function public.record_ai_provider_attempt_v2(
  target_provider text,
  target_status text,
  target_duration_ms integer,
  target_http_status integer,
  target_reservation_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  lease_provider text;
begin
  if target_reservation_id is null then
    raise exception using
      errcode = '22023',
      message = 'invalid_ai_provider_reservation';
  end if;

  select provider
    into lease_provider
    from public.ai_provider_attempt_leases
   where reservation_id = target_reservation_id
     and expires_at > pg_catalog.clock_timestamp()
   for update;
  if not found then
    raise exception using
      errcode = 'P0002',
      message = 'ai_provider_reservation_not_found';
  end if;
  if lease_provider <> target_provider then
    raise exception using
      errcode = 'P0002',
      message = 'ai_provider_reservation_not_found';
  end if;

  perform public.record_ai_provider_attempt(
    target_provider,
    target_status,
    target_duration_ms,
    target_http_status
  );
  delete from public.ai_provider_attempt_leases
   where reservation_id = target_reservation_id;

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
  coalesce(usage.request_count, 0)::bigint as daily_request_count,
  coalesce(active.request_count, 0)::bigint as active_request_count
from public.ai_provider_runtime_state state
left join public.ai_provider_daily_usage usage
  on usage.provider = state.provider
 and usage.usage_date = (now() at time zone 'UTC')::date
left join lateral (
  select count(*) as request_count
    from public.ai_provider_attempt_leases lease
   where lease.provider = state.provider
     and lease.expires_at > now()
) active on true;

revoke all on public.ai_provider_health from public, anon, authenticated;
grant select on public.ai_provider_health to service_role;

revoke all on function public.reserve_ai_provider_attempt_v2(
  uuid, text, integer, integer, integer, text, integer, integer, integer,
  boolean
) from public, anon, authenticated;
grant execute on function public.reserve_ai_provider_attempt_v2(
  uuid, text, integer, integer, integer, text, integer, integer, integer,
  boolean
) to service_role;

revoke all on function public.record_ai_provider_attempt_v2(
  text, text, integer, integer, uuid
) from public, anon, authenticated;
grant execute on function public.record_ai_provider_attempt_v2(
  text, text, integer, integer, uuid
) to service_role;

notify pgrst, 'reload schema';
