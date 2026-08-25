-- Run this in Supabase → SQL Editor (once).
-- Maps Auth users to public.user_profiles.
-- Password stays in Auth. user_id = auth.users.id. user_name comes from the app.

create unique index if not exists user_profiles_user_id_key
  on public.user_profiles (user_id);

create unique index if not exists user_profiles_user_name_key
  on public.user_profiles (lower(user_name));

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.user_profiles (user_id, user_name, first_name, last_name, date_of_birth)
  values (
    new.id,
    left(
      regexp_replace(
        lower(split_part(coalesce(nullif(new.raw_user_meta_data->>'user_name', ''), new.email), '@', 1)),
        '[^a-z0-9._-]',
        '_',
        'g'
      ),
      32
    ),
    nullif(new.raw_user_meta_data->>'first_name', ''),
    nullif(new.raw_user_meta_data->>'last_name', ''),
    nullif(new.raw_user_meta_data->>'date_of_birth', '')::date
  )
  on conflict (user_id) do update
    set user_name = excluded.user_name,
        first_name = coalesce(excluded.first_name, public.user_profiles.first_name),
        last_name = coalesce(excluded.last_name, public.user_profiles.last_name),
        date_of_birth = coalesce(excluded.date_of_birth, public.user_profiles.date_of_birth),
        updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Do not require email confirmation for this personal app.
update auth.users
set email_confirmed_at = now()
where email_confirmed_at is null;

create or replace function public.confirm_user_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update auth.users
  set email_confirmed_at = now()
  where id = new.id
    and email_confirmed_at is null;
  return new;
end;
$$;

drop trigger if exists on_auth_user_auto_confirm on auth.users;
create trigger on_auth_user_auto_confirm
  after insert on auth.users
  for each row execute procedure public.confirm_user_email();

alter table public.user_profiles enable row level security;

drop policy if exists "own profile select" on public.user_profiles;
drop policy if exists "own profile insert" on public.user_profiles;
drop policy if exists "own profile update" on public.user_profiles;

create policy "own profile select"
  on public.user_profiles
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "own profile insert"
  on public.user_profiles
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "own profile update"
  on public.user_profiles
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create or replace function public.user_id_taken(p_user_name text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_profiles
    where lower(user_name) = lower(trim(p_user_name))
  );
$$;

revoke all on function public.user_id_taken(text) from public;
grant execute on function public.user_id_taken(text) to anon, authenticated;
