-- The stat skills under the seven stats (2026-11-25). Agility and Charisma
-- skills are added by the app (SkillCatalog.builtIn) when the table lacks them.
update public.skills set detail = 'Grows with Vitality.', glyph = 'heart' where id = 'secondWind';
update public.skills set detail = 'Grows with Intelligence.' where id = 'sharpMind';
update public.skills set detail = 'Grows with Wisdom.' where id = 'stillWater';
update public.skills set detail = 'Grows with Willpower.' where id = 'unyielding';
