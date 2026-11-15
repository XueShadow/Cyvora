create table if not exists public.threat_scan_results (
  id uuid primary key default gen_random_uuid(),
  scan_record_id uuid not null unique
    references public.scan_records(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  classification text not null check (
    classification in ('unknown', 'safe', 'low', 'medium', 'high', 'critical')
  ),
  confidence numeric(4, 3) not null check (confidence between 0 and 1),
  explanation text not null check (char_length(explanation) between 1 and 300),
  evidence jsonb not null default '[]'::jsonb
    check (case when jsonb_typeof(evidence) = 'array'
      then jsonb_array_length(evidence) <= 12 else false end),
  providers_consulted text[] not null default '{}'
    check (cardinality(providers_consulted) <= 3),
  provider_availability jsonb not null default '{}'::jsonb
    check (jsonb_typeof(provider_availability) = 'object'),
  checked_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (id, user_id)
);

create index if not exists threat_scan_results_user_checked
  on public.threat_scan_results (user_id, checked_at desc);

create table if not exists public.threat_provider_results (
  id uuid primary key default gen_random_uuid(),
  threat_scan_result_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in ('urlhaus', 'pulsedive', 'virustotal')),
  indicator_type text not null check (indicator_type in ('url', 'domain', 'ip')),
  indicator_hash text not null check (indicator_hash ~ '^[0-9a-f]{64}$'),
  status text not null check (
    status in (
      'malicious', 'suspicious', 'no_match', 'not_found', 'unknown',
      'unavailable', 'rate_limited', 'unauthorized', 'not_consulted'
    )
  ),
  classification text not null check (
    classification in ('unknown', 'safe', 'low', 'medium', 'high', 'critical')
  ),
  confidence numeric(4, 3) not null check (confidence between 0 and 1),
  evidence jsonb not null default '[]'::jsonb
    check (case when jsonb_typeof(evidence) = 'array'
      then jsonb_array_length(evidence) <= 5 else false end),
  checked_at timestamptz not null default now(),
  cache_hit boolean not null default false,
  foreign key (threat_scan_result_id, user_id)
    references public.threat_scan_results(id, user_id) on delete cascade,
  unique (threat_scan_result_id, provider, indicator_hash)
);

create index if not exists threat_provider_results_user_checked
  on public.threat_provider_results (user_id, checked_at desc);

create table if not exists public.threat_lookup_cache (
  cache_key text primary key check (cache_key ~ '^(urlhaus|pulsedive|virustotal):[0-9a-f]{64}$'),
  provider text not null check (provider in ('urlhaus', 'pulsedive', 'virustotal')),
  indicator_type text not null check (indicator_type in ('url', 'domain', 'ip')),
  indicator_hash text not null check (indicator_hash ~ '^[0-9a-f]{64}$'),
  normalized_result jsonb not null
    check (jsonb_typeof(normalized_result) = 'object'),
  last_checked_at timestamptz not null default now(),
  expires_at timestamptz not null,
  check (expires_at > last_checked_at)
);

create index if not exists threat_lookup_cache_expiry
  on public.threat_lookup_cache (expires_at);

create table if not exists public.threat_provider_daily_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in ('urlhaus', 'pulsedive')),
  usage_day date not null,
  request_count integer not null check (request_count between 1 and 30),
  primary key (user_id, provider, usage_day)
);

alter table public.threat_scan_results enable row level security;
alter table public.threat_provider_results enable row level security;
alter table public.threat_lookup_cache enable row level security;
alter table public.threat_provider_daily_usage enable row level security;

revoke all on public.threat_scan_results, public.threat_provider_results,
  public.threat_lookup_cache, public.threat_provider_daily_usage
  from public, anon, authenticated;

drop policy if exists threat_scan_results_select_self
  on public.threat_scan_results;
create policy threat_scan_results_select_self
  on public.threat_scan_results
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists threat_provider_results_select_self
  on public.threat_provider_results;
create policy threat_provider_results_select_self
  on public.threat_provider_results
  for select to authenticated
  using (user_id = (select auth.uid()));

grant select on public.threat_scan_results,
  public.threat_provider_results to authenticated;
grant all on public.threat_scan_results,
  public.threat_provider_results,
  public.threat_lookup_cache,
  public.threat_provider_daily_usage to service_role;

