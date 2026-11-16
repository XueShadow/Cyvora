create or replace function public.create_family_invite(
  p_family_id uuid,
  p_invited_email text,
  p_token_hash text,
  p_invited_by uuid,
  p_expires_at timestamptz
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  invite_count bigint;
  invite_id uuid;
  request_time timestamptz;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('family_invites:' || p_family_id::text, 0)
  );
  request_time := pg_catalog.clock_timestamp();

  if not exists (
    select 1
      from public.family_members
     where family_id = p_family_id
       and user_id = p_invited_by
       and role = 'owner'
  ) then
    raise exception using
      errcode = '42501',
      message = 'family_owner_required';
  end if;

  select count(*)
    into invite_count
    from public.family_invites
   where family_id = p_family_id
     and created_at >= request_time - interval '1 hour';

  if invite_count >= 5 then
    raise exception using
      errcode = 'P0001',
      message = 'family_invite_rate_limit';
  end if;

  insert into public.family_invites (
    family_id,
    invited_email,
    token_hash,
    invited_by,
    expires_at,
    created_at
  )
  values (
    p_family_id,
    p_invited_email,
    p_token_hash,
    p_invited_by,
    p_expires_at,
    request_time
  )
  returning id into invite_id;

  return invite_id;
end;
$$;

revoke all on function public.create_family_invite(
  uuid, text, text, uuid, timestamptz
) from public, anon, authenticated;
grant execute on function public.create_family_invite(
  uuid, text, text, uuid, timestamptz
) to service_role;
