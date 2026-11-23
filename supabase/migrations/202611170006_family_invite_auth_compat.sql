create or replace function public.consume_family_invite(
  invite_token_hash text,
  joining_user_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  invitation public.family_invites%rowtype;
  account_email text;
  email_confirmed_at timestamptz;
begin
  select *
    into invitation
    from public.family_invites
   where token_hash = invite_token_hash
     and accepted_at is null
     and expires_at > now()
   for update;

  if not found then
    raise exception 'Invitation is invalid or expired';
  end if;

  select
    u.email,
    coalesce(
      nullif(to_jsonb(u) ->> 'email_confirmed_at', '')::timestamptz,
      nullif(to_jsonb(u) ->> 'confirmed_at', '')::timestamptz
    )
    into account_email, email_confirmed_at
    from auth.users u
   where u.id = joining_user_id;

  if account_email is null
     or email_confirmed_at is null
     or lower(account_email) <> lower(invitation.invited_email) then
    raise exception 'Sign in with the verified email address that received this invitation';
  end if;

  insert into public.family_members (family_id, user_id, role)
  values (invitation.family_id, joining_user_id, 'member');

  update public.family_invites
     set accepted_at = now()
   where id = invitation.id;

  return invitation.family_id;
end;
$$;

revoke all on function public.consume_family_invite(text, uuid)
  from public, anon, authenticated;
grant execute on function public.consume_family_invite(text, uuid)
  to service_role;
