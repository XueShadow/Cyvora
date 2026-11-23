create or replace view public.admin_user_directory as
select
  id,
  email,
  email_confirmed_at,
  created_at,
  last_sign_in_at,
  banned_until,
  raw_app_meta_data ->> 'role' as admin_role,
  coalesce(banned_until > now(), false) as is_suspended
from auth.users;

create or replace view public.admin_family_directory as
select
  family.id as family_id,
  family.name,
  family.created_at,
  count(distinct member.user_id)::bigint as member_count,
  count(distinct invite.id) filter (
    where invite.accepted_at is null and invite.expires_at > now()
  )::bigint as pending_invites
from public.families family
left join public.family_members member on member.family_id = family.id
left join public.family_invites invite on invite.family_id = family.id
group by family.id, family.name, family.created_at;

create or replace view public.admin_dashboard_daily as
with registrations as (
  select
    date_trunc('day', account.created_at)::date as day,
    count(*)::bigint as registration_count
  from auth.users account
  group by 1
),
scans as (
  select
    date_trunc('day', scan.created_at)::date as day,
    count(*)::bigint as scan_count,
    count(*) filter (where scan.risk_level = 'low')::bigint as low_risk_count,
    count(*) filter (where scan.risk_level = 'review')::bigint as review_risk_count,
    count(*) filter (where scan.risk_level = 'high')::bigint as high_risk_count
  from public.scan_records scan
  group by 1
)
select
  coalesce(registrations.day, scans.day) as day,
  coalesce(registrations.registration_count, 0)::bigint as registration_count,
  coalesce(scans.scan_count, 0)::bigint as scan_count,
  coalesce(scans.low_risk_count, 0)::bigint as low_risk_count,
  coalesce(scans.review_risk_count, 0)::bigint as review_risk_count,
  coalesce(scans.high_risk_count, 0)::bigint as high_risk_count
from registrations
full outer join scans using (day);

create or replace view public.admin_family_security_events as
select
  alert.family_id,
  date_trunc('day', alert.created_at)::date as day,
  alert.severity,
  count(*)::bigint as event_count
from public.alerts alert
where alert.family_id is not null
group by 1, 2, 3;

create or replace view public.admin_family_membership_directory as
select family_id, user_id, role, joined_at
from public.family_members;

create or replace view public.admin_family_invitation_directory as
select id, family_id, created_at, expires_at, accepted_at
from public.family_invites;

revoke all on public.admin_user_directory, public.admin_family_directory,
  public.admin_dashboard_daily, public.admin_family_security_events,
  public.admin_family_membership_directory, public.admin_family_invitation_directory
  from public, anon, authenticated;
grant select on public.admin_user_directory, public.admin_family_directory,
  public.admin_dashboard_daily, public.admin_family_security_events,
  public.admin_family_membership_directory, public.admin_family_invitation_directory
  to service_role;

create table if not exists public.admin_audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid,
  actor_role text check (
    actor_role is null or actor_role in (
      'super_admin', 'admin', 'moderator', 'support_admin'
    )
  ),
  action text not null check (char_length(action) between 1 and 80),
  target_type text not null check (char_length(target_type) between 1 and 50),
  target_id text check (target_id is null or char_length(target_id) <= 120),
  outcome text not null check (outcome in (
    'started', 'succeeded', 'failed', 'denied'
  )),
  request_id uuid not null,
  metadata jsonb not null default '{}'::jsonb
    check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_logs_created
  on public.admin_audit_logs (created_at desc);
create index if not exists admin_audit_logs_actor_created
  on public.admin_audit_logs (actor_id, created_at desc);
create index if not exists admin_audit_logs_action_created
  on public.admin_audit_logs (action, created_at desc);

alter table public.admin_audit_logs enable row level security;
revoke all on public.admin_audit_logs from public, anon, authenticated;
revoke all on public.admin_audit_logs from service_role;
grant select, insert on public.admin_audit_logs to service_role;
grant usage, select on sequence public.admin_audit_logs_id_seq to service_role;

create or replace function public.reject_admin_audit_log_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Administrative audit logs are append-only';
end;
$$;

drop trigger if exists admin_audit_logs_append_only
  on public.admin_audit_logs;
create trigger admin_audit_logs_append_only
  before update or delete on public.admin_audit_logs
  for each row execute function public.reject_admin_audit_log_mutation();

revoke all on function public.reject_admin_audit_log_mutation()
  from public, anon, authenticated, service_role;

create table if not exists public.admin_account_deletion_requests (
  id uuid primary key default gen_random_uuid(),
  target_user_id uuid not null,
  requester_id uuid not null,
  requester_role text not null check (requester_role in ('super_admin', 'admin')),
  reason text not null check (char_length(reason) between 12 and 500),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'executing', 'failed', 'completed')),
  reviewed_by uuid,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  check (target_user_id <> requester_id),
  check (
    reviewed_by is null
    or (reviewed_by <> requester_id and reviewed_by <> target_user_id)
  )
);

create unique index if not exists admin_account_deletion_one_open_request
  on public.admin_account_deletion_requests (target_user_id)
  where status in ('pending', 'approved', 'executing');
create index if not exists admin_account_deletion_requests_created
  on public.admin_account_deletion_requests (created_at desc);

alter table public.admin_account_deletion_requests enable row level security;
revoke all on public.admin_account_deletion_requests
  from public, anon, authenticated;
grant all on public.admin_account_deletion_requests to service_role;

drop policy if exists example_submissions_select_reviewer
  on public.example_submissions;
create policy example_submissions_select_reviewer
  on public.example_submissions for select to authenticated
  using (
    (auth.jwt() -> 'app_metadata' ->> 'role')
      in ('moderator', 'admin', 'super_admin')
  );

drop policy if exists example_verifications_select_reviewer
  on public.example_verifications;
create policy example_verifications_select_reviewer
  on public.example_verifications for select to authenticated
  using (
    (auth.jwt() -> 'app_metadata' ->> 'role')
      in ('moderator', 'admin', 'super_admin')
  );

drop policy if exists example_admin_overrides_select_admin
  on public.example_admin_overrides;
create policy example_admin_overrides_select_admin
  on public.example_admin_overrides for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'super_admin'));

drop policy if exists dataset_versions_select_reviewer
  on public.dataset_versions;
create policy dataset_versions_select_reviewer
  on public.dataset_versions for select to authenticated
  using (
    (auth.jwt() -> 'app_metadata' ->> 'role')
      in ('moderator', 'admin', 'super_admin')
  );

drop policy if exists intelligence_audit_logs_select_admin
  on public.intelligence_audit_logs;
create policy intelligence_audit_logs_select_admin
  on public.intelligence_audit_logs for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') in ('admin', 'super_admin'));

notify pgrst, 'reload schema';
