-- Run only with the disposable local Supabase test database.
-- All fixture data is rolled back at the end of this file.
begin;

select plan(14);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at
)
values (
  '40000000-0000-0000-0000-000000000001',
  'authenticated',
  'authenticated',
  'notification-idempotency@example.test',
  '',
  now()
);

select has_table(
  'public',
  'notification_scan_idempotency',
  'notification scan idempotency state exists'
);
select ok(
  exists (
    select 1
    from cron.job
    where jobname = 'delete-expired-notification-scan-idempotency'
  ),
  'expired idempotency records have an automatic cleanup schedule'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.reserve_notification_scan(uuid,uuid,text)',
    'execute'
  ),
  'authenticated users cannot reserve notification scans directly'
);

set local role service_role;

create temporary table notification_idempotency_case (
  reservation jsonb not null,
  scan_id uuid,
  replayed_scan_id uuid
);

insert into notification_idempotency_case (reservation)
select public.reserve_notification_scan(
  '40000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001',
  repeat('a', 64)
);

select is(
  (select reservation ->> 'status' from notification_idempotency_case),
  'reserved',
  'the first notification request receives a processing lease'
);
select is(
  public.reserve_notification_scan(
    '40000000-0000-0000-0000-000000000001',
    '50000000-0000-0000-0000-000000000001',
    repeat('a', 64)
  ) ->> 'status',
  'processing',
  'a duplicate request cannot start concurrent analysis'
);
select is(
  public.reserve_notification_scan(
    '40000000-0000-0000-0000-000000000001',
    '50000000-0000-0000-0000-000000000001',
    repeat('b', 64)
  ) ->> 'status',
  'conflict',
  'a request key cannot be reused for different content'
);

select public.release_notification_scan(
  '40000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001',
  (select (reservation ->> 'lease_token')::uuid
   from notification_idempotency_case)
);
update notification_idempotency_case
set reservation = public.reserve_notification_scan(
  '40000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001',
  repeat('a', 64)
);
select is(
  (select reservation ->> 'status' from notification_idempotency_case),
  'reserved',
  'a released failed request can be retried'
);

update notification_idempotency_case
set scan_id = public.record_notification_threat_scan(
  '40000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001',
  (reservation ->> 'lease_token')::uuid,
  'message',
  'low',
  '{}'::text[],
  jsonb_build_object(
    'legacy_explanation', 'Idempotency test',
    'unified_result', jsonb_build_object(
      'classification', 'UNKNOWN',
      'risk_level', 'UNKNOWN',
      'confidence', 0,
      'analysis_summary', 'Idempotency test',
      'evidence', '[]'::jsonb,
      'rule_analysis', '{}'::jsonb,
      'ai_analysis', '{}'::jsonb,
      'analysis_modules_status', '{}'::jsonb,
      'recommended_actions', '[]'::jsonb,
      'confidence_reasons', '[]'::jsonb,
      'engine_version', 'idempotency-test',
      'analyzed_at', now()::text
    )
  ),
  '[]'::jsonb
);
select ok(
  (select scan_id is not null from notification_idempotency_case),
  'successful analysis and idempotency completion are committed together'
);

update notification_idempotency_case
set reservation = public.reserve_notification_scan(
  '40000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001',
  repeat('a', 64)
);
select is(
  (select reservation ->> 'status' from notification_idempotency_case),
  'completed',
  'a retry after completion receives the saved result'
);
select is(
  (select reservation #>> '{response,scan_id}'
   from notification_idempotency_case),
  (select scan_id::text from notification_idempotency_case),
  'the replay returns the original scan id'
);

update notification_idempotency_case
set replayed_scan_id = public.record_notification_threat_scan(
  '40000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001',
  '60000000-0000-0000-0000-000000000001',
  'message',
  'low',
  '{}'::text[],
  '{}'::jsonb,
  '[]'::jsonb
);
select is(
  (select replayed_scan_id from notification_idempotency_case),
  (select scan_id from notification_idempotency_case),
  'repeated completion cannot create a second result'
);
select is(
  (select count(*) from public.scan_records
   where user_id = '40000000-0000-0000-0000-000000000001'),
  1::bigint,
  'idempotent completion stores exactly one scan record'
);

delete from public.scan_records
where id = (select scan_id from notification_idempotency_case);
update notification_idempotency_case
set reservation = public.reserve_notification_scan(
  '40000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001',
  repeat('a', 64)
);
select is(
  (select reservation ->> 'status' from notification_idempotency_case),
  'deleted',
  'deleting scan history prevents an old notification from creating a new result'
);
select ok(
  (select not (reservation ? 'response')
   from notification_idempotency_case),
  'deleted scan results are not retained in the idempotency response'
);

select * from finish();
rollback;
