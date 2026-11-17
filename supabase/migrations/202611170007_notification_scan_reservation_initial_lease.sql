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

revoke all on function public.reserve_notification_scan(uuid, uuid, text)
  from public, anon, authenticated;
grant execute on function public.reserve_notification_scan(uuid, uuid, text)
  to service_role;

notify pgrst, 'reload schema';
