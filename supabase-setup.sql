-- Run this once in Supabase: SQL Editor > New query > Run
create table if not exists tracker_state(
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null, updated_at timestamptz default now());
create table if not exists tracker_archive(
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null, data jsonb not null, created_at timestamptz default now());
alter table tracker_state enable row level security;
alter table tracker_archive enable row level security;
create policy "own state" on tracker_state for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
create policy "own archive" on tracker_archive for all using (auth.uid()=user_id) with check (auth.uid()=user_id);
