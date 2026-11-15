create or replace view public.provider_health_daily
with (security_invoker = true)
as
with provider_events as (
  select
    'ai'::text as provider_type,
    attempt.value ->> 'provider' as provider,
    attempt.value ->> 'status' as status,
    case
      when (attempt.value ->> 'duration_ms') ~ '^[0-9]{1,7}$'
        then (attempt.value ->> 'duration_ms')::integer
      else null
    end as duration_ms,
    result.analyzed_at as checked_at
  from public.threat_scan_results result
  cross join lateral jsonb_array_elements(
    case
      when jsonb_typeof(result.ai_analysis -> 'provider_attempts') = 'array'
        then result.ai_analysis -> 'provider_attempts'
      else '[]'::jsonb
    end
  ) as attempt(value)
  where result.analyzed_at >= now() - interval '30 days'

  union all

  select
    'url_reputation'::text as provider_type,
    provider.value ->> 'provider' as provider,
    provider.value ->> 'status' as status,
    case
      when (provider.value ->> 'duration_ms') ~ '^[0-9]{1,7}$'
        then (provider.value ->> 'duration_ms')::integer
      else null
    end as duration_ms,
    module.checked_at
  from public.analysis_module_results module
  cross join lateral jsonb_array_elements(
    case
      when jsonb_typeof(module.details -> 'providers') = 'array'
        then module.details -> 'providers'
      else '[]'::jsonb
    end
  ) as provider(value)
  where module.module = 'external_threat_intelligence'
    and module.checked_at >= now() - interval '30 days'
)
select
  date_trunc('day', checked_at)::date as day,
  provider_type,
  provider,
  status,
  count(*)::bigint as attempt_count,
  round(avg(duration_ms)::numeric, 2) as average_duration_ms
from provider_events
where provider is not null
  and status is not null
  and status <> 'not_configured'
group by 1, 2, 3, 4;

create or replace view public.detection_feedback_daily
with (security_invoker = true)
as
select
  date_trunc('day', feedback.created_at)::date as day,
  coalesce(result.engine_version, 'legacy') as engine_version,
  scan.scan_type,
  scan.risk_level,
  feedback.feedback,
  count(*)::bigint as feedback_count,
  count(distinct feedback.user_id)::bigint as reporter_count
from public.detection_feedback feedback
join public.scan_records scan on scan.id = feedback.scan_record_id
left join public.threat_scan_results result
  on result.scan_record_id = scan.id
where feedback.created_at >= now() - interval '90 days'
group by 1, 2, 3, 4, 5;

revoke all on public.provider_health_daily,
  public.detection_feedback_daily from public, anon, authenticated;
grant select on public.provider_health_daily,
  public.detection_feedback_daily to service_role;
