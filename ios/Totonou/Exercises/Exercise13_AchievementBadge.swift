import SwiftUI
import TotonouCore

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 13 · Achievement badge                      (SwiftUI views, state)
//
// The Rewards screen shows a grid of these, one per achievement. Right now each
// badge shows its icon and name, but every badge looks the same: you cannot
// tell earned from locked, or common from legendary, at a glance.
//
// Build it
//   1. A rounded tile, about 80 points wide, on Ink.raised.
//   2. Earned: the icon in its rarity colour (`achievement.rarity.tint`), a
//      border in the same colour, and the title under it.
//   3. Locked: a `.lock` glyph in Ink.mute, the title muted, the tile at
//      about 45% opacity. Do not show the glyph, so it stays a surprise.
//   4. Tapping a tile shows `achievement.detail` (try .popover, or a small
//      overlay toggled by @State).
//   5. Accessibility: one label per tile, "First boss, earned" or "Locked".
//
// You will practise: conditional views, ViewBuilder, @State, accessibility.
// Read first: RewardCard in Features/Rewards/RewardViews.swift, RankBadge in
// App/Components.swift. Check it in the #Preview below, then on the Rewards tab.
// ─────────────────────────────────────────────────────────────────────────────

struct AchievementBadge: View {
    let achievement: Achievement
    let earned: Bool

    var body: some View {
        // TODO(you): replace this with the tile described above.
        VStack(spacing: 6) {
            GlyphIcon(achievement.glyph, size: 26, tint: Ink.washi)
            Text(achievement.title)
                .font(.text(12, weight: .semibold))
                .multilineTextAlignment(.center)
        }
        .frame(width: 80, height: 80)
    }
}

#Preview {
    HStack {
        AchievementBadge(achievement: .firstBoss, earned: true)
        AchievementBadge(achievement: .streak30, earned: false)
    }
    .padding()
    .background(Ink.sumi)
    .foregroundStyle(Ink.washi)
}