create or replace function public.consume_threat_provider_quota(
  target_user_id uuid,
  target_provider text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  resulting_count integer;
begin
  if target_provider not in ('urlhaus', 'pulsedive') then
    raise exception 'unsupported threat provider';
  end if;

  insert into public.threat_provider_daily_usage (
    user_id, provider, usage_day, request_count
  )
  values (
    target_user_id,
    target_provider,
    (now() at time zone 'utc')::date,
    1
  )
  on conflict (user_id, provider, usage_day)
  do update set request_count =
    public.threat_provider_daily_usage.request_count + 1
  where public.threat_provider_daily_usage.request_count < 30
  returning request_count into resulting_count;

  return resulting_count is not null;
end;
$$;

revoke all on function public.consume_threat_provider_quota(uuid, text)
  from public, anon, authenticated;
grant execute on function public.consume_threat_provider_quota(uuid, text)
  to service_role;

create or replace function public.record_threat_scan(
  target_user_id uuid,
  target_scan_type text,
  target_risk_level text,
  target_indicators text[],
  target_assessment jsonb,
  target_provider_results jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  created_scan_id uuid;
  created_threat_result_id uuid;
  provider_result jsonb;
begin
  if target_scan_type not in ('message', 'url', 'screenshot') then
    raise exception 'unsupported scan type';
  end if;
  if target_risk_level not in ('low', 'review', 'high') then
    raise exception 'unsupported risk level';
  end if;
  if jsonb_typeof(target_assessment) <> 'object'
     or jsonb_typeof(target_provider_results) <> 'array'
     or jsonb_array_length(target_provider_results) > 30 then
    raise exception 'invalid threat assessment';
  end if;

  insert into public.scan_records (
    user_id, scan_type, risk_level, indicators
  )
  values (
    target_user_id, target_scan_type, target_risk_level,
    coalesce(target_indicators, '{}'::text[])
  )
  returning id into created_scan_id;

  insert into public.threat_scan_results (
    scan_record_id,
    user_id,
    classification,
    confidence,
    explanation,
    evidence,
    providers_consulted,
    provider_availability,
    checked_at
  )
  values (
    created_scan_id,
    target_user_id,
    target_assessment ->> 'classification',
    (target_assessment ->> 'confidence')::numeric,
    target_assessment ->> 'explanation',
    target_assessment -> 'evidence',
    array(
      select jsonb_array_elements_text(
        target_assessment -> 'providers_consulted'
      )
    ),
    target_assessment -> 'provider_availability',
    (target_assessment ->> 'checked_at')::timestamptz
  )
  returning id into created_threat_result_id;

  for provider_result in
    select value from jsonb_array_elements(target_provider_results)
  loop
    insert into public.threat_provider_results (
      threat_scan_result_id,
      user_id,
      provider,
      indicator_type,
      indicator_hash,
      status,
      classification,
      confidence,
      evidence,
      checked_at,
      cache_hit
    )
    values (
      created_threat_result_id,
      target_user_id,
      provider_result ->> 'provider',
      provider_result ->> 'indicator_type',
      provider_result ->> 'indicator_hash',
      provider_result ->> 'status',
      provider_result ->> 'classification',
      (provider_result ->> 'confidence')::numeric,
      provider_result -> 'evidence',
      (provider_result ->> 'checked_at')::timestamptz,
      coalesce((provider_result ->> 'cache_hit')::boolean, false)
    );
  end loop;

  return created_scan_id;
end;
$$;

revoke all on function public.record_threat_scan(
  uuid, text, text, text[], jsonb, jsonb
) from public, anon, authenticated;
grant execute on function public.record_threat_scan(
  uuid, text, text, text[], jsonb, jsonb
) to service_role;

create or replace function public.prune_threat_lookup_cache(
  max_rows integer default 500
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_count integer;
  deleted_usage_count integer;
begin
  if max_rows < 1 or max_rows > 5000 then
    raise exception 'max_rows must be between 1 and 5000';
  end if;

  with expired as (
    select cache_key
    from public.threat_lookup_cache
    where expires_at <= now()
    order by expires_at
    limit max_rows
  )
  delete from public.threat_lookup_cache cache
  using expired
  where cache.cache_key = expired.cache_key;

  get diagnostics deleted_count = row_count;

  with expired as (
    select user_id, provider, usage_day
    from public.threat_provider_daily_usage
    where usage_day < (now() at time zone 'utc')::date - 30
    order by usage_day
    limit max_rows
  )
  delete from public.threat_provider_daily_usage usage
  using expired
  where usage.user_id = expired.user_id
    and usage.provider = expired.provider
    and usage.usage_day = expired.usage_day;

  get diagnostics deleted_usage_count = row_count;
  return deleted_count + deleted_usage_count;
end;
$$;

revoke all on function public.prune_threat_lookup_cache(integer)
  from public, anon, authenticated;
grant execute on function public.prune_threat_lookup_cache(integer)
  to service_role;

grant all on public.threat_scan_results,
  public.threat_provider_results,
  public.threat_lookup_cache to service_role;
