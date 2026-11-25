-- Totonou: a daily counter for the `ai` Edge Function (supabase/functions/ai).
-- Run once in the Supabase dashboard: SQL Editor → paste → Run.
--
-- The function calls a paid model. The app's key is public and sign-in is
-- anonymous, so each user gets a daily number of calls, and so does the project
-- as a whole (the row whose user_id is all zeros). The function refuses a call
-- once either count is over its cap.

create table public.ai_usage (
  user_id uuid not null,
  day     date not null default current_date,
  calls   int  not null default 0,
  primary key (user_id, day)
);

-- Row-level security on with no policies: the app cannot read or write this
-- table at all. Only the function's service-role key gets through.
alter table public.ai_usage enable row level security;

-- Adds one to today's count and returns the new count, in one statement, so two
-- calls at the same moment cannot both read the old number.
create function public.bump_ai_usage(p_user uuid)
returns int
language sql
security definer
set search_path = ''
as $$
  insert into public.ai_usage (user_id, day, calls)
  values (p_user, current_date, 1)
  on conflict (user_id, day) do update set calls = public.ai_usage.calls + 1
  returning calls;
$$;

revoke execute on function public.bump_ai_usage(uuid) from public, anon, authenticated;
grant  execute on function public.bump_ai_usage(uuid) to service_role;
