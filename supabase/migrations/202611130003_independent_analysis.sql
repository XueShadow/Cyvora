drop function if exists public.prune_threat_lookup_cache(integer);
drop function if exists public.consume_threat_provider_quota(uuid, text);
drop function if exists public.consume_url_reputation_quota(uuid);
drop function if exists public.consume_threat_analysis_quota(uuid);

drop table if exists public.threat_lookup_cache;
drop table if exists public.threat_provider_daily_usage;
drop table if exists public.url_reputation_usage;
drop table if exists public.threat_analysis_usage;

alter table public.threat_scan_results
  rename column providers_status to analysis_modules_status;

alter table public.analysis_audit_logs
  rename column providers_status to analysis_modules_status;

update public.threat_scan_results
set analysis_modules_status = '{}'::jsonb;

update public.analysis_audit_logs
set analysis_modules_status = '{}'::jsonb;

alter table public.threat_scan_results
  drop column if exists providers_consulted,
  drop column if exists provider_availability;

alter table public.threat_scan_results
  add column if not exists confidence_reasons jsonb not null default '[]'::jsonb
    check (case when jsonb_typeof(confidence_reasons) = 'array'
      then jsonb_array_length(confidence_reasons) <= 8 else false end);

alter table public.threat_scan_results
  drop constraint if exists threat_scan_results_analysis_classification_check,
  add constraint threat_scan_results_analysis_classification_check
    check (analysis_classification in (
      'SAFE', 'SUSPICIOUS', 'MALICIOUS', 'UNKNOWN', 'SCAM'
    )),
  drop constraint if exists threat_scan_results_analysis_risk_level_check,
  add constraint threat_scan_results_analysis_risk_level_check
    check (analysis_risk_level in (
      'LOW', 'MEDIUM', 'HIGH', 'CRITICAL', 'UNKNOWN', 'UNDETERMINED'
    ));

create table if not exists public.analysis_module_results (
  id uuid primary key default gen_random_uuid(),
  threat_scan_result_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  module text not null check (module in (
    'url_structure', 'domain_dns', 'ssl_tls', 'redirect_analysis',
    'suspicious_patterns', 'local_indicator_database', 'community_reports',
    'scam_pattern_recognition'
  )),
  indicator_type text check (indicator_type in ('url', 'domain', 'ip')),
  indicator_hash text check (
    indicator_hash is null or indicator_hash ~ '^[0-9a-f]{64}$'
  ),
  status text not null check (status in (
    'completed', 'unavailable', 'failed', 'not_applicable'
  )),
  evidence_kind text not null check (evidence_kind in (
    'confirmed_detection', 'suspicious_signal', 'no_match', 'not_checked',
    'analysis_unavailable', 'analysis_failed'
  )),
  check (
    (status = 'completed' and evidence_kind in (
      'confirmed_detection', 'suspicious_signal', 'no_match', 'not_checked'
    )) or
    (status = 'unavailable' and evidence_kind = 'analysis_unavailable') or
    (status = 'failed' and evidence_kind = 'analysis_failed') or
    (status = 'not_applicable' and evidence_kind = 'not_checked')
  ),
  confidence numeric(4, 3) not null check (confidence between 0 and 1),
  evidence jsonb not null default '[]'::jsonb
    check (case when jsonb_typeof(evidence) = 'array'
      then jsonb_array_length(evidence) <= 8 else false end),
  source text not null check (char_length(source) <= 120),
  error_reason text check (error_reason is null or char_length(error_reason) <= 300),
  category text check (category is null or char_length(category) <= 80),
  details jsonb not null default '{}'::jsonb
    check (jsonb_typeof(details) = 'object'),
  checked_at timestamptz not null default now(),
  foreign key (threat_scan_result_id)
    references public.threat_scan_results(id) on delete cascade
);

create index if not exists analysis_module_results_scan_module
  on public.analysis_module_results (threat_scan_result_id, module);
create index if not exists analysis_module_results_user_checked
  on public.analysis_module_results (user_id, checked_at desc);

create table if not exists public.local_threat_indicators (
  id uuid primary key default gen_random_uuid(),
  indicator_type text not null check (indicator_type in ('url', 'domain', 'ip')),
  indicator_hash text not null check (indicator_hash ~ '^[0-9a-f]{64}$'),
  category text not null check (char_length(category) between 1 and 80),
  source_note text,
  active boolean not null default true,
  reviewed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  check (not active or reviewed_by is not null),
  unique (indicator_type, indicator_hash)
);

create table if not exists public.community_threat_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  indicator_type text not null check (indicator_type in ('url', 'domain', 'ip')),
  indicator_hash text not null check (indicator_hash ~ '^[0-9a-f]{64}$'),
  category text not null check (char_length(category) between 1 and 80),
  review_status text not null default 'pending'
    check (review_status in ('pending', 'confirmed', 'rejected')),
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  check (
    (review_status = 'pending' and reviewed_by is null and reviewed_at is null) or
    (review_status in ('confirmed', 'rejected') and reviewed_by is not null
      and reviewed_at is not null)
  ),
  unique (reporter_id, indicator_type, indicator_hash)
);

