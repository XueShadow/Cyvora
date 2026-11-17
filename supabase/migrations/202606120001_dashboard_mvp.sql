 create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null default '',
  last_name text not null default '',
  updated_at timestamptz not null default now()
);

create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 80),
  owner_id uuid not null unique references auth.users(id) on delete cascade,
  share_reports boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.family_members (
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null unique references auth.users(id) on delete cascade,
  role text not null check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (family_id, user_id)
);

create table if not exists public.family_invites (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  invited_email text not null,
  token_hash text not null unique,
  invited_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  accepted_at timestamptz
);

create unique index if not exists family_invites_one_pending_email
  on public.family_invites (family_id, lower(invited_email))
  where accepted_at is null;

create table if not exists public.scan_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  scan_type text not null check (scan_type in ('message', 'url', 'screenshot')),
  risk_level text not null check (risk_level in ('low', 'review', 'high')),
  indicators text[] not null default '{}'
    check (cardinality(indicators) <= 10),
  created_at timestamptz not null default now()
);

create index if not exists scan_records_user_created
  on public.scan_records (user_id, created_at desc);

create table if not exists public.scam_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  family_id uuid references public.families(id) on delete set null,
  category text not null check (char_length(category) between 1 and 40),
  description text not null check (char_length(description) between 1 and 3000),
  created_at timestamptz not null default now()
);

create index if not exists scam_reports_family_created
  on public.scam_reports (family_id, created_at desc)
  where family_id is not null;

create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  family_id uuid references public.families(id) on delete cascade,
  scan_record_id uuid references public.scan_records(id) on delete cascade,
  report_id uuid references public.scam_reports(id) on delete cascade,
  title text not null,
  detail text not null,
  severity text not null check (severity in ('info', 'review', 'high')),
  created_at timestamptz not null default now(),
  check ((user_id is not null and family_id is null)
      or (user_id is null and family_id is not null))
);

create index if not exists alerts_user_created
  on public.alerts (user_id, created_at desc)
  where user_id is not null;

create index if not exists alerts_family_created
  on public.alerts (family_id, created_at desc)
  where family_id is not null;

create table if not exists public.alert_reads (
  alert_id uuid not null references public.alerts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (alert_id, user_id)
);

create or replace function public.is_family_member(target_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.family_members fm
    where fm.family_id = target_family_id
      and fm.user_id = (select auth.uid())
  );
$$;

create or replace function public.is_family_owner(target_family_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.family_members fm
    where fm.family_id = target_family_id
      and fm.user_id = (select auth.uid())
      and fm.role = 'owner'
  );
$$;

create or replace function public.are_family_members(first_user_id uuid, second_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.family_members first_member
    join public.family_members second_member
      on second_member.family_id = first_member.family_id
    where first_member.user_id = first_user_id
      and first_user_id = (select auth.uid())
      and second_member.user_id = second_user_id
  );
$$;

create or replace function public.can_view_alert(target_alert_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.alerts a
    where a.id = target_alert_id
      and (
        a.user_id = (select auth.uid())
        or (
          a.family_id is not null
          and public.is_family_member(a.family_id)
        )
      )
  );
$$;

create or replace function public.add_family_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.family_members (family_id, user_id, role)
  values (new.id, new.owner_id, 'owner');
  return new;
end;
$$;

drop trigger if exists families_add_owner on public.families;
create trigger families_add_owner
after insert on public.families
for each row execute function public.add_family_owner();

create or replace function public.sync_profile_from_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (user_id, first_name, last_name, updated_at)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name', ''),
    now()
  )
  on conflict (user_id) do update
  set first_name = excluded.first_name,
      last_name = excluded.last_name,
      updated_at = now();
  return new;
end;
$$;

drop trigger if exists auth_user_sync_profile on auth.users;
create trigger auth_user_sync_profile
after insert or update of raw_user_meta_data on auth.users
for each row execute function public.sync_profile_from_auth();

insert into public.profiles (user_id, first_name, last_name)
select
  u.id,
  coalesce(u.raw_user_meta_data ->> 'first_name', ''),
  coalesce(u.raw_user_meta_data ->> 'last_name', '')
from auth.users u
on conflict (user_id) do nothing;

