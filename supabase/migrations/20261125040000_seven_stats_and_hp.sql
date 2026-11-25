-- Seven stats and hit points (2026-11-25). The five old stat columns keep their
-- names: endurance holds Vitality, intellect Intelligence, discipline Willpower,
-- recovery Wisdom. Agility and Charisma are new; damage is HP lost.
alter table public.profiles
  add column if not exists agility integer not null default 0,
  add column if not exists charisma integer not null default 0,
  add column if not exists damage integer not null default 0;
