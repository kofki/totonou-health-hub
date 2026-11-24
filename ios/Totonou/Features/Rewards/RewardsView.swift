import SwiftData
import SwiftUI
import TotonouCore

/// Everything you have earned, and what is next.
struct RewardsView: View {
    @Environment(QuestEngine.self) private var engine
    @Query private var players: [Player]
    @State private var showSpend = false
    @State private var choosingTitle = false

    var body: some View {
        Screen {
            if let player = players.first {
                header
                hero(player)
                if player.unspentStatPoints > 0 { unspent(player) }
                inventory(player)
                if let next = NextMilestone.after(streak: player.streak()) { milestone(next, streak: player.streak()) }
                titles(player)
                achievements(player)
            }
        }
        .sheet(isPresented: $showSpend) { StatSpendView() }
    }

    private var header: some View {
        HStack {
            Text("Rewards").font(.text(34, weight: .bold))
            Spacer()
            ToriiLogo().frame(width: 40, height: 40)
        }
    }

    private func hero(_ player: Player) -> some View {
        let level = player.progress.level
        let next = Titles.next(after: level)
        return Button { choosingTitle = true } label: {
            SystemPanel(tint: Ink.kin, glow: true) {
                HStack(spacing: 14) {
                    RankBadge(rank: Rank.forLevel(level), size: 48)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Level \(level)\(player.activeTitle.map { " · \($0)" } ?? "")").font(.text(20, weight: .bold))
                        Text("Next title at level \(next.level): \(next.title)").caption(size: 14)
                    }
                    Spacer(minLength: 0)
                    KitsuneSpirit(tails: KitsuneSpirit.tails(for: Rank.forLevel(level)))
                        .frame(width: 56, height: 56)
                }
            }
        }
        .buttonStyle(PressStyle())
        .confirmationDialog("Wear a title", isPresented: $choosingTitle, titleVisibility: .visible) {
            ForEach(player.titles, id: \.self) { title in
                Button(title) { engine.wear(title, player: player) }
            }
            Button("No title") { engine.wear(nil, player: player) }
        }
    }

    private func unspent(_ player: Player) -> some View {
        Button { showSpend = true } label: {
            SystemWindow(title: "\(player.unspentStatPoints) stat point\(player.unspentStatPoints == 1 ? "" : "s") to spend") {
                SystemLine("Tap to choose")
            }
        }
        .buttonStyle(PressStyle())
    }

    private func inventory(_ player: Player) -> some View {
        HStack(spacing: 10) {
            item(ManekiNeko(), "\(player.bankedMinutes)", "minutes", Ink.kin)
            item(Omamori(), "\(player.streakFreezes)/\(Rewards.maxFreezes)", "freezes", Ink.ai)
            item(GlyphIcon(.pass, size: 34, tint: Ink.shu), "\(player.emergencyPasses)", "passes", Ink.shu)
        }
    }

    private func item(_ figure: some View, _ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            figure.frame(width: 52, height: 52)
            Text(value).font(.number(24, weight: .bold))
            Text(label).caption(size: 13)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Ink.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(tint.opacity(0.4), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func milestone(_ next: (milestone: StreakMilestone, daysLeft: Int), streak: Int) -> some View {
        SystemPanel {
            HStack(spacing: 8) {
                GlyphIcon(.flame, size: 22, tint: Ink.shu)
                Text("Next chest: \(next.milestone.days)-day streak").font(.text(17, weight: .semibold))
                Spacer()
                Text("\(streak)/\(next.milestone.days)").font(.number(17)).foregroundStyle(Ink.mute)
            }
            MeterBar(value: Double(streak) / Double(next.milestone.days), tint: Ink.shu, segments: 0)
        }
    }

    /// Titles you hold, each with a star; the one you wear is lit. Tap to wear it.
    @ViewBuilder private func titles(_ player: Player) -> some View {
        if !player.titles.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Titles") { Text("\(player.titles.count)").caption(size: 15) }
                ForEach(player.titles, id: \.self) { title in
                    let worn = title == player.activeTitle
                    Button { engine.wear(worn ? nil : title, player: player) } label: {
                        HStack(spacing: 12) {
                            GlyphIcon(worn ? .crown : .star, size: 22, tint: worn ? Ink.kin : Ink.mute)
                            Text(title).font(.text(17, weight: worn ? .bold : .medium))
                            Spacer()
                            if worn { Text("Worn").caption(Ink.kin, size: 13) }
                        }
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
    }

    private func achievements(_ player: Player) -> some View {
        let earned = player.achievements
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Achievements") {
                Text("\(earned.count) of \(Achievement.allCases.count)").caption(size: 15)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(Achievement.allCases, id: \.self) { achievement in
                    AchievementBadge(achievement: achievement, earned: earned.contains(achievement))
                }
            }
        }
    }
}

/// The game's own summary of you, written the way a "system" would.
struct CharacterProfile: View {
    let player: Player
    let quests: [Quest]

    var body: some View {
        SystemWindow(title: "<Character profile>", leading: true) {
            attributes
            field("Personal skills", skills.isEmpty ? "None" : skills.joined(separator: ", "))
            field("Overall evaluation", evaluation)
        }
    }

    private func label(_ text: String) -> Text {
        Text("\(text.uppercased()): ").font(.hud(16)).foregroundStyle(.white.opacity(0.75))
    }

    private func field(_ name: String, _ value: String) -> some View {
        (label(name) + Text(value).font(.text(16, weight: .medium)))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Achievements, each with its rarity in its rarity's colour.
    private var attributes: some View {
        let earned = Achievement.allCases.filter(player.achievements.contains)
        var line = label("Personal attributes")
        if earned.isEmpty { line = line + Text("None").font(.text(16, weight: .medium)) }
        for (index, achievement) in earned.enumerated() {
            let tint = achievement.rarity.tint == Ink.mute ? Color.white.opacity(0.75) : achievement.rarity.tint
            line = line + Text(achievement.title).font(.text(16, weight: .medium))
                + Text(" (\(achievement.rarity.title))").font(.text(16, weight: .bold)).foregroundStyle(tint)
                + Text(index < earned.count - 1 ? ", " : "")
        }
        return line.frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Unlocked unique skills, highest level first.
    private var skills: [String] {
        let facts = player.skillFacts()
        return Skill.allCases
            .map { ($0, $0.level(facts)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map { "[\($0.0.name) Lv. \($0.1)]" }
    }

    private var evaluation: String {
        let values = Stat.allCases.map { ($0, player.value(for: $0)) }
        guard let top = values.max(by: { $0.1 < $1.1 }), let low = values.min(by: { $0.1 < $1.1 }), top.1 > 0 else {
            return "Not enough data yet. The system is watching."
        }
        let streak = player.streak()
        var lines = ["\(top.0.title) leads."]
        if top.1 - low.1 >= 10 { lines.append("\(low.0.title) lags far behind.") }
        lines.append(streak >= 7 ? "A \(streak)-day streak. Keep the fire going." : "Consistency is still being tested.")
        return lines.joined(separator: " ")
    }
}
