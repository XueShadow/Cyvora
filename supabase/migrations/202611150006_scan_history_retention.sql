create or replace function public.delete_expired_scan_history()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_count integer;
begin
  delete from public.scan_records
  where created_at < now() - interval '120 days';

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

revoke all on function public.delete_expired_scan_history() from public;
grant execute on function public.delete_expired_scan_history() to service_role;

do $migration$
begin
  if exists (
    select 1
    from pg_available_extensions
    where name = 'pg_cron'
  ) then
    execute 'create extension if not exists pg_cron with schema extensions';

    if not exists (
      select 1
      from cron.job
      where jobname = 'delete-expired-scan-history'
    ) then
      perform cron.schedule(
        'delete-expired-scan-history',
        '15 2 * * *',
        $job$select public.delete_expired_scan_history()$job$
      );
    end if;
  end if;
end;
$migration$;
