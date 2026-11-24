# Learning Swift in this codebase

The app runs as it is. Pieces were left unfinished on purpose, each one
marked `TODO(you)` with instructions at the top of its file. They go from plain
Swift to SwiftUI to the Apple frameworks, and each one changes something you can
see in the app.

Do them in order. Before each, read the file listed under "Read first": it shows
the same idea already working somewhere else in the project.

| # | Exercise | File | What lights up | Read first |
|---|---|---|---|---|
| 1 | ~~Streak~~ handed over, solved by Claude | `ios/TotonouCore/Sources/TotonouCore/Exercises/Exercise1_Streak.swift` | The streak number on Today (now always 0) | `GameRules.swift` → `LevelCurve` |
| 2 | Overall score | `ios/TotonouCore/Sources/TotonouCore/Exercises/Exercise2_OverallScore.swift` | Tests only for now. The benchmarks section left the app with the mock data and returns with real health data | `GameRules.swift` → `Rank` |
| 3 | Word of the day card (no longer shown: the owner removed Japanese text on 2026-11-24; keep it as practice or retire it) | `ios/Totonou/Exercises/Exercise3_WordOfDayCard.swift` | Placeholder panel at the bottom of Status | `App/Components.swift` |
| 4 | Quest log | `ios/Totonou/Exercises/Exercise4_QuestHistoryView.swift` | The QUEST LOG sheet on Status | `Features/Today/TodayView.swift`, `Services/QuestPlanner.swift` |
| 5 | ~~Level-up animation~~ handed over, solved by Claude | `ios/Totonou/Exercises/Exercise5_LevelUpOverlay.swift` | The overlay when you gain a level | `TodayView.swift` → the `ClearStamp` transition |
| 6 | ~~HealthKit source~~ handed over, solved by Claude | `ios/Totonou/Exercises/Exercise6_HealthKitSignalSource.swift` | Real steps, runs and sleep complete quests | `Services/Signals.swift`, `Services/QuestEngine.swift` |
| 7 | Live widget: steps 1–3 handed over and solved; step 4 (a second widget) is still yours | `ios/TotonouWidget/TotonouWidget.swift` | The widget shows your real next quest | `TotonouCore/.../Shared.swift` → `WidgetSnapshot` |
| 8 | Flame icon | `ios/Totonou/Exercises/Exercise8_FlameGlyph.swift` | The icon beside your streak on Today (now a diamond) | `App/Glyphs.swift` → `.mountain`, `.heart`, `.moon` |
| 9 | Coach blink | `ios/Totonou/Exercises/Exercise9_KitsuneBlink.swift` | The fox on Coach blinks | `App/Characters.swift` → the hunter's aura, the oni's eyes |
| 10 | Restore from the cloud | `ios/Totonou/Services/SupabaseCloudStore.swift` | Progress saved in Supabase comes back on launch | the two `save` functions in the same file |
| 11 | Fold the Done list | `ios/Totonou/Exercises/Exercise11_DoneSection.swift` | Tapping "Done" on Today hides finished quests | `Features/Today/TodayView.swift` → `selected` |
| 13 | Achievement badge | `ios/Totonou/Exercises/Exercise13_AchievementBadge.swift` | The achievement grid on Rewards shows earned and locked badges | `Features/Rewards/RewardViews.swift` → `RewardCard` |
| 12 | Next milestone | `ios/TotonouCore/Sources/TotonouCore/Exercises/Exercise12_NextMilestone.swift` | The "Next chest" bar on the Rewards screen | `Rewards.swift` → `StreakMilestones` |
| 14 | Busy-block filter | `ios/TotonouCore/Sources/TotonouCore/Exercises/Exercise14_BusyFilter.swift` | All-day, free and declined events stop pushing quests around | `DayPlanning.swift` → `CalendarEventInfo` |

Exercises 8 and 9 are short and visual. They fit well between 3 and 4, once you
are comfortable with the Xcode canvas.

## Exercises 2, 12 and 14 have tests

```bash
cd ios/TotonouCore && swift test
```

Nine tests fail until you finish them. That is the starting state, not a bug.
Run one exercise at a time with `swift test --filter Overall`, `--filter NextMilestone` or `--filter BusyFilter`.


## How to work

- Write it yourself first. When you are stuck for more than twenty minutes, ask
  Claude for a hint — not the answer.
- When an exercise works, ask Claude to review it and to quiz you on it.
- An exercise is done when you can explain every line and could rewrite it
  without looking.

## A reading order for the rest of the code

1. `TotonouCore/Sources/TotonouCore/GameRules.swift` — enums, structs, computed properties.
2. `Totonou/Models/Models.swift` — SwiftData `@Model` classes and relationships.
3. `Totonou/Services/QuestEngine.swift` — `@Observable`, `@MainActor`, async functions.
4. `Totonou/App/Components.swift` — small reusable views, `Shape`, `ButtonStyle`, generics with `@ViewBuilder`.
5. `Totonou/App/Glyphs.swift` — drawing with `Path`. Open its preview to see every icon.
6. `Totonou/App/Motion.swift` — every animation helper: entrances, counting numbers, the shake, particles.
7. `Totonou/App/Characters.swift` — the hunter, oni, kitsune and daruma, built from the two files above.
8. `Totonou/Features/Today/TodayView.swift` — `@Query`, `@Environment`, composing a screen.
9. `Totonou/App/TotonouApp.swift` — how the app starts and where the database comes from.
