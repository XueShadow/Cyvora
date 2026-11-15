create table if not exists public.scam_intelligence_usage (
  user_id uuid primary key references auth.users(id) on delete cascade,
  usage_date date not null,
  request_count integer not null check (request_count between 1 and 30),
  updated_at timestamptz not null default now()
);

alter table public.scam_intelligence_usage enable row level security;

revoke all on table public.scam_intelligence_usage
  from public, anon, authenticated;

create or replace function public.consume_scam_intelligence_quota(
  target_user_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_allowed boolean;
  utc_today date := (now() at time zone 'UTC')::date;
begin
  insert into public.scam_intelligence_usage as usage (
    user_id,
    usage_date,
    request_count
  )
  values (target_user_id, utc_today, 1)
  on conflict (user_id) do update
  set usage_date = excluded.usage_date,
      request_count = case
        when usage.usage_date = excluded.usage_date
          then usage.request_count + 1
        else 1
      end,
      updated_at = now()
  where usage.usage_date <> excluded.usage_date
     or usage.request_count < 30
  returning true into request_allowed;

  return coalesce(request_allowed, false);
end;
$$;

revoke all on function public.consume_scam_intelligence_quota(uuid)
  from public, anon, authenticated;
grant execute on function public.consume_scam_intelligence_quota(uuid)
  to service_role;
