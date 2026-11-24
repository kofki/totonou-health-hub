-- Totonou: first schema.
-- Run once in the Supabase dashboard: SQL Editor → paste → Run.
--
-- Two tables, both private to the signed-in user. Row-level security is on, so
-- the publishable key in the app can only ever read or write that user's rows.

create table public.profiles (
  user_id         uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  name            text        not null,
  total_xp        integer     not null default 0,
  strength        integer     not null default 0,
  endurance       integer     not null default 0,
  intellect       integer     not null default 0,
  discipline      integer     not null default 0,
  recovery        integer     not null default 0,
  banked_minutes  integer     not null default 0,
  completion_days date[]      not null default '{}',
  updated_at      timestamptz not null default now()
);

create table public.quests (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  title            text        not null,
  stat             text        not null,
  rank             text        not null,
  source           text        not null,
  is_critical      boolean     not null default false,
  is_recovery      boolean     not null default false,
  scheduled_at     timestamptz not null,
  duration_minutes integer     not null default 0,
  completed_at     timestamptz,
  failed_at        timestamptz,
  auto_completed   boolean     not null default false,
  updated_at       timestamptz not null default now(),
  -- The app has no server ids yet, so a quest is identified by when it is and what it is.
  unique (user_id, scheduled_at, title)
);

alter table public.profiles enable row level security;
alter table public.quests   enable row level security;

create policy "own profile" on public.profiles
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "own quests" on public.quests
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