create index if not exists local_threat_indicators_hash
  on public.local_threat_indicators (indicator_hash) where active;
create index if not exists community_threat_reports_hash_review
  on public.community_threat_reports (indicator_hash, review_status);

alter table public.analysis_module_results enable row level security;
alter table public.local_threat_indicators enable row level security;
alter table public.community_threat_reports enable row level security;

revoke all on public.analysis_module_results, public.local_threat_indicators,
  public.community_threat_reports
  from public, anon, authenticated;
grant select on public.analysis_module_results,
  public.community_threat_reports to authenticated;
grant all on public.analysis_module_results, public.local_threat_indicators,
  public.community_threat_reports to service_role;

drop policy if exists analysis_module_results_select_self
  on public.analysis_module_results;
create policy analysis_module_results_select_self
  on public.analysis_module_results
  for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists community_threat_reports_select_self
  on public.community_threat_reports;
create policy community_threat_reports_select_self
  on public.community_threat_reports
  for select to authenticated
  using (reporter_id = (select auth.uid()));

revoke all on public.threat_provider_results from public, anon, authenticated;
grant all on public.threat_provider_results to service_role;

drop function if exists public.record_threat_scan(
  uuid, text, text, text[], jsonb, jsonb
);

create function public.record_threat_scan(
  target_user_id uuid,
  target_scan_type text,
  target_risk_level text,
  target_indicators text[],
  target_assessment jsonb,
  target_analysis_modules jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  created_scan_id uuid;
  created_threat_result_id uuid;
  module_result jsonb;
  unified jsonb := target_assessment -> 'unified_result';
begin
  if target_scan_type not in ('message', 'url', 'screenshot') then
    raise exception 'unsupported scan type';
  end if;
  if target_risk_level not in ('low', 'review', 'high') then
    raise exception 'unsupported risk level';
  end if;
  if jsonb_typeof(unified) is distinct from 'object'
     or jsonb_typeof(target_analysis_modules) is distinct from 'array'
     or jsonb_array_length(target_analysis_modules) > 50 then
    raise exception 'invalid analysis assessment';
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
    scan_record_id, user_id, classification, confidence, explanation,
    evidence, checked_at,
    analysis_classification, analysis_risk_level, analysis_confidence,
    analysis_summary, rule_analysis, ai_analysis, analysis_modules_status,
    recommended_actions, engine_version, analyzed_at, confidence_reasons
  )
  values (
    created_scan_id,
    target_user_id,
    'unknown',
    0,
    left(coalesce(target_assessment ->> 'legacy_explanation', 'Analysis completed.'), 300),
    coalesce(unified -> 'evidence', '[]'::jsonb),
    coalesce((unified ->> 'analyzed_at')::timestamptz, now()),
    unified ->> 'classification',
    unified ->> 'risk_level',
    (unified ->> 'confidence')::integer,
    unified ->> 'analysis_summary',
    coalesce(unified -> 'rule_analysis', '{}'::jsonb),
    coalesce(unified -> 'ai_analysis', '{}'::jsonb),
    coalesce(unified -> 'analysis_modules_status', '{}'::jsonb),
    coalesce(unified -> 'recommended_actions', '[]'::jsonb),
    coalesce(unified ->> 'engine_version', 'bantai-independent-analysis-1'),
    coalesce((unified ->> 'analyzed_at')::timestamptz, now()),
    coalesce(unified -> 'confidence_reasons', '[]'::jsonb)
  )
  returning id into created_threat_result_id;

  for module_result in
    select value from jsonb_array_elements(target_analysis_modules)
  loop
    insert into public.analysis_module_results (
      threat_scan_result_id, user_id, module, indicator_type, indicator_hash,
      status, evidence_kind, confidence, evidence, source, error_reason,
      category, details, checked_at
    )
    values (
      created_threat_result_id,
      target_user_id,
      module_result ->> 'module',
      module_result ->> 'indicator_type',
      module_result ->> 'indicator_hash',
      module_result ->> 'status',
      module_result ->> 'evidence_kind',
      (module_result ->> 'confidence')::numeric,
      coalesce(module_result -> 'evidence', '[]'::jsonb),
      coalesce(module_result ->> 'source', 'BantAI local analysis'),
      module_result ->> 'error_reason',
      module_result ->> 'category',
      coalesce(module_result -> 'details', '{}'::jsonb),
      coalesce((module_result ->> 'checked_at')::timestamptz, now())
    );
  end loop;

  insert into public.analysis_audit_logs (
    user_id, scan_record_id, event, engine_version,
    analysis_modules_status, metadata
  )
  values (
    target_user_id,
    created_scan_id,
    'analysis_completed',
    coalesce(unified ->> 'engine_version', 'bantai-independent-analysis-1'),
    coalesce(unified -> 'analysis_modules_status', '{}'::jsonb),
    jsonb_build_object(
      'scan_type', target_scan_type,
      'indicator_count', jsonb_array_length(
        coalesce(unified -> 'indicators', '[]'::jsonb)
      ),
      'ai_status', coalesce(unified #>> '{ai_analysis,status}', 'disabled')
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

notify pgrst, 'reload schema';
