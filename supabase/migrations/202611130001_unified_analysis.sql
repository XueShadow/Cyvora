alter table public.threat_scan_results
  add column if not exists analysis_classification text
    check (analysis_classification in ('SAFE', 'SUSPICIOUS', 'SCAM', 'UNKNOWN')),
  add column if not exists analysis_risk_level text
    check (analysis_risk_level in ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL', 'UNKNOWN')),
  add column if not exists analysis_confidence integer
    check (analysis_confidence between 0 and 100),
  add column if not exists analysis_summary text,
  add column if not exists rule_analysis jsonb not null default '{}'::jsonb
    check (jsonb_typeof(rule_analysis) = 'object'),
  add column if not exists ai_analysis jsonb not null default '{}'::jsonb
    check (jsonb_typeof(ai_analysis) = 'object'),
  add column if not exists providers_status jsonb not null default '{}'::jsonb
    check (jsonb_typeof(providers_status) = 'object'),
  add column if not exists recommended_actions jsonb not null default '[]'::jsonb
    check (case when jsonb_typeof(recommended_actions) = 'array'
      then jsonb_array_length(recommended_actions) <= 5 else false end),
  add column if not exists engine_version text not null default 'legacy',
  add column if not exists analyzed_at timestamptz not null default now();

create table if not exists public.scam_patterns (
  id uuid primary key default gen_random_uuid(),
  version text not null,
  rule_id text not null,
  enabled boolean not null default true,
  weight integer not null check (weight between 0 and 10),
  updated_at timestamptz not null default now(),
  unique (version, rule_id)
);

insert into public.scam_patterns (version, rule_id, weight)
values
  ('bantai-rules-1', 'Urgent or coercive language', 1),
  ('bantai-rules-1', 'Account recovery or identity theft pressure', 2),
  ('bantai-rules-1', 'Requests for passwords or security codes', 4),
  ('bantai-rules-1', 'Payment or account-verification trap', 3),
  ('bantai-rules-1', 'Requests for secrecy or isolation', 2),
  ('bantai-rules-1', 'Unexpected prize, reward, or refund', 1),
  ('bantai-rules-1', 'Suspicious or unusual URL characteristics', 1),
  ('bantai-rules-1', 'Unusual URL structure', 1),
  ('bantai-rules-1', 'Shortened, hidden, or redirecting link', 1),
  ('bantai-rules-1', 'Impersonation or brand spoofing', 3),
  ('bantai-rules-1', 'Suspicious sender or domain mismatch', 3),
  ('bantai-rules-1', 'Domain or sender claims need independent verification', 1),
  ('bantai-rules-1', 'Potentially misleading link text', 1)
on conflict (version, rule_id) do nothing;

create table if not exists public.detection_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  scan_record_id uuid not null references public.scan_records(id) on delete cascade,
  feedback text not null check (feedback in ('correct', 'false_positive', 'false_negative')),
  created_at timestamptz not null default now(),
  unique (user_id, scan_record_id)
);

create index if not exists detection_feedback_created
  on public.detection_feedback (created_at);

create table if not exists public.analysis_audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  scan_record_id uuid references public.scan_records(id) on delete set null,
  event text not null check (event in ('analysis_completed', 'analysis_failed')),
  engine_version text not null,
  providers_status jsonb not null default '{}'::jsonb
    check (jsonb_typeof(providers_status) = 'object'),
  metadata jsonb not null default '{}'::jsonb
    check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);

create index if not exists analysis_audit_logs_user_created
  on public.analysis_audit_logs (user_id, created_at desc);
create index if not exists analysis_audit_logs_created
  on public.analysis_audit_logs (created_at);

alter table public.scam_patterns enable row level security;
alter table public.detection_feedback enable row level security;
alter table public.analysis_audit_logs enable row level security;

revoke all on public.scam_patterns, public.detection_feedback,
  public.analysis_audit_logs from public, anon, authenticated;
grant select, insert, update, delete on public.scam_patterns to service_role;
grant select, insert, update, delete on public.detection_feedback,
  public.analysis_audit_logs to service_role;

drop policy if exists detection_feedback_select_self
  on public.detection_feedback;
create policy detection_feedback_select_self
  on public.detection_feedback
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists detection_feedback_insert_self
  on public.detection_feedback;
create policy detection_feedback_insert_self
  on public.detection_feedback
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.scan_records s
      where s.id = scan_record_id and s.user_id = (select auth.uid())
    )
  );
grant select, insert on public.detection_feedback to authenticated;

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
  unified jsonb := target_assessment -> 'unified_result';
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
    checked_at,
    analysis_classification,
    analysis_risk_level,
    analysis_confidence,
    analysis_summary,
    rule_analysis,
    ai_analysis,
    providers_status,
    recommended_actions,
    engine_version,
    analyzed_at
  )
  values (
    created_scan_id,
    target_user_id,
    target_assessment ->> 'legacy_classification',
    coalesce((target_assessment ->> 'legacy_confidence')::numeric, 0),
    coalesce(target_assessment ->> 'legacy_explanation', 'Analysis completed.'),
    coalesce(target_assessment -> 'evidence', '[]'::jsonb),
    array(
      select jsonb_array_elements_text(
        coalesce(target_assessment -> 'providers_consulted', '[]'::jsonb)
      )
    ),
    coalesce(target_assessment -> 'provider_availability', '{}'::jsonb),
    coalesce(
      (target_assessment ->> 'checked_at')::timestamptz,
      now()
    ),
    unified ->> 'classification',
    unified ->> 'risk_level',
    (unified ->> 'confidence')::integer,
    unified ->> 'analysis_summary',
    coalesce(unified -> 'rule_analysis', '{}'::jsonb),
    coalesce(unified -> 'ai_analysis', '{}'::jsonb),
    coalesce(unified -> 'providers_status', '{}'::jsonb),
    coalesce(unified -> 'recommended_actions', '[]'::jsonb),
    coalesce(unified ->> 'engine_version', 'bantai-analysis-1'),
    coalesce((unified ->> 'analyzed_at')::timestamptz, now())
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

  insert into public.analysis_audit_logs (
    user_id, scan_record_id, event, engine_version, providers_status, metadata
  )
  values (
    target_user_id,
    created_scan_id,
    'analysis_completed',
    coalesce(unified ->> 'engine_version', 'bantai-analysis-1'),
    coalesce(unified -> 'providers_status', '{}'::jsonb),
    jsonb_build_object(
      'scan_type', target_scan_type,
      'indicator_count', jsonb_array_length(
        coalesce(unified -> 'indicators', '[]'::jsonb)
      ),
      'ai_status', coalesce(unified #>> '{ai_analysis,status}', 'not_requested')
    )
  );

  return created_scan_id;
end;
$$;

revoke all on function public.record_threat_scan(
  uuid, text, text, text[], jsonb, jsonb
) from public, anon, authenticated;
grant execute on function public.record_threat_scan(
  uuid, text, text, text[], jsonb, jsonb
) to service_role;

create or replace function public.prune_analysis_data(
  max_rows integer default 500
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_count integer;
begin
  if max_rows < 1 or max_rows > 5000 then
    raise exception 'max_rows must be between 1 and 5000';
  end if;
  with expired as (
    select id from public.analysis_audit_logs
    where created_at < now() - interval '90 days'
    order by created_at limit max_rows
  )
  delete from public.analysis_audit_logs logs
  using expired
  where logs.id = expired.id;
  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

revoke all on function public.prune_analysis_data(integer)
  from public, anon, authenticated;
grant execute on function public.prune_analysis_data(integer) to service_role;
