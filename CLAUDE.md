# CLAUDE.md — Totonou 整う

## Project

Personal quest system for iOS: arcs → daily quests → auto-completion from real
data → XP, stats and earned screen time, with shields and penalties. Personal use
first. Product spec and current state: `README.md`.

This is also a **learning project**. The owner is learning Swift and SwiftUI.

History: this repo was "Health Hub" (Spring Boot + FastAPI + Expo) until
2026-11-24, when the owner replaced it with Totonou and asked Claude to build the
app while leaving parts for them to write. The rules below replace the old
"Claude writes almost nothing" rules. The owner should edit them if they are
not what was meant.

## Rules for Claude

1. **Never complete an exercise.** Anything marked `TODO(you)`, anything in an
   `Exercises/` folder, and anything listed in `LEARN.md` belongs to the owner.
   Do not fill it in, do not "fix" its failing tests, do not paste a full
   solution in chat. Give hints, point at similar code in the repo, review what
   the owner wrote, and quiz them. Only write the solution if the owner
   explicitly says they give up on that exercise.
2. **Leave something to learn in new work.** When building a new feature, carve
   out one or two self-contained pieces as new exercises (same format: a header
   comment with rules, steps, what they will practise, and a way to check), add
   them to `LEARN.md`, and keep the app building and running without them.
3. **Explain new concepts.** When code uses a Swift or SwiftUI idea not yet in
   the codebase, add a short comment on why, not what.
4. **Review as a teacher.** On the owner's code: explain the problem and let
   them fix it. Do not rewrite it.
5. No sample data in the app (owner's request, 2026-11-24). The app shows only
   what the user created or what a real source reported. Every outside system
   still sits behind a protocol in `ios/Totonou/Services/`, but stand-ins
   (`MockCloudStore`, `NoReminders`, `NoSignalSource`) are for previews and
   tests only. If a feature has no real source yet, leave it out and say so.

## Stack

| Layer | Tech |
|---|---|
| App | Swift, SwiftUI, SwiftData, WidgetKit (iOS 18+) |
| Shared logic | `ios/TotonouCore` Swift package, Swift Testing |
| Cloud | Supabase (Postgres + Auth) via supabase-swift, behind `CloudStore`. Schema in `supabase/migrations/` |
| Back end (planned) | Go on Cloud Run |
| Data (planned) | Garmin Connect, HealthKit, Google Calendar, USDA FoodData Central |
| AI | Foundation Models on-device (`OnDeviceAI.swift`), with rule-based fallbacks. Claude API via a back end is planned |
| Blocking (planned) | FamilyControls, ManagedSettings, DeviceActivity |

## Commands

```bash
cd ios/TotonouCore && swift test          # 7 exercise tests fail until the owner finishes them
xcodebuild -project ios/Totonou.xcodeproj -scheme Totonou \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Conventions

- Design tokens live in `TotonouCore/Theme.swift` (`Ink`, `Backdrop`, `Font.text`,
  `Font.number`, `Font.hud`, `.caption()`). Deep blue, not black. Every difficulty
  rank has its own colour (E grey, D jade, C blue, B violet, A gold, S red); add
  no other colours.
- Game messages (next quest, quest info, penalty, coach, plans) go in a
  `SystemWindow`; everything else in a plain `SystemPanel` card.
- Keep the UI simple (owner's request, 2026-11-24): large sans-serif text, short
  English labels, few captions. No Japanese text in the interface (owner,
  2026-11-24); Japanese-style drawings (kitsune, omamori, torii…) are welcome.
- The system voice: `SystemWindow` titles in condensed capitals in [brackets];
  body text stays in `Font.text`, sentence case, so it is easy to read.
- Icons are `Glyph` cases drawn in `App/Glyphs.swift`, not SF Symbols or images.
  Characters live in `App/Characters.swift` and `App/Spirits.swift`, animation
  helpers in `App/Motion.swift`.
  New motion must respect Reduce Motion.
- Views never mutate XP, stats or the screen-time bank; they call `QuestEngine`.
- Enums are stored in SwiftData as raw strings with a typed accessor.
- The Xcode project uses synchronised folders. Do not add file references to
  `project.pbxproj`; create files in the right folder.

## Git

- `main` is protected. Claude works on `claude/…` branches; the owner's learning
  work goes on `learn/…`. The owner reviews and merges everything.
- Conventional commits.
