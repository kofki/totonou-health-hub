import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 23 · Played label                          (integer maths, formatting)
//
// Sport skills (Volleyball, Wave Rider…) grow with minutes played, which come
// from Garmin and Apple Health. Under each one, Status should say how much you
// have played so far. Right now it shows only the description.
//
// Build it
//   1. 0 minutes: return nil, so nothing is added.
//   2. Under an hour: "45 min so far."
//   3. An hour or more: hours and minutes, "2 h 15 min so far.", and leave the
//      minutes off when they are 0: "3 h so far."
//   4. 100 hours or more: hours only, "120 h so far." (the minutes stop mattering).
//
// You will practise: integer division and remainder (/ and %), optionals as
// "nothing to show", building a string from parts.
// Read first: `SkillRow` in Features/Rewards/RewardViews.swift, which shows it.
// How to check: play a sport your watch records (or add a Volleyball workout
// in the Health app), open Totonou, and look at Status → Skills → See all.
// ─────────────────────────────────────────────────────────────────────────────

func playedLabel(minutes: Int) -> String? {
    // TODO(you): Exercise 23.
    nil
}
