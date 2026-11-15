create or replace function public.mfa_access_allowed()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select not exists (
    select 1
    from auth.mfa_factors
    where user_id = (select auth.uid())
      and status = 'verified'
  )
  or (select auth.jwt() ->> 'aal') = 'aal2';
$$;

comment on function public.mfa_access_allowed() is
  'Allows AAL1 sessions for users without MFA and requires AAL2 for opted-in users.';

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles',
    'families',
    'family_members',
    'family_invites',
    'scan_records',
    'scam_reports',
    'alerts',
    'alert_reads',
    'user_settings',
    'threat_scan_results',
    'threat_provider_results',
    'threat_lookup_cache',
    'threat_provider_daily_usage',
    'analysis_module_results',
    'community_threat_reports',
    'detection_feedback',
    'example_submissions',
    'example_verifications',
    'example_admin_overrides',
    'dataset_versions',
    'trusted_training_examples',
    'intelligence_audit_logs'
  ]
  loop
    if to_regclass('public.' || table_name) is not null then
      execute format(
        'alter table public.%I enable row level security',
        table_name
      );
      execute format(
        'drop policy if exists mfa_required_for_opted_in_users on public.%I',
        table_name
      );
      execute format(
        'create policy mfa_required_for_opted_in_users on public.%I '
        'as restrictive for all to authenticated '
        'using (public.mfa_access_allowed()) '
        'with check (public.mfa_access_allowed())',
        table_name
      );
    end if;
  end loop;
end;
$$;
