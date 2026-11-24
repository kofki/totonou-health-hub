# Totonou 整う

A personal quest system: write a life chapter (an arc), get daily quests, let your
watch and calendar complete them, earn XP, stats and screen time. Miss a critical
quest and everything locks until you recover.

**Arcs → Quests → Stats → Rewards**

## Status

The app runs on what you create. There is no sample data: a new install is a
level 1 hunter with no arc, and Today asks you to write one.

| Piece | State |
|---|---|
| Arcs | You describe a chapter; a planner turns it into goals and daily quests, which appear on Today every day |
| Planner and coach AI | Apple's on-device model (Foundation Models, iOS 26 with Apple Intelligence on). Without it: keyword rules for the plan, computed findings for the coach |
| Quests, XP, levels, stats, earned screen time | Working. Each level pays a stat point and 10 banked minutes; titles every 5 levels; rank-ups (every 10) add a streak freeze and an emergency pass; each 10 points in a stat adds 5% XP to its quests |
| Streaks, freezes, milestone chests, daily clear bonus, achievements | Rules and engine working and tested. Their full-screen moments are designed in Figma and not built yet; until then only level-ups show an overlay |
| Penalty zone and recovery quests | Working. A "Must do" switch in the quest composer is still to come, so nothing is critical yet |
| Bosses | You add a deadline and its tasks; ticking tasks drains its HP |
| Coach | Reads your last 7 days of quests, your stats and your bosses; suggests quests you can add with one tap |
| Weekly chart | Status shows planned and finished quests per day (Swift Charts) |
| Reminders | Local notifications for today's open quests and the next three days. Off until you switch them on in Status |
| Sounds | Quest complete, level up, boss hit. Switch in Status |
| Cloud backup (Supabase) | Profile and today's quests are saved after every change. Reading them back is Exercise 10. Reward fields are not uploaded until `20261124120000_rewards.sql` is applied |
| Apple Health | Steps, running distance, mindful minutes and sleep. Quests named like "8,000 steps", "Run 5 km" or "Meditate 10 min" complete themselves, also in the background |
| Garmin | Through Apple Health: turn on Garmin Connect → Settings → Apple Health |
| Calendars (Google included) | Read through EventKit. Add Google under iOS Settings → Calendar → Accounts. Daily quests move off busy blocks. The Today view of your events is not built yet |
| Apple Reminders | Reminders due today become quests; finishing either side finishes the other |
| Alarms | AlarmKit on iOS 26: per-quest alarms and a daily wake-up alarm, Done and Snooze. The switches that turn them on are not built yet. iOS gives no app access to Clock app alarms |
| Widget | Shows your real next quest, level and streak |
| Shield / intercept | In-app preview only |
| Meal plans, sleep quests, benchmarks vs. your age | Removed with the mock data. They need real sources first |
| Go back end, USDA, Claude API | Not started |
| Screen Time API blocking | Not started. It needs a paid Apple Developer account: a free team cannot use the Family Controls capability. Designed in Figma |

Designs for the new screens: [Totonou — Rewards and connections](https://www.figma.com/design/j8aW56j4oZgsnb2LTFZek3) (Figma).

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

1. SQL Editor: paste and run `supabase/migrations/20261124000000_init.sql`.
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
- **Characters** — `ios/Totonou/App/Characters.swift`. The hooded hunter (Status;
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
