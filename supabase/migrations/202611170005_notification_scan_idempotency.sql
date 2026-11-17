create table if not exists public.notification_scan_idempotency (
  user_id uuid not null references auth.users(id) on delete cascade,
  request_id uuid not null,
  request_fingerprint text not null
    check (request_fingerprint ~ '^[0-9a-f]{64}$'),
  status text not null default 'processing'
    check (status in ('processing', 'completed', 'deleted')),
  lease_token uuid not null default gen_random_uuid(),
  lease_expires_at timestamptz not null default now() + interval '5 minutes',
  scan_record_id uuid references public.scan_records(id) on delete set null,
  response jsonb check (
    response is null or jsonb_typeof(response) = 'object'
  ),
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  primary key (user_id, request_id),
  check (
    (status = 'processing' and response is null and completed_at is null)
    or (status = 'completed' and response is not null and completed_at is not null)
    or (status = 'deleted' and response is null and completed_at is not null)
  )
);

create index if not exists notification_scan_idempotency_completed_at
  on public.notification_scan_idempotency (completed_at)
  where status = 'completed';

alter table public.notification_scan_idempotency enable row level security;
revoke all on public.notification_scan_idempotency
  from public, anon, authenticated, service_role;

create or replace function public.mark_notification_scan_result_deleted()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.notification_scan_idempotency
  set status = 'deleted',
      lease_token = gen_random_uuid(),
      lease_expires_at = now(),
      response = null,
      completed_at = now()
  where scan_record_id = old.id
    and status = 'completed';
  return old;
end;
$$;

drop trigger if exists scan_records_mark_notification_result_deleted
  on public.scan_records;
create trigger scan_records_mark_notification_result_deleted
before delete on public.scan_records
for each row
execute function public.mark_notification_scan_result_deleted();

create or replace function public.reserve_notification_scan(
  target_user_id uuid,
  target_request_id uuid,
  target_request_fingerprint text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing public.notification_scan_idempotency%rowtype;
begin
  if target_user_id is null
     or target_request_id is null
     or target_request_fingerprint is null
     or target_request_fingerprint !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid notification scan reservation';
  end if;

  insert into public.notification_scan_idempotency (
    user_id, request_id, request_fingerprint
  )
  values (
    target_user_id, target_request_id, target_request_fingerprint
  )
  on conflict (user_id, request_id) do nothing
  returning * into existing;

  if found then
    return jsonb_build_object(
      'status', 'reserved',
      'lease_token', existing.lease_token
    );
  end if;

  select * into existing
  from public.notification_scan_idempotency
  where user_id = target_user_id and request_id = target_request_id
  for update;

  if existing.request_fingerprint <> target_request_fingerprint then
    return jsonb_build_object('status', 'conflict');
  end if;

  if existing.status = 'completed' then
    return jsonb_build_object(
      'status', 'completed',
      'response', existing.response
    );
  end if;

  if existing.status = 'deleted' then
    return jsonb_build_object('status', 'deleted');
  end if;

  if existing.lease_expires_at > now() then
    return jsonb_build_object('status', 'processing');
  end if;

  update public.notification_scan_idempotency
  set lease_token = gen_random_uuid(),
      lease_expires_at = now() + interval '5 minutes'
  where user_id = target_user_id and request_id = target_request_id
  returning * into existing;

  return jsonb_build_object(
    'status', 'reserved',
    'lease_token', existing.lease_token
  );
end;
$$;

create or replace function public.release_notification_scan(
  target_user_id uuid,
  target_request_id uuid,
  target_lease_token uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.notification_scan_idempotency
  where user_id = target_user_id
    and request_id = target_request_id
    and status = 'processing'
    and lease_token = target_lease_token;
$$;

create or replace function public.record_notification_threat_scan(
  target_user_id uuid,
  target_request_id uuid,
  target_lease_token uuid,
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
  reservation public.notification_scan_idempotency%rowtype;
  created_scan_id uuid;
  response_body jsonb;
begin
  select * into reservation
  from public.notification_scan_idempotency
  where user_id = target_user_id and request_id = target_request_id
  for update;

  if not found then
    raise exception 'notification scan reservation is unavailable';
  end if;

  if reservation.status = 'completed' then
    return reservation.scan_record_id;
  end if;

  if reservation.status <> 'processing'
     or reservation.lease_token <> target_lease_token
     or reservation.lease_expires_at <= now() then
    raise exception 'notification scan reservation has expired';
  end if;

  created_scan_id := public.record_threat_scan(
    target_user_id,
    target_scan_type,
    target_risk_level,
    target_indicators,
    target_assessment,
    target_analysis_modules
  );

  response_body := target_assessment -> 'unified_result';
  if jsonb_typeof(response_body) is distinct from 'object' then
    raise exception 'invalid notification scan response';
  end if;
  response_body := response_body || jsonb_build_object(
    'scan_id', created_scan_id,
    'record_id', created_scan_id
  );

  update public.notification_scan_idempotency
  set status = 'completed',
      lease_expires_at = now(),
      scan_record_id = created_scan_id,
      response = response_body,
      completed_at = now()
  where user_id = target_user_id and request_id = target_request_id;

  return created_scan_id;
end;
$$;

create or replace function public.delete_expired_notification_scan_idempotency()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_count integer;
begin
  delete from public.notification_scan_idempotency
  where (status = 'completed'
         and completed_at < now() - interval '35 days')
     or (status = 'deleted'
         and completed_at < now() - interval '35 days')
     or (status = 'processing'
         and lease_expires_at < now() - interval '1 day');

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

revoke all on function public.reserve_notification_scan(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.release_notification_scan(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.record_notification_threat_scan(
  uuid, uuid, uuid, text, text, text[], jsonb, jsonb
) from public, anon, authenticated;
revoke all on function public.delete_expired_notification_scan_idempotency()
  from public, anon, authenticated;
revoke all on function public.mark_notification_scan_result_deleted()
  from public, anon, authenticated, service_role;
grant execute on function public.reserve_notification_scan(uuid, uuid, text)
  to service_role;
grant execute on function public.release_notification_scan(uuid, uuid, uuid)
  to service_role;
grant execute on function public.record_notification_threat_scan(
  uuid, uuid, uuid, text, text, text[], jsonb, jsonb
) to service_role;
grant execute on function public.delete_expired_notification_scan_idempotency()
  to service_role;

do $migration$
begin
  if not exists (
    select 1
    from pg_available_extensions
    where name = 'pg_cron'
  ) then
    raise exception
      'pg_cron is required to enforce notification scan idempotency retention';
  end if;

  execute 'create extension if not exists pg_cron with schema extensions';

  if not exists (
    select 1
    from cron.job
    where jobname = 'delete-expired-notification-scan-idempotency'
  ) then
    perform cron.schedule(
      'delete-expired-notification-scan-idempotency',
      '20 2 * * *',
      $job$select public.delete_expired_notification_scan_idempotency()$job$
    );
  end if;
end;
$migration$;

notify pgrst, 'reload schema';
