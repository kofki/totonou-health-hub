-- Totonou: questions asked on the Coach tab, answered by Claude Code on the
-- owner's Mac (scripts/coach-relay). Run once in the Supabase dashboard.
--
-- The app writes a question; the relay on the Mac sees it through the `mcp`
-- function, runs Claude Code with the Totonou tools, and Claude writes the
-- answer back with answer_coach_question. The app shows it when it arrives.

create table public.coach_questions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  question    text        not null check (length(question) between 1 and 1000),
  answer      text,
  created_at  timestamptz not null default now(),
  answered_at timestamptz
);
create index coach_questions_waiting on public.coach_questions (user_id, created_at) where answer is null;

alter table public.coach_questions enable row level security;

-- The app may ask and read its own questions. Only the function (service role)
-- writes answers.
create policy "ask own questions" on public.coach_questions
  for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "read own questions" on public.coach_questions
  for select to authenticated
  using ((select auth.uid()) = user_id);
