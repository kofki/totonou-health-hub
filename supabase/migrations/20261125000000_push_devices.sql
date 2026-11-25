-- Totonou: phones that receive push notifications (supabase/functions/_shared/apns.ts).
-- Run once in the Supabase dashboard: SQL Editor → paste → Run.
--
-- The app stores its Apple push token here when "Claude and coach" alerts are
-- switched on, and deletes it when they are switched off. The `mcp` function
-- reads it to tell you when Claude changed your plan or answered a question.

create table public.push_devices (
  token       text primary key,
  user_id     uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  -- 'sandbox' for builds run from Xcode, 'production' for TestFlight and the App Store.
  environment text        not null check (environment in ('sandbox', 'production')),
  updated_at  timestamptz not null default now()
);

alter table public.push_devices enable row level security;

create policy "own devices" on public.push_devices
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
