-- Claude can give a quest (or a daily quest in an arc's plan) a checklist of steps.
alter table public.claude_changes drop constraint if exists claude_changes_kind_check;
alter table public.claude_changes add constraint claude_changes_kind_check check (kind in (
  'add_quest', 'remove_quest', 'add_arc', 'add_daily_quest', 'add_objective', 'end_arc', 'coach_message',
  'set_steps'
));
