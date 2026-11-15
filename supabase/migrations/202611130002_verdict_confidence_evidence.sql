alter table public.threat_scan_results
  add column if not exists confidence_reasons jsonb not null default '[]'::jsonb
    check (case when jsonb_typeof(confidence_reasons) = 'array'
      then jsonb_array_length(confidence_reasons) <= 8 else false end);

alter table public.threat_scan_results
  drop constraint if exists threat_scan_results_analysis_classification_check,
  add constraint threat_scan_results_analysis_classification_check
    check (analysis_classification in ('SAFE', 'SUSPICIOUS', 'SCAM', 'MALICIOUS', 'UNKNOWN')),
  drop constraint if exists threat_scan_results_analysis_risk_level_check,
  add constraint threat_scan_results_analysis_risk_level_check
    check (analysis_risk_level in ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL', 'UNKNOWN', 'UNDETERMINED'));

alter table public.threat_provider_results
  drop constraint if exists threat_provider_results_status_check,
  add constraint threat_provider_results_status_check check (
    status in (
      'malicious', 'suspicious', 'enrichment', 'no_match', 'not_found',
      'unknown', 'unavailable', 'timeout', 'error', 'rate_limited',
      'unauthorized', 'not_consulted'
    )
  ),
  add column if not exists provider_status text not null default 'error'
    check (provider_status in (
      'success', 'not_found', 'rate_limited', 'timeout', 'error',
      'unauthorized', 'not_consulted'
    )),
  add column if not exists evidence_kind text not null default 'analysis_unavailable'
    check (evidence_kind in (
      'confirmed_detection', 'suspicious_signal', 'no_match', 'enrichment',
      'analysis_unavailable', 'analysis_failed'
    )),
  add column if not exists indicator_match boolean not null default false,
  add column if not exists source text not null default '',
  add column if not exists error_reason text,
  add column if not exists category text,
  add column if not exists detection_stats jsonb
    check (detection_stats is null or jsonb_typeof(detection_stats) = 'object'),
  add column if not exists analysis_date timestamptz;

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
    scan_record_id, user_id, classification, confidence, explanation,
    evidence, providers_consulted, provider_availability, checked_at,
    analysis_classification, analysis_risk_level, analysis_confidence,
    analysis_summary, rule_analysis, ai_analysis, providers_status,
    recommended_actions, engine_version, analyzed_at, confidence_reasons
  )
  values (
    created_scan_id,
    target_user_id,
    target_assessment ->> 'legacy_classification',
    coalesce((target_assessment ->> 'legacy_confidence')::numeric, 0),
    coalesce(target_assessment ->> 'legacy_explanation', 'Analysis completed.'),
    coalesce(target_assessment -> 'evidence', '[]'::jsonb),
    array(select jsonb_array_elements_text(
      coalesce(target_assessment -> 'providers_consulted', '[]'::jsonb)
    )),
    coalesce(target_assessment -> 'provider_availability', '{}'::jsonb),
    coalesce((target_assessment ->> 'checked_at')::timestamptz, now()),
    unified ->> 'classification',
    unified ->> 'risk_level',
    (unified ->> 'confidence')::integer,
    unified ->> 'analysis_summary',
    coalesce(unified -> 'rule_analysis', '{}'::jsonb),
    coalesce(unified -> 'ai_analysis', '{}'::jsonb),
    coalesce(unified -> 'providers_status', '{}'::jsonb),
    coalesce(unified -> 'recommended_actions', '[]'::jsonb),
    coalesce(unified ->> 'engine_version', 'bantai-analysis-2'),
    coalesce((unified ->> 'analyzed_at')::timestamptz, now()),
    coalesce(unified -> 'confidence_reasons', '[]'::jsonb)
  )
  returning id into created_threat_result_id;

  for provider_result in
    select value from jsonb_array_elements(target_provider_results)
  loop
    insert into public.threat_provider_results (
      threat_scan_result_id, user_id, provider, indicator_type, indicator_hash,
      status, classification, confidence, evidence, checked_at, cache_hit,
      provider_status, evidence_kind, indicator_match, source, error_reason,
      category, detection_stats, analysis_date
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
      coalesce((provider_result ->> 'cache_hit')::boolean, false),
      provider_result ->> 'provider_status',
      provider_result ->> 'evidence_kind',
      coalesce((provider_result ->> 'indicator_match')::boolean, false),
      coalesce(provider_result ->> 'source', ''),
      provider_result ->> 'error_reason',
      provider_result ->> 'category',
      provider_result -> 'detection_stats',
      (provider_result ->> 'analysis_date')::timestamptz
    );
  end loop;

  insert into public.analysis_audit_logs (
    user_id, scan_record_id, event, engine_version, providers_status, metadata
  )
  values (
    target_user_id,
    created_scan_id,
    'analysis_completed',
    coalesce(unified ->> 'engine_version', 'bantai-analysis-2'),
    coalesce(unified -> 'providers_status', '{}'::jsonb),
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
