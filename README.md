# Totonou 整う

A personal quest system: write a life chapter (an arc), get daily quests, let your
watch and calendar complete them, earn XP, stats and screen time. Miss a critical
quest and everything locks until you recover.

**Arcs → Quests → Stats → Rewards**

## Status

The app runs on what you create. There is no sample data: a new install is a
level 1 human with no arc, and Today asks you to write one.

| Piece | State |
|---|---|
| Arcs | You describe a chapter; a planner turns it into goals and daily quests, which appear on Today every day. Several arcs can run at once. An arc is a season (90 days) or an objective (no end date, runs until you reach it); each shows its goals, quests and boss tasks done, and you can end one early |
| Planner and coach AI | Apple's on-device model (Foundation Models, iOS 26 with Apple Intelligence on). Without it, Claude on the owner's own Claude account: Coach questions go to Claude Code on the Mac (`scripts/coach-relay`), and "Plan with Claude" / "Ask Claude" open the Claude app. With neither: keyword rules for the plan, computed findings for the coach |
| Claude connector | An MCP server (`supabase/functions/mcp`). Claude reads the game and leaves changes (quests, daily quests, objectives, arcs, coach note) that the app applies on open. Set up in Connect → Claude |
| Scheduled coach | Two Claude Code routines on claude.ai: a 07:00 check-in and a 21:30 review, through the connector |
| Objectives | Each arc holds daily, weekly or whole-arc counts; quests linked to an objective count toward it |
| Quests, XP, levels, stats, earned screen time | Working. Each level pays a stat point and 10 banked minutes; titles every 5 levels; rank-ups (every 10) add a streak freeze and an emergency pass; each 10 points in a stat adds 5% XP to its quests |
| Streaks, freezes, milestone chests, daily clear bonus, achievements, skills | Working, each with its own full-screen moment. 44 unique skills (Iron Body, Dawn Walker, Volleyball with its own branches, Wave Rider…) level from 1 to 10 with how you play. They come from the Supabase `skills` table, so they can be edited without an app update; the app falls back to the same list built in |
| Status sheet and character profile | Status shows a game-style status window (stats with + to spend points) and a character profile |
| Rewards tab | Titles, minutes, freezes, passes, next streak chest, achievements |
| Seven stats | Strength, Agility, Vitality, Intelligence, Wisdom, Charisma, Willpower, shown as a seven-sided chart on Status |
| HP | Finishing quests heals, most of all clearing one arc's quests for a day; missed quests, a missed must-do and a short night hurt, at most 40 HP a day. Under 30% you are wounded (half XP); at 0 you are in the penalty zone |
| Penalty zone and recovery quests | Working. Missing anything yesterday brings one short make-up quest in the morning, from the arc you missed (rank D, 15-20 min); the locked apps stay shut until it is done. A missed must-do also costs 25 HP at once |
| Lock-in hours | Screen Time setup: hours when the locked apps stay shut even with minutes banked (for example 11 PM to 7 AM) |
| Bosses | You add a deadline and its tasks; ticking tasks drains its HP |
| Coach | Reads your last 7 days of quests, your stats and your bosses; suggests quests you can add with one tap |
| Weekly chart | Status shows planned and finished quests per day (Swift Charts) |
| Reminders | Local notifications for today's open quests and the next three days. Off until you switch them on in Status |
| Sounds | Quest complete, level up, boss hit. Switch in Status |
| Cloud backup (Supabase) | Profile and today's quests are saved after every change. Reading them back is Exercise 10. Reward fields are not uploaded until `20261124120000_rewards.sql` is applied |
| Apple Health | Steps, running distance, mindful minutes and sleep. Quests named like "8,000 steps", "Run 5 km" or "Meditate 10 min" complete themselves, also in the background |
| Garmin | Through Apple Health (steps, runs, sleep, calories, resting heart rate, HRV, VO2 max), and directly through the Garmin Connect Personal API (`supabase/functions/garmin`: Body Battery, stress, sleep score, HRV). The function needs the `GARMIN_API_KEY` secret |
| Notifications | Quest reminders, daily nudges (morning summary, evening count, must-do warning) and streak and reward alerts on the phone; push alerts when Claude changes the plan or answers the Coach (`supabase/functions/_shared/apns.ts`, needs an APNs key) |
| Calendars (Google included) | Read through EventKit. Add Google under iOS Settings → Calendar → Accounts. Daily quests move off busy blocks; Today lists your events with + to make one a quest |
| Apple Reminders | Reminders due today become quests; finishing either side finishes the other |
| Alarms | AlarmKit on iOS 26: per-quest alarms and a daily wake-up alarm, Done and Snooze; switch them on in a quest's info window or after a day clear. iOS gives no app access to Clock app alarms |
| Widget | Shows your real next quest, level and streak |
| Shield / intercept | In-app preview only |
| Meal plans, sleep quests, benchmarks vs. your age | Removed with the mock data. They need real sources first |
| Go back end, USDA | Not started |
| Screen Time lock | Chosen apps stay locked; spending earned minutes opens them for that long (`ScreenTimeLock.swift`, `TotonouMonitor` extension re-locks). Also tracks daily use of those apps in 15-minute steps for the Coach and Claude. Works only on a real iPhone; untested on a device so far |

