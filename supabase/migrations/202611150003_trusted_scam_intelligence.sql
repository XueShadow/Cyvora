alter table public.analysis_module_results
  drop constraint if exists analysis_module_results_module_check,
  add constraint analysis_module_results_module_check
    check (module in (
      'url_structure', 'domain_dns', 'ssl_tls', 'redirect_analysis',
      'suspicious_patterns', 'local_indicator_database', 'community_reports',
      'external_threat_intelligence', 'scam_pattern_recognition',
      'anomaly_detection', 'adaptive_pattern_analysis'
    ));

create table if not exists public.example_submissions (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  scan_record_id uuid references public.scan_records(id) on delete set null,
  content_type text not null check (content_type in ('message', 'url', 'screenshot')),
  redacted_content text not null check (
    char_length(redacted_content) between 1 and 5000
  ),
  content_hash text not null check (content_hash ~ '^[0-9a-f]{64}$'),
  submitted_label text not null check (
    submitted_label in ('scam', 'legitimate', 'unsure')
  ),
  status text not null default 'pending'
    check (status in (
      'pending', 'under_review', 'verified_scam',
      'verified_legitimate', 'rejected', 'disputed'
    )),
  screening_result jsonb not null default '{}'::jsonb
    check (jsonb_typeof(screening_result) = 'object'),
  status_note text check (
    status_note is null or char_length(status_note) <= 300
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists example_submissions_review_queue
  on public.example_submissions (status, created_at);
create index if not exists example_submissions_content_hash
  on public.example_submissions (content_hash, status);
create index if not exists example_submissions_reporter
  on public.example_submissions (reporter_id, created_at desc);
create unique index if not exists example_submissions_active_reporter_hash
  on public.example_submissions (reporter_id, content_hash)
  where status in (
    'pending', 'under_review', 'verified_scam', 'verified_legitimate'
  );

create table if not exists public.example_verifications (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null references public.example_submissions(id)
    on delete cascade,
  reviewer_id uuid not null references auth.users(id) on delete restrict,
  decision text not null check (decision in (
    'verified_scam', 'verified_legitimate', 'rejected', 'disputed'
  )),
  verification_method text not null check (verification_method in (
    'official_source', 'direct_contact', 'law_enforcement',
    'independent_fact_check', 'other'
  )),
  evidence_reference text not null check (
    char_length(evidence_reference) between 12 and 2000
  ),
  notes text check (notes is null or char_length(notes) <= 1000),
  created_at timestamptz not null default now(),
  unique (submission_id, reviewer_id)
);

create index if not exists example_verifications_submission
  on public.example_verifications (submission_id, created_at);

create table if not exists public.example_admin_overrides (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null unique references public.example_submissions(id)
    on delete cascade,
  admin_id uuid not null references auth.users(id) on delete restrict,
  decision text not null check (
    decision in ('verified_scam', 'verified_legitimate')
  ),
  evidence_reference text not null check (
    char_length(evidence_reference) between 12 and 2000
  ),
  created_at timestamptz not null default now()
);

create table if not exists public.dataset_versions (
  id uuid primary key default gen_random_uuid(),
  version_label text not null unique,
  example_count integer not null check (example_count > 0),
  evaluation_status text not null default 'not_evaluated'
    check (evaluation_status in (
      'not_evaluated', 'pending', 'passed', 'failed'
    )),
  evaluation_metrics jsonb not null default '{}'::jsonb
    check (jsonb_typeof(evaluation_metrics) = 'object'),
  release_status text not null default 'staged'
    check (release_status in ('staged', 'approved', 'active', 'rolled_back')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  evaluated_at timestamptz,
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz
);

create table if not exists public.trusted_training_examples (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid unique references public.example_submissions(id)
    on delete set null,
  content_hash text not null unique check (content_hash ~ '^[0-9a-f]{64}$'),
  dataset_version_id uuid not null references public.dataset_versions(id)
    on delete restrict,
  verified_label text not null check (
    verified_label in ('verified_scam', 'verified_legitimate')
  ),
  features jsonb not null check (jsonb_typeof(features) = 'object'),
  created_at timestamptz not null default now()
);

create index if not exists trusted_training_examples_version
  on public.trusted_training_examples (dataset_version_id, verified_label);

create table if not exists public.intelligence_audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null check (char_length(action) between 1 and 80),
  submission_id uuid references public.example_submissions(id)
    on delete set null,
  dataset_version_id uuid references public.dataset_versions(id)
    on delete set null,
  metadata jsonb not null default '{}'::jsonb
    check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);

create index if not exists intelligence_audit_logs_created
  on public.intelligence_audit_logs (created_at desc);
create index if not exists intelligence_audit_logs_submission
  on public.intelligence_audit_logs (submission_id, created_at desc);

create or replace function public.stage_trusted_example(
  target_submission_id uuid,
  target_actor_id uuid,
  target_label text,
  target_features jsonb,
  target_admin_override boolean default false,
  target_override_evidence text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  submission_row record;
  reviewer_count integer;
  existing_count integer;
  created_version_id uuid;
  existing_version_id uuid;
  existing_label text;
begin
  if target_label not in ('verified_scam', 'verified_legitimate')
     or jsonb_typeof(target_features) is distinct from 'object'
     or jsonb_typeof(target_features -> 'categories') is distinct from 'array'
     or jsonb_typeof(target_features -> 'split') is distinct from 'string'
     or (target_admin_override and (
       target_override_evidence is null or
       char_length(target_override_evidence) not between 12 and 2000
     )) then
    raise exception 'invalid trusted example data';
  end if;

  select id, reporter_id, content_hash, status
    into submission_row
    from public.example_submissions
    where id = target_submission_id
    for update;
  if not found then
    raise exception 'submission not found';
  end if;
  if submission_row.status not in ('pending', 'under_review')
     and not (target_admin_override and submission_row.status = 'disputed') then
    select dataset_version_id into existing_version_id
      from public.trusted_training_examples
      where submission_id = target_submission_id;
    if existing_version_id is not null then
      return existing_version_id;
    end if;
    raise exception 'submission is not eligible for trusted use';
  end if;

  if not target_admin_override and exists (
    select 1
      from public.example_verifications
      where submission_id = target_submission_id
        and decision = case target_label
          when 'verified_scam' then 'verified_legitimate'
          else 'verified_scam'
        end
  ) then
    raise exception 'conflicting moderator decisions';
  end if;

  if target_admin_override then
    insert into public.example_admin_overrides (
      submission_id, admin_id, decision, evidence_reference
    )
    values (
      target_submission_id, target_actor_id, target_label,
      target_override_evidence
    );
    reviewer_count := 0;
  else
    select count(distinct reviewer_id)::integer
      into reviewer_count
      from public.example_verifications
      where submission_id = target_submission_id
        and decision = target_label;
    if reviewer_count < 2 then
      raise exception 'two independent moderator decisions are required';
    end if;
  end if;

  if exists (
    select 1
      from public.example_submissions conflicting
      where conflicting.content_hash = submission_row.content_hash
        and conflicting.id <> target_submission_id
        and conflicting.status = case target_label
          when 'verified_scam' then 'verified_legitimate'
          else 'verified_scam'
        end
  ) then
    raise exception 'conflicting verified examples exist';
  end if;

  perform pg_advisory_xact_lock(834761001);
  select dataset_version_id, verified_label
    into existing_version_id, existing_label
    from public.trusted_training_examples
    where content_hash = submission_row.content_hash;
  if existing_version_id is not null then
    if existing_label <> target_label then
      raise exception 'conflicting trusted example labels exist';
    end if;
    update public.example_submissions
      set status = target_label,
          status_note = 'Verified; an identical example is already in the trusted dataset.',
          updated_at = now()
      where id = target_submission_id;
    insert into public.intelligence_audit_logs (
      actor_id, action, submission_id, dataset_version_id, metadata
    )
    values (
      target_actor_id,
      'duplicate_trusted_example_verified',
      target_submission_id,
      existing_version_id,
      jsonb_build_object('verified_label', target_label)
    );
    return existing_version_id;
  end if;

  select dataset_version_id into existing_version_id
    from public.trusted_training_examples
    where submission_id = target_submission_id;
  if existing_version_id is not null then
    return existing_version_id;
  end if;

  select count(*)::integer into existing_count
    from public.trusted_training_examples;
  insert into public.dataset_versions (
    version_label, example_count, evaluation_status, release_status, created_by
  )
  values (
    'curated-' || to_char(clock_timestamp(), 'YYYYMMDDHH24MISSMS') || '-' ||
      substr(gen_random_uuid()::text, 1, 8),
    existing_count + 1,
    'not_evaluated',
    'staged',
    target_actor_id
  )
  returning id into created_version_id;

  insert into public.trusted_training_examples (
    submission_id, content_hash, dataset_version_id, verified_label, features
  )
  values (
    target_submission_id, submission_row.content_hash, created_version_id,
    target_label, target_features
  );

  update public.example_submissions
    set status = target_label,
        status_note = 'Verified by two distinct moderators; staged for evaluation.',
        updated_at = now()
    where id = target_submission_id;

  insert into public.intelligence_audit_logs (
    actor_id, action, submission_id, dataset_version_id, metadata
  )
  values (
    target_actor_id,
    case when target_admin_override
      then 'admin_dispute_override'
      else 'trusted_example_staged'
    end,
    target_submission_id,
    created_version_id,
    jsonb_build_object(
      'verified_label', target_label,
      'independent_reviewers', reviewer_count,
      'admin_override', target_admin_override,
      'production_effect', 'none'
    )
  );
  return created_version_id;
end;
$$;

revoke all on function public.stage_trusted_example(
  uuid, uuid, text, jsonb, boolean, text
) from public, anon, authenticated;
grant execute on function public.stage_trusted_example(
  uuid, uuid, text, jsonb, boolean, text
) to service_role;

create or replace function public.activate_trusted_dataset(
  target_version_id uuid,
  target_actor_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_evaluation_status text;
begin
  select evaluation_status into target_evaluation_status
    from public.dataset_versions
    where id = target_version_id
    for update;
  if not found or target_evaluation_status <> 'passed' then
    raise exception 'dataset has not passed evaluation';
  end if;

  update public.dataset_versions
    set release_status = 'rolled_back'
    where release_status = 'active'
      and id <> target_version_id;

  update public.dataset_versions
    set release_status = 'active',
        approved_by = target_actor_id,
        approved_at = now()
    where id = target_version_id
      and evaluation_status = 'passed';
  if not found then
    raise exception 'dataset release failed';
  end if;

  insert into public.intelligence_audit_logs (
    actor_id, action, dataset_version_id, metadata
  )
  values (
    target_actor_id,
    'trusted_dataset_activated',
    target_version_id,
    jsonb_build_object('evaluation_status', 'passed')
  );
end;
$$;

revoke all on function public.activate_trusted_dataset(
  uuid, uuid
) from public, anon, authenticated;
grant execute on function public.activate_trusted_dataset(
  uuid, uuid
) to service_role;

alter table public.example_submissions enable row level security;
alter table public.example_verifications enable row level security;
alter table public.example_admin_overrides enable row level security;
alter table public.dataset_versions enable row level security;
alter table public.trusted_training_examples enable row level security;
alter table public.intelligence_audit_logs enable row level security;

revoke all on public.example_submissions, public.example_verifications,
  public.example_admin_overrides,
  public.dataset_versions, public.trusted_training_examples,
  public.intelligence_audit_logs from public, anon, authenticated;
grant select (
  id, scan_record_id, content_type, submitted_label, status, status_note,
  created_at, updated_at
) on public.example_submissions to authenticated;
grant select on public.example_verifications, public.example_admin_overrides,
  public.dataset_versions,
  public.intelligence_audit_logs to authenticated;
grant all on public.example_submissions, public.example_verifications,
  public.example_admin_overrides,
  public.dataset_versions, public.trusted_training_examples,
  public.intelligence_audit_logs to service_role;

drop policy if exists example_submissions_select_owner
  on public.example_submissions;
create policy example_submissions_select_owner
  on public.example_submissions for select to authenticated
  using (reporter_id = (select auth.uid()));

drop policy if exists example_submissions_select_reviewer
  on public.example_submissions;
create policy example_submissions_select_reviewer
  on public.example_submissions for select to authenticated
  using (
    (auth.jwt() -> 'app_metadata' ->> 'role') in ('moderator', 'admin')
  );

drop policy if exists example_verifications_select_reviewer
  on public.example_verifications;
create policy example_verifications_select_reviewer
  on public.example_verifications for select to authenticated
  using (
    (auth.jwt() -> 'app_metadata' ->> 'role') in ('moderator', 'admin')
  );

drop policy if exists example_admin_overrides_select_admin
  on public.example_admin_overrides;
create policy example_admin_overrides_select_admin
  on public.example_admin_overrides for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

drop policy if exists dataset_versions_select_reviewer
  on public.dataset_versions;
create policy dataset_versions_select_reviewer
  on public.dataset_versions for select to authenticated
  using (
    (auth.jwt() -> 'app_metadata' ->> 'role') in ('moderator', 'admin')
  );

drop policy if exists intelligence_audit_logs_select_admin
  on public.intelligence_audit_logs;
create policy intelligence_audit_logs_select_admin
  on public.intelligence_audit_logs for select to authenticated
  using ((auth.jwt() -> 'app_metadata' ->> 'role') = 'admin');

notify pgrst, 'reload schema';
