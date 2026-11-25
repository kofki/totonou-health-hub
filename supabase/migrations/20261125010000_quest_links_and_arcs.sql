-- Totonou: back up how quests fit together, and the arcs themselves.
-- Run once in the Supabase dashboard: SQL Editor → paste → Run.
--
-- Quests have no ids that survive between phones, so a quest is still found
-- by (user, scheduled_at, title), and links point to other quests the same way:
-- a step names its quest by title and start time.

alter table public.quests
  add column if not exists arc                 text,
  add column if not exists objective           text,
  add column if not exists parent_title        text,
  add column if not exists parent_scheduled_at timestamptz,
  add column if not exists signal_key          text,
  add column if not exists target              double precision;

comment on column public.quests.parent_title is
  'Set on a step (sub-quest): the title of the quest it unlocks. Steps pay their own reward.';

-- One row per arc, identified by title and start. Objectives and the daily plan
-- are small lists that always travel with their arc, so they are JSON / arrays
-- here rather than tables of their own.
create table if not exists public.arcs (
  user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  title       text        not null,
  start_date  timestamptz not null,
  kind        text        not null check (kind in ('seasonal', 'objective')),
  manifesto   text        not null default '',
  goals       text[]      not null default '{}',
  goals_done  text[]      not null default '{}',
  -- Null for an objective arc, which has no end date.
  end_date    timestamptz,
  ended_at    timestamptz,
  -- One QuestIdea.line per daily quest ("title|stat|hour|minute|minutes|rank|objective|weekdays").
  quest_plan  text[]      not null default '{}',
  -- [{"title", "period": "day|week|arc", "target", "detail"}]
  objectives  jsonb       not null default '[]',
  updated_at  timestamptz not null default now(),
  primary key (user_id, title, start_date)
);

alter table public.arcs enable row level security;

create policy "own arcs" on public.arcs
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
