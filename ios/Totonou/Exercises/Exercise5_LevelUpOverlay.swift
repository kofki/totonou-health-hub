import SwiftUI
import TotonouCore

// ─────────────────────────────────────────────────────────────────────────────
// EXERCISE 5 · Level up                                       (animation)
//
// Status: handed over to Claude on 2026-11-24 (owner's choice). Solved below.
// Read it as a worked example of a staged entrance:
//   • one `stage` number drives everything; each part appears when stage passes it
//   • the stages advance on a timer in .task, so leaving the screen cancels them
//   • .contentTransition(.numericText()) rolls the level number
//   • .sensoryFeedback fires a haptic when a stage is reached
//   • with Reduce Motion on, everything is shown at once and only fades
// ─────────────────────────────────────────────────────────────────────────────

struct LevelUpOverlay: View {
    let event: LevelUpEvent
    /// Opens the stat-point screen. Nil hides the button.
    var spend: (() -> Void)?
    let dismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage = 0
    @State private var shownLevel: Int

    init(event: LevelUpEvent, spend: (() -> Void)? = nil, dismiss: @escaping () -> Void) {
        self.event = event
        self.spend = spend
        self.dismiss = dismiss
        _shownLevel = State(initialValue: event.from)
    }

    private var rank: Rank { Rank.forLevel(event.to) }
    private var tint: Color { event.isRankUp ? Ink.kin : Ink.ai }
    private let lastStage = 4

    var body: some View {
        ZStack {
            Backdrop()
            Ink.deep.opacity(0.7).ignoresSafeArea()
            InkMist(count: event.isRankUp ? 50 : 30, tint: tint).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    KitsuneSpirit(tails: KitsuneSpirit.tails(for: rank), tint: tint)
                        .frame(width: 96, height: 96)
                        .reveal(stage >= 0)

                    SystemLine(event.isRankUp ? "Rank up" : "Level up", tint: tint, size: 22)
                        .reveal(stage >= 0)

                    if event.isRankUp {
                        HStack(spacing: 18) {
                            RankBadge(rank: Rank.forLevel(event.from), size: 56, dimmed: true)
                            GlyphIcon(.rankUp, size: 28, tint: Ink.mute)
                            RankBadge(rank: rank, size: 96)
                                .shadow(color: rank.tint, radius: 26)
                        }
                        .reveal(stage >= 1)
                    }

                    Text("\(shownLevel)")
                        .font(.number(event.isRankUp ? 88 : 120, weight: .heavy))
                        .contentTransition(.numericText(value: Double(shownLevel)))
                        .shadow(color: tint.opacity(0.9), radius: 28)
                        .reveal(stage >= 1)

                    VStack(spacing: 6) {
                        ProgressLine(value: stage >= 1 ? 1 : 0, tint: tint, height: 8)
                            .frame(width: 280)
                        Text("Level \(event.from) → \(event.to)").caption(size: 14)
                    }
                    .reveal(stage >= 1)

                    if !event.evidence.isEmpty {
                        SystemWindow(title: "What earned it", tint: tint) {
                            ForEach(event.evidence, id: \.self) { line in
                                Text(line).font(.text(17, weight: .medium))
                            }
                        }
                        .reveal(stage >= 2)
                    }

                    VStack(spacing: 10) {
                        ForEach(Array(rewardCards.enumerated()), id: \.offset) { index, card in
                            card.reveal(stage >= 3, delay: reduceMotion ? 0 : Double(index) * 0.12)
                        }
                    }

                    VStack(spacing: 10) {
                        if let spend, event.statPoints > 0 {
                            Button("Spend stat point\(event.statPoints == 1 ? "" : "s")") { spend() }
                                .buttonStyle(SystemButtonStyle(tint: tint, filled: true))
                        }
                        Button("Continue", action: dismiss)
                            .buttonStyle(SystemButtonStyle(tint: tint))
                    }
                    .reveal(stage >= lastStage)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 40)
                .foregroundStyle(Ink.washi)
            }
            .scrollIndicators(.hidden)
        }
        .contentShape(Rectangle())
        // First tap shows everything; once all is shown, the buttons decide.
        .onTapGesture { if stage < lastStage { show(lastStage) } }
        .sensoryFeedback(.impact(weight: .heavy), trigger: stage == 1)
        .sensoryFeedback(.success, trigger: stage == 3)
        .task { await play() }
    }

    private var rewardCards: [RewardCard] {
        var cards = [
            RewardCard(glyph: .crown, value: "+\(event.statPoints) stat point\(event.statPoints == 1 ? "" : "s")",
                       label: "Choose where it goes"),
            RewardCard(glyph: .hourglass, value: "+\(event.minutes) min", label: "Banked screen time"),
        ]
        for title in event.titles {
            cards.append(RewardCard(glyph: .star, value: title, label: "New title", tint: Ink.kin))
        }
        if event.freezes > 0 {
            cards.append(RewardCard(glyph: .freeze, value: "+\(event.freezes) streak freeze", label: "Saves one missed day"))
        }
        if event.passes > 0 {
            cards.append(RewardCard(glyph: .pass, value: "+\(event.passes) emergency pass", label: "A short unlock, even when locked",
                                    tint: Ink.shu))
        }
        return cards
    }

    private func play() async {
        if reduceMotion { show(lastStage); return }
        for (next, wait) in [(1, 0.35), (2, 0.6), (3, 0.5), (4, 0.6)] {
            guard (try? await Task.sleep(for: .seconds(wait))) != nil else { return }
            show(next)
        }
    }

    private func show(_ next: Int) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.3)) {
            stage = max(stage, next)
            if stage >= 1 { shownLevel = event.to }
        }
    }
}

private extension View {
    /// Hidden until `shown`, then fades and rises into place.
    func reveal(_ shown: Bool, delay: Double = 0) -> some View {
        self
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 12)
            .animation(.spring(duration: 0.5, bounce: 0.25).delay(delay), value: shown)
    }
}

#Preview {
    LevelUpOverlay(event: LevelUpEvent(from: 19, to: 20, rewards: Rewards.rewards(from: 19, to: 20),
                                       evidence: ["6 quests cleared", "2 finished from real data", "Strength +4 · Endurance +2"]),
                   spend: {}, dismiss: {})
}
