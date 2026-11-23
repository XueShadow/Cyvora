-- Run only with the disposable local Supabase test database.
-- All fixture data is rolled back at the end of this file.
begin;

select plan(14);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at
)
values
  (
    '10000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'security-owner@example.test',
    '',
    now()
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'security-member@example.test',
    '',
    now()
  ),
  (
    '10000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'security-outsider@example.test',
    '',
    now()
  ),
  (
    '10000000-0000-0000-0000-000000000004',
    'authenticated',
    'authenticated',
    'security-invitee@example.test',
    '',
    now()
  ),
  (
    '10000000-0000-0000-0000-000000000005',
    'authenticated',
    'authenticated',
    'security-audit-actor@example.test',
    '',
    now()
  );

insert into public.families (id, name, owner_id)
values
  (
    '20000000-0000-0000-0000-000000000001',
    'Security test family',
    '10000000-0000-0000-0000-000000000001'
  ),
  (
    '20000000-0000-0000-0000-000000000002',
    'Isolated test family',
    '10000000-0000-0000-0000-000000000003'
  );

insert into public.family_members (family_id, user_id, role)
values (
  '20000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000002',
  'member'
);

insert into public.scan_records (id, user_id, scan_type, risk_level)
values
  (
    '30000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    'message',
    'low'
  ),
  (
    '30000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000002',
    'message',
    'low'
  );

delete from public.ai_request_deduplication
 where user_id = '10000000-0000-0000-0000-000000000002';
delete from public.ai_provider_attempt_leases
 where user_id = '10000000-0000-0000-0000-000000000002';
delete from public.ai_user_daily_usage
 where user_id = '10000000-0000-0000-0000-000000000002';
delete from public.ai_provider_daily_usage where provider = 'groq';
delete from public.ai_provider_runtime_state where provider = 'groq';
delete from public.ai_global_daily_usage;

select has_table('public', 'scan_records', 'scan history exists after migrations');
select ok(
  (select relrowsecurity from pg_class where oid = 'public.scan_records'::regclass),
  'scan history has row-level security enabled'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000002',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-0000-0000-000000000002","role":"authenticated"}',
  true
);

select is(
  (select count(*) from public.scan_records),
  1::bigint,
  'a member cannot read another account scan history'
);
select is(
  (select count(*) from public.families),
  1::bigint,
  'a family member cannot read an unrelated family'
);
select throws_ok(
  $$
    insert into public.scan_records (user_id, scan_type, risk_level)
    values (
      '10000000-0000-0000-0000-000000000001',
      'message',
      'low'
    )
  $$,
  '42501',
  null,
  'a member cannot create a scan for another account'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.create_family_invite(uuid,text,text,uuid,timestamptz)',
    'execute'
  ),
  'authenticated users cannot call the privileged invite-creation RPC'
);
select ok(
  not has_function_privilege(
    'authenticated',
    'public.reserve_ai_provider_attempt_v2(uuid,text,integer,integer,integer,text,integer,integer,integer,boolean)',
    'execute'
  ),
  'authenticated users cannot call the privileged AI quota RPC'
);

reset role;
set local role service_role;

insert into public.family_invites (
  family_id, invited_email, token_hash, invited_by, expires_at
)
values (
  '20000000-0000-0000-0000-000000000001',
  'expired-member@example.test',
  'security-test-expired-invite',
  '10000000-0000-0000-0000-000000000001',
  now() - interval '1 minute'
);

select throws_ok(
  $$
    select public.consume_family_invite(
      'security-test-expired-invite',
      '10000000-0000-0000-0000-000000000003'
    )
  $$,
  'P0001',
  'Invitation is invalid or expired',
  'expired family invitations cannot be consumed'
);

insert into public.family_invites (
  family_id, invited_email, token_hash, invited_by, expires_at
)
values (
  '20000000-0000-0000-0000-000000000001',
  'security-invitee@example.test',
  'security-test-reusable-invite',
  '10000000-0000-0000-0000-000000000001',
  now() + interval '1 hour'
);
select is(
  public.consume_family_invite(
    'security-test-reusable-invite',
    '10000000-0000-0000-0000-000000000004'
  ),
  '20000000-0000-0000-0000-000000000001'::uuid,
  'a valid invitation can be accepted by its verified email account'
);
select throws_ok(
  $$
    select public.consume_family_invite(
      'security-test-reusable-invite',
      '10000000-0000-0000-0000-000000000004'
    )
  $$,
  'P0001',
  'Invitation is invalid or expired',
  'an accepted invitation token cannot be reused'
);
reset role;
delete from auth.users
 where id = '10000000-0000-0000-0000-000000000004';
select is(
  (select count(*) from public.family_members
    where user_id = '10000000-0000-0000-0000-000000000004'),
  0::bigint,
  'deleting a user cascades family membership'
);

set local role service_role;
insert into public.admin_audit_logs (
  actor_id, actor_role, action, target_type, target_id, outcome, request_id
)
values (
  '10000000-0000-0000-0000-000000000005',
  'admin',
  'test.account.delete',
  'admin_account',
  '10000000-0000-0000-0000-000000000005',
  'succeeded',
  '40000000-0000-0000-0000-000000000005'
);
reset role;
delete from auth.users
 where id = '10000000-0000-0000-0000-000000000005';
select is(
  (select actor_id from public.admin_audit_logs
    where request_id = '40000000-0000-0000-0000-000000000005'),
  '10000000-0000-0000-0000-000000000005'::uuid,
  'deleting an administrator does not mutate immutable audit records'
);
set local role service_role;

select matches(
  public.reserve_ai_provider_attempt_v2(
    '10000000-0000-0000-0000-000000000002',
    'groq',
    100,
    1,
    100,
    repeat('a', 64),
    10,
    300,
    10,
    true
  ),
  '^allowed:',
  'an eligible AI provider attempt reserves quota and a lease'
);
select is(
  public.reserve_ai_provider_attempt_v2(
    '10000000-0000-0000-0000-000000000002',
    'groq',
    100,
    1,
    100,
    repeat('b', 64),
    10,
    300,
    10,
    false
  ),
  'user_budget_exhausted',
  'a user over the daily quota cannot reserve another provider attempt'
);

select * from finish();
rollback;
