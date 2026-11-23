create or replace function public.mfa_access_allowed()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when coalesce(
      (select auth.jwt() -> 'app_metadata' ->> 'role'),
      ''
    ) in ('super_admin', 'admin', 'moderator', 'support_admin')
    then
      exists (
        select 1
        from auth.mfa_factors
        where user_id = (select auth.uid())
          and status = 'verified'
      )
      and (select auth.jwt() ->> 'aal') = 'aal2'
    else
      not exists (
        select 1
        from auth.mfa_factors
        where user_id = (select auth.uid())
          and status = 'verified'
      )
      or (select auth.jwt() ->> 'aal') = 'aal2'
  end;
$$;

comment on function public.mfa_access_allowed() is
  'Requires verified MFA and AAL2 for privileged administrator roles; preserves opt-in MFA for regular users.';
