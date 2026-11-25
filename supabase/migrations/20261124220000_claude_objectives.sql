-- Totonou: lets Claude add objectives (add_objective in supabase/functions/mcp).
-- Run once after 20261124210000_claude_mcp.sql. A fresh project gets the same
-- check from that file, so this one only matters where it already ran.
alter table public.claude_changes drop constraint if exists claude_changes_kind_check;
alter table public.claude_changes add constraint claude_changes_kind_check check (kind in (
  'add_quest','remove_quest','add_arc','add_daily_quest','add_objective','end_arc','coach_message'));
