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
| 9 | Coach blink | `ios/Totonou/Exercises/Exercise9_KitsuneBlink.swift` | The fox on Coach blinks | `App/Characters.swift` → the human's aura, the oni's eyes |
| 10 | Restore from the cloud | `ios/Totonou/Services/SupabaseCloudStore.swift` | Progress saved in Supabase comes back on launch | the two `save` functions in the same file |
| 11 | Fold the Done list | `ios/Totonou/Exercises/Exercise11_DoneSection.swift` | Tapping "Done" on Today hides finished quests | `Features/Today/TodayView.swift` → `selected` |
| 13 | Achievement badge | `ios/Totonou/Exercises/Exercise13_AchievementBadge.swift` | The achievement grid on Rewards shows earned and locked badges | `Features/Rewards/RewardViews.swift` → `RewardCard` |
| 12 | Next milestone | `ios/TotonouCore/Sources/TotonouCore/Exercises/Exercise12_NextMilestone.swift` | The "Next chest" bar on the Rewards screen | `Rewards.swift` → `StreakMilestones` |
| 14 | Busy-block filter | `ios/TotonouCore/Sources/TotonouCore/Exercises/Exercise14_BusyFilter.swift` | All-day, free and declined events stop pushing quests around | `DayPlanning.swift` → `CalendarEventInfo` |
| 15 | Cloud arc planner | `ios/Totonou/Exercises/Exercise15_CloudArcPlanner.swift` | "New arc" on a phone without Apple Intelligence gets a plan written by AI instead of keyword rules (needs the `ai` function deployed) | `Services/CloudAI.swift` → `CloudCoachAdvisor`, `Services/OnDeviceAI.swift` → `OnDeviceArcPlanner` |
| 16 | Merge the daily plans | `ios/TotonouCore/Sources/TotonouCore/Exercises/Exercise16_PlanMerger.swift` | "Every day" on the Arcs tab lists all your arcs' quests in time order, with no repeats; reminders and the wake alarm use the same list | `DayPlanning.swift` → `DayPlanner`, `Models/Models.swift` → `dailyPlan` |
| 17 | Finished arc row | `ios/Totonou/Exercises/Exercise17_FinishedArcRow.swift` | Finished arcs on the Arcs tab show how they ended, how long they ran and what you got done (now only a grey title) | `Features/Arcs/ArcsView.swift` → `ArcRow`, `Models/Models.swift` → `Arc` |
| 18 | Objective row | `ios/Totonou/Exercises/Exercise18_ObjectiveRow.swift` | Each objective in an arc shows its count as pips, turns jade when met, and unfolds the quests that count toward it (now one plain line) | `Features/Arcs/ArcsView.swift` → `ArcRow`, `CheckBox`; `Models/Models.swift` → `Objective` |

Exercises 8 and 9 are short and visual. They fit well between 3 and 4, once you
are comfortable with the Xcode canvas.

## Exercises 2, 12, 14 and 16 have tests

```bash
cd ios/TotonouCore && swift test
```

Eleven tests fail until you finish them. That is the starting state, not a bug.
Run one exercise at a time with `swift test --filter Overall`, `--filter NextMilestone`, `--filter BusyFilter` or `--filter PlanMerger`.


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
7. `Totonou/App/Characters.swift` — the human, oni, kitsune and daruma, built from the two files above.
8. `Totonou/Features/Today/TodayView.swift` — `@Query`, `@Environment`, composing a screen.
9. `Totonou/App/TotonouApp.swift` — how the app starts and where the database comes from.
