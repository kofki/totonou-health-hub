-- Totonou: the skill catalogue.
-- Run once in the Supabase dashboard: SQL Editor → paste → Run.
--
-- One row per unique skill. The app reads this table at launch and falls back
-- to the same list built into the app (TotonouCore/Skills.swift) when it cannot.
-- Edit rows here to rename or rebalance skills, or add new ones, without an
-- app update. `measure` must be one the app records (SkillMeasure in
-- Skills.swift); the check below enforces that, so a skill can only grow with
-- something that was actually proved.

create table public.skills (
  id          text primary key,
  name        text      not null,
  detail      text      not null,
  measure     text      not null check (measure in (
                'strength','endurance','intellect','discipline','recovery',
                'earlyQuests','nightQuests','onTimeQuests','longQuests','hardQuests',
                'mustDoDone','recoveries','bossesDefeated','clearDays','streak',
                'autoDone','runQuests','stepQuests','mindfulQuests','calendarQuests','reminderQuests',
                'workouts','cyclingWorkouts','swimWorkouts','danceWorkouts','martialArtsWorkouts')),
  thresholds  integer[] not null check (cardinality(thresholds) between 1 and 10),
  glyph       text      not null default 'star',
  rarity      text      not null default 'common' check (rarity in ('common','rare','epic','legendary')),
  sort_order  integer   not null default 0
);

-- A shared catalogue: anyone using the app may read it; only the dashboard
-- (the service role) can change it.
alter table public.skills enable row level security;
create policy "skills are readable" on public.skills for select to anon, authenticated using (true);

insert into public.skills (id, name, detail, measure, thresholds, glyph, rarity, sort_order) values
  ('ironBody', 'Iron Body', 'Grows with Strength.', 'strength', '{5,10,20,30,45,60,80,100,130,160}', 'dumbbell', 'common', 1),
  ('secondWind', 'Second Wind', 'Grows with Endurance.', 'endurance', '{5,10,20,30,45,60,80,100,130,160}', 'mountain', 'common', 2),
  ('sharpMind', 'Sharp Mind', 'Grows with Intellect.', 'intellect', '{5,10,20,30,45,60,80,100,130,160}', 'book', 'common', 3),
  ('unyielding', 'Unyielding', 'Grows with Discipline.', 'discipline', '{5,10,20,30,45,60,80,100,130,160}', 'torii', 'common', 4),
  ('stillWater', 'Still Water', 'Grows with Recovery.', 'recovery', '{5,10,20,30,45,60,80,100,130,160}', 'moon', 'common', 5),
  ('dawnWalker', 'Dawn Walker', 'Quests finished before 06:30.', 'earlyQuests', '{1,3,7,15,25,40,60,80,100,150}', 'alarm', 'rare', 6),
  ('nightOwl', 'Night Owl', 'Quests finished after 21:00.', 'nightQuests', '{1,3,7,15,25,40,60,80,100,150}', 'moon', 'common', 7),
  ('clockwork', 'Clockwork', 'Quests finished before their time limit.', 'onTimeQuests', '{3,10,25,50,80,120,170,230,300,400}', 'hourglass', 'rare', 8),
  ('deepPractice', 'Deep Practice', 'Quests of an hour or more.', 'longQuests', '{1,3,7,15,25,40,60,80,100,150}', 'target', 'rare', 9),
  ('overreach', 'Overreach', 'A- and S-rank quests finished.', 'hardQuests', '{1,2,4,6,9,12,16,20,25,30}', 'bolt', 'epic', 10),
  ('eternalFlame', 'Eternal Flame', 'The length of your streak.', 'streak', '{3,7,14,21,30,45,60,100,180,365}', 'flame', 'epic', 11),
  ('oathKeeper', 'Oath Keeper', 'Must-do quests kept.', 'mustDoDone', '{1,3,7,15,25,40,60,80,100,150}', 'shield', 'rare', 12),
  ('flawless', 'Flawless', 'Days with every quest cleared.', 'clearDays', '{1,3,7,15,25,40,60,80,100,150}', 'star', 'epic', 13),
  ('phoenix', 'Phoenix', 'Coming back from the penalty zone.', 'recoveries', '{1,2,4,6,9,12,16,20,25,30}', 'rankUp', 'epic', 14),
  ('giantSlayer', 'Giant Slayer', 'Bosses defeated.', 'bossesDefeated', '{1,2,4,6,9,12,16,20,25,30}', 'sword', 'legendary', 15),
  ('livingProof', 'Living Proof', 'Quests your data proved, not your word.', 'autoDone', '{3,10,25,50,80,120,170,230,300,400}', 'heart', 'rare', 16),
  ('runnersStride', 'Runner''s Stride', 'Runs proven by Apple Health.', 'runQuests', '{1,3,7,15,25,40,60,80,100,150}', 'mountain', 'rare', 17),
  ('wanderer', 'Wanderer', 'Step goals proven by Apple Health.', 'stepQuests', '{1,3,7,15,25,40,60,80,100,150}', 'watch', 'common', 18),
  ('calmMind', 'Calm Mind', 'Mindful sessions proven by Apple Health.', 'mindfulQuests', '{1,3,7,15,25,40,60,80,100,150}', 'moon', 'rare', 19),
  ('strategist', 'Strategist', 'Calendar events turned into finished quests.', 'calendarQuests', '{1,3,7,15,25,40,60,80,100,150}', 'calendar', 'common', 20),
  ('looseEnds', 'Loose Ends', 'Reminders finished as quests.', 'reminderQuests', '{1,3,7,15,25,40,60,80,100,150}', 'bell', 'common', 21),
  ('trainingRegimen', 'Training Regimen', 'Every workout in Apple Health.', 'workouts', '{3,10,25,50,80,120,170,230,300,400}', 'dumbbell', 'rare', 22),
  ('ironWheels', 'Iron Wheels', 'Cycling workouts.', 'cyclingWorkouts', '{1,3,7,15,25,40,60,80,100,150}', 'bolt', 'common', 23),
  ('openWater', 'Open Water', 'Swimming workouts.', 'swimWorkouts', '{1,3,7,15,25,40,60,80,100,150}', 'moon', 'common', 24),
  ('rhythm', 'Rhythm', 'Dance workouts.', 'danceWorkouts', '{1,3,7,15,25,40,60,80,100,150}', 'star', 'common', 25),
  ('wayOfTheFist', 'Way of the Fist', 'Martial arts, boxing and wrestling workouts.', 'martialArtsWorkouts', '{1,3,7,15,25,40,60,80,100,150}', 'sword', 'rare', 26);
