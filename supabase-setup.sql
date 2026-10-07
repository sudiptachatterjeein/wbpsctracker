-- Run once in Supabase: SQL Editor > New query > Run. Safe to re-run.
create table if not exists tracker_state(user_id uuid primary key references auth.users(id) on delete cascade, data jsonb not null, updated_at timestamptz default now());
create table if not exists tracker_archive(id bigserial primary key, user_id uuid not null references auth.users(id) on delete cascade, kind text not null, data jsonb not null, created_at timestamptz default now());
create table if not exists profiles(id uuid primary key references auth.users(id) on delete cascade, email text, name text default '', role text not null default 'student' check(role in('admin','student')), active boolean not null default false, created_at timestamptz default now());
create or replace function is_admin() returns boolean language sql security definer set search_path=public stable as $$ select exists(select 1 from profiles where id=auth.uid() and role='admin' and active) $$;
alter table tracker_state enable row level security; alter table tracker_archive enable row level security; alter table profiles enable row level security;
drop policy if exists "own state" on tracker_state; create policy "own state" on tracker_state for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
drop policy if exists "own archive" on tracker_archive; create policy "own archive" on tracker_archive for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
drop policy if exists "admin reads state" on tracker_state; create policy "admin reads state" on tracker_state for select using (is_admin());
drop policy if exists "read own or admin" on profiles; create policy "read own or admin" on profiles for select using (id=auth.uid() or is_admin());
drop policy if exists "admin updates" on profiles; create policy "admin updates" on profiles for update using (is_admin()) with check (is_admin());
-- first account ever created becomes admin; later self-signups stay disabled until an admin enables them
create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare first boolean; begin select count(*)=0 into first from profiles;
insert into profiles(id,email,name,role,active) values(new.id,new.email,coalesce(new.raw_user_meta_data->>'name',''),case when first then 'admin' else 'student' end,first); return new; end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();
-- backfill accounts that already exist: they become active, the oldest becomes admin
insert into profiles(id,email,role,active) select id,email,'student',true from auth.users on conflict do nothing;
update profiles set role='admin' where id=(select id from auth.users order by created_at limit 1) and not exists(select 1 from profiles where role='admin');