create or replace function public.create_scan_alert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.risk_level = 'high' then
    insert into public.alerts (
      user_id, scan_record_id, title, detail, severity
    )
    values (
      new.user_id,
      new.id,
      'Review a scan result',
      'Local heuristics found several warning signs. This is not a confirmed threat.',
      'high'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists scan_records_create_alert on public.scan_records;
create trigger scan_records_create_alert
after insert on public.scan_records
for each row execute function public.create_scan_alert();

create or replace function public.create_report_alerts()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.alerts (
    user_id, report_id, title, detail, severity
  )
  values (
    new.user_id,
    new.id,
    'Scam report saved',
    'Your scam report was saved to your account.',
    'info'
  );

  if new.family_id is not null then
    insert into public.alerts (
      family_id, report_id, title, detail, severity
    )
    values (
      new.family_id,
      new.id,
      'New family scam report',
      'A family member shared a scam report.',
      'review'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists scam_reports_create_alerts on public.scam_reports;
create trigger scam_reports_create_alerts
after insert on public.scam_reports
for each row execute function public.create_report_alerts();

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

alter table public.profiles enable row level security;
alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.family_invites enable row level security;
alter table public.scan_records enable row level security;
alter table public.scam_reports enable row level security;
alter table public.alerts enable row level security;
alter table public.alert_reads enable row level security;

drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles
for select to authenticated
using (
  user_id = (select auth.uid())
  or public.are_family_members((select auth.uid()), user_id)
);
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles
for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists families_select_member on public.families;
create policy families_select_member on public.families
for select to authenticated
using (public.is_family_member(id));
drop policy if exists families_insert_self on public.families;
create policy families_insert_self on public.families
for insert to authenticated
with check (owner_id = (select auth.uid()));
drop policy if exists families_update_owner on public.families;
create policy families_update_owner on public.families
for update to authenticated
using (public.is_family_owner(id))
with check (
  owner_id = (select auth.uid())
  and public.is_family_owner(id)
);
drop policy if exists families_delete_owner on public.families;
create policy families_delete_owner on public.families
for delete to authenticated
using (public.is_family_owner(id));

drop policy if exists family_members_select_member on public.family_members;
create policy family_members_select_member on public.family_members
for select to authenticated
using (public.is_family_member(family_id));
drop policy if exists family_members_delete_member on public.family_members;
create policy family_members_delete_member on public.family_members
for delete to authenticated
using (
  (role = 'member' and public.is_family_owner(family_id))
  or (user_id = (select auth.uid()) and role = 'member')
);

drop policy if exists family_invites_select_owner on public.family_invites;
create policy family_invites_select_owner on public.family_invites
for select to authenticated
using (public.is_family_owner(family_id));

drop policy if exists scan_records_select_self on public.scan_records;
create policy scan_records_select_self on public.scan_records
for select to authenticated
using (user_id = (select auth.uid()));
drop policy if exists scan_records_insert_self on public.scan_records;
create policy scan_records_insert_self on public.scan_records
for insert to authenticated
with check (user_id = (select auth.uid()));
drop policy if exists scan_records_delete_self on public.scan_records;
create policy scan_records_delete_self on public.scan_records
for delete to authenticated
using (user_id = (select auth.uid()));

drop policy if exists scam_reports_select_author_or_family on public.scam_reports;
create policy scam_reports_select_author_or_family on public.scam_reports
for select to authenticated
using (
  user_id = (select auth.uid())
  or (
    family_id is not null
    and public.is_family_member(family_id)
    and exists (
      select 1 from public.families f
      where f.id = family_id and f.share_reports
    )
  )
);
drop policy if exists scam_reports_insert_self on public.scam_reports;
create policy scam_reports_insert_self on public.scam_reports
for insert to authenticated
with check (
  user_id = (select auth.uid())
  and (
    family_id is null
    or (
      public.is_family_member(family_id)
      and exists (
        select 1 from public.families f
        where f.id = family_id and f.share_reports
      )
    )
  )
);
drop policy if exists scam_reports_delete_self on public.scam_reports;
create policy scam_reports_delete_self on public.scam_reports
for delete to authenticated
using (user_id = (select auth.uid()));

drop policy if exists alerts_select_visible on public.alerts;
create policy alerts_select_visible on public.alerts
for select to authenticated
using (
  user_id = (select auth.uid())
  or (family_id is not null and public.is_family_member(family_id))
);

drop policy if exists alert_reads_select_self on public.alert_reads;
create policy alert_reads_select_self on public.alert_reads
for select to authenticated
using (user_id = (select auth.uid()));
drop policy if exists alert_reads_insert_visible on public.alert_reads;
create policy alert_reads_insert_visible on public.alert_reads
for insert to authenticated
with check (
  user_id = (select auth.uid())
  and public.can_view_alert(alert_id)
);
drop policy if exists alert_reads_update_visible on public.alert_reads;
create policy alert_reads_update_visible on public.alert_reads
for update to authenticated
using (
  user_id = (select auth.uid())
  and public.can_view_alert(alert_id)
)
with check (
  user_id = (select auth.uid())
  and public.can_view_alert(alert_id)
);

revoke all on public.profiles, public.families, public.family_members,
  public.family_invites, public.scan_records, public.scam_reports,
  public.alerts, public.alert_reads from anon, authenticated;

grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.families to authenticated;
grant select, delete on public.family_members to authenticated;
grant select on public.family_invites to authenticated;
grant select, insert, delete on public.scan_records to authenticated;
grant select, insert, delete on public.scam_reports to authenticated;
grant select on public.alerts to authenticated;
grant select, insert, update on public.alert_reads to authenticated;
grant all on public.profiles, public.families, public.family_members,
  public.family_invites, public.scan_records, public.scam_reports,
  public.alerts, public.alert_reads to service_role;

revoke all on function public.is_family_member(uuid) from public, anon;
revoke all on function public.is_family_owner(uuid) from public, anon;
revoke all on function public.are_family_members(uuid, uuid) from public, anon;
revoke all on function public.can_view_alert(uuid) from public, anon;
grant execute on function public.is_family_member(uuid) to authenticated;
grant execute on function public.is_family_owner(uuid) to authenticated;
grant execute on function public.are_family_members(uuid, uuid) to authenticated;
grant execute on function public.can_view_alert(uuid) to authenticated;

revoke all on function public.add_family_owner() from public, anon, authenticated;
revoke all on function public.sync_profile_from_auth() from public, anon, authenticated;
revoke all on function public.create_scan_alert() from public, anon, authenticated;
revoke all on function public.create_report_alerts() from public, anon, authenticated;
revoke all on function public.consume_family_invite(text, uuid)
  from public, anon, authenticated;
grant execute on function public.consume_family_invite(text, uuid) to service_role;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'alerts'
    ) then
      alter publication supabase_realtime add table public.alerts;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'family_members'
    ) then
      alter publication supabase_realtime add table public.family_members;
    end if;
  end if;
end;
$$;
