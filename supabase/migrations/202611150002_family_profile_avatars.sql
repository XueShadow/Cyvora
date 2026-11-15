alter table public.profiles
  add column if not exists avatar_path text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_avatar_path_matches_user'
      and conrelid = 'public.profiles'::regclass
  ) then
    alter table public.profiles
      add constraint profiles_avatar_path_matches_user
      check (
        avatar_path is null
        or avatar_path = user_id::text || '/avatar'
      );
  end if;
end;
$$;

create or replace function public.sync_profile_from_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  saved_avatar_path text;
begin
  saved_avatar_path := new.raw_user_meta_data ->> 'avatar_path';
  if saved_avatar_path is distinct from new.id::text || '/avatar' then
    saved_avatar_path := null;
  end if;

  insert into public.profiles (
    user_id,
    first_name,
    last_name,
    avatar_path,
    updated_at
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name', ''),
    saved_avatar_path,
    now()
  )
  on conflict (user_id) do update
  set first_name = excluded.first_name,
      last_name = excluded.last_name,
      avatar_path = excluded.avatar_path,
      updated_at = now();
  return new;
end;
$$;

update public.profiles profile
set avatar_path = case
  when user_record.raw_user_meta_data ->> 'avatar_path'
       = user_record.id::text || '/avatar'
    then user_record.raw_user_meta_data ->> 'avatar_path'
  else null
end
from auth.users user_record
where user_record.id = profile.user_id;

drop policy if exists profile_avatars_read_family on storage.objects;
create policy profile_avatars_read_family on storage.objects
for select to authenticated
using (
  bucket_id = 'profile-avatars'
  and public.are_family_members(
    (select auth.uid()),
    ((storage.foldername(name))[1])::uuid
  )
);
