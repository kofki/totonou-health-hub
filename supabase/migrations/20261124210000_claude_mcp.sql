-- Totonou: what the Claude MCP server needs (supabase/functions/mcp).
-- Run once in the Supabase dashboard: SQL Editor → paste → Run.
--
-- Claude (the app on your phone, the website, or Claude Code) connects to the
-- `mcp` function with a personal token. Through it Claude can read one document
-- that describes your game, and leave changes for the app to apply. The phone
-- stays the source of truth: Claude never edits game data directly.

-- 1. What Claude reads. One JSON document per user, written by the app each
--    time it backs up: stats, arcs and their progress, recent quests, the
--    coach's measured facts. JSON rather than columns, so the app can add to it
--    without a new migration.
create table public.claude_snapshots (
  user_id    uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  data       jsonb       not null,
  updated_at timestamptz not null default now()
);

-- 2. What Claude writes. Each row is one change ("add this quest", "start this
--    arc"). The app reads the rows it has not applied yet, applies them through
--    QuestEngine, and stamps applied_at. `result` says what happened.
create table public.claude_changes (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  kind       text        not null check (kind in (
               'add_quest','remove_quest','add_arc','add_daily_quest','add_objective','end_arc','coach_message')),
  payload    jsonb       not null,
  created_at timestamptz not null default now(),
  applied_at timestamptz,
  result     text
);
create index claude_changes_pending on public.claude_changes (user_id, created_at) where applied_at is null;

-- 3. Who Claude is acting for. The app makes a random token, shows it to you
--    once, and stores only its SHA-256 hash here, so a leak of this table does
--    not leak a working token. Delete the row to disconnect Claude.
create table public.claude_tokens (
  token_hash   text primary key,
  user_id      uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  created_at   timestamptz not null default now(),
  last_used_at timestamptz
);

alter table public.claude_snapshots enable row level security;
alter table public.claude_changes   enable row level security;
alter table public.claude_tokens    enable row level security;

create policy "own snapshot" on public.claude_snapshots
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- The app may read its changes and mark them applied. It may not create them:
-- only the function (service role) does, after checking a token.
create policy "read own changes" on public.claude_changes
  for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "mark own changes" on public.claude_changes
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "own tokens" on public.claude_tokens
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