Designs for the new screens: [Totonou — Rewards and connections](https://www.figma.com/design/j8aW56j4oZgsnb2LTFZek3) (Figma).

Debug builds accept the launch argument `-previewCelebrations` to show every celebration screen once without changing any data.

## Run it

Open `ios/Totonou.xcodeproj` in Xcode 16 or later, pick an iPhone simulator, press Run.

The pure-Swift rules have tests:

```bash
cd ios/TotonouCore && swift test
```

Nine of those tests fail until Exercises 2, 12 and 14 in [LEARN.md](LEARN.md) are done.

## Supabase

The app signs in anonymously and saves to two tables, `profiles` and `quests`.
Project URL and publishable key are in `ios/Totonou/Services/SupabaseCloudStore.swift`
(the publishable key is safe to commit; row-level security does the protecting).

One-time setup in the Supabase dashboard:

1. SQL Editor: paste and run each file in `supabase/migrations/`, oldest first
   (`…_init.sql`, `…_rewards.sql`, `…_skills.sql`).
2. Authentication → Sign In / Providers: turn on "Allow anonymous sign-ins".

The bottom of the Status screen shows whether the last backup worked, and why not.

## Layout

```
ios/
├── Totonou.xcodeproj
├── Totonou/              the app
│   ├── App/              entry point, tab bar, components, icons, characters, motion
│   ├── Models/           SwiftData models
│   ├── Services/         quest engine, signal sources, arc planner, mock data
│   ├── Features/         Today, Arcs, Status, Coach, Shield
│   └── Exercises/        unfinished on purpose — see LEARN.md
├── TotonouWidget/        WidgetKit extension
├── TotonouCore/          Swift package: game rules, theme, shared types, tests
└── Config/               widget Info.plist
```

Folders in the Xcode project are synchronised with disk: add a Swift file to a
folder and it is part of the target.

## Design

Plain and readable first: one sans-serif face (the system font) at generous
sizes, rounded digits for game numbers, short English labels. A deep-blue
gradient background rather than black, off-white text, one bright blue for the
system and one warm red for stamps, bosses and penalties.

Anything the game says to you arrives in a **system window** (`SystemWindow`): a
glowing translucent blue panel with cut corners and a centred, capitalised
title. The next quest, quest info, penalties, the coach and your plan all use
it. Everything else is a quiet rounded card. Japanese appears only as small kana
touches: the greeting (おはよう), the クリア stamp, レベルアップ.

The palette and fonts are in `ios/TotonouCore/Sources/TotonouCore/Theme.swift`.

Nothing is an image file except the app icon. All of it is drawn in SwiftUI:

- **Icons** — `ios/Totonou/App/Glyphs.swift`. Twenty-two stroke icons on a 24-point
  grid: `GlyphIcon(.moon)`. Add a case to `Glyph` to add one.
- **Characters** — `ios/Totonou/App/Characters.swift`. The hooded human (Status;
  aura grows with rank), the oni mask (bosses; eyes dim with HP), the kitsune mask
  (coach) and the daruma (arcs; second eye fills as the arc runs, tap it).
- **Motion** — `ios/Totonou/App/Motion.swift`. Staggered section entrances, numbers
  that count, a boss-hit shake, drifting particles, the reward banner. Everything
  stands still when Reduce Motion is on.

Each of those files has an Xcode preview showing the whole set.

## Dev notes

- To start over, delete the app from the simulator.
- Sounds are generated tones in `ios/Totonou/Sounds`. Replace the three .wav
  files to change them; keep the names.
