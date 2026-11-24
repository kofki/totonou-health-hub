-- Totonou: reward state on the profile.
-- Not applied yet. Run it in the Supabase dashboard (SQL Editor → paste → Run)
-- before the app starts uploading these columns; until then the app keeps
-- uploading only the columns from the first migration.

alter table public.profiles
  add column unspent_stat_points integer  not null default 0,
  add column streak_freezes      integer  not null default 0,
  add column frozen_days         date[]   not null default '{}',
  add column emergency_passes    integer  not null default 1,
  add column titles              text[]   not null default '{}',
  add column active_title        text,
  add column achievements        text[]   not null default '{}',
  add column clear_days          date[]   not null default '{}',
  add column quests_done         integer  not null default 0,
  add column auto_done           integer  not null default 0,
  add column bosses_defeated     integer  not null default 0;
