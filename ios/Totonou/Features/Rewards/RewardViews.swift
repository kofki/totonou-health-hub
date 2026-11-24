import SwiftData
import SwiftUI
import TotonouCore

// Pieces shared by the reward screens.

extension Stat {
    /// Each stat has its own colour, so its bar and icon read at a glance.
    var tint: Color {
        switch self {
        case .strength: Ink.jade
        case .endurance: Ink.ai
        case .intellect: Ink.violet
        case .discipline: Ink.kin
        case .recovery: Ink.shu
        }
    }
}

extension Skill {
    var glyph: Glyph {
        switch self {
        case .ironBody: .dumbbell
        case .secondWind: .mountain
        case .sharpMind: .book
        case .unyielding: .torii
        case .stillWater: .moon
        case .dawnWalker: .alarm
        case .eternalFlame: .flame
        case .livingProof: .heart
        case .giantSlayer: .sword
        case .phoenix: .rankUp
        case .oathKeeper: .shield
        case .flawless: .star
        }
    }

    var tint: Color {
        switch self {
        case .ironBody: Stat.strength.tint
        case .secondWind: Stat.endurance.tint
        case .sharpMind: Stat.intellect.tint
        case .unyielding: Stat.discipline.tint
        case .stillWater: Stat.recovery.tint
        case .dawnWalker, .eternalFlame: Ink.kin
        case .giantSlayer, .phoenix: Ink.shu
        case .livingProof, .oathKeeper, .flawless: Ink.ai
        }
    }
}

/// One skill line: icon, name, level, and a thin bar towards the next level.
struct SkillRow: View {
    let skill: Skill
    let facts: SkillFacts

    var body: some View {
        let level = skill.level(facts)
        HStack(spacing: 12) {
            GlyphIcon(level > 0 ? skill.glyph : .lock, size: 22, tint: level > 0 ? skill.tint : Ink.mute)
                .frame(width: 40, height: 40)
                .background((level > 0 ? skill.tint : Ink.washi).opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(skill.name).font(.text(17, weight: .semibold))
                    Spacer()
                    Text(level > 0 ? "Lv. \(level)" : "Locked").font(.number(16, weight: .bold))
                        .foregroundStyle(level > 0 ? skill.tint : Ink.mute)
                }
                Text(skill.detail).caption(size: 13)
                MeterBar(value: skill.progress(facts), tint: level > 0 ? skill.tint : Ink.mute, height: 5, segments: 0)
            }
        }
        .opacity(level > 0 ? 1 : 0.55)
        .accessibilityElement(children: .combine)
    }
}

extension Achievement {
    var glyph: Glyph {
        switch self {
        case .firstQuest: .check
        case .firstAuto: .watch
        case .firstBoss: .sword
        case .recovered: .heart
        case .streak7, .streak30: .flame
        case .fullWeek: .calendar
        case .upAtSix: .alarm
        case .quests100: .target
        case .mustDo10: .shield
        case .level10: .rankUp
        case .rankC: .crown
        }
    }
}

/// One reward: an icon, what you got, and a short line under it.
struct RewardCard: View {
    let glyph: Glyph
    let value: String
    let label: String
    var tint: Color = Ink.ai

    var body: some View {
        HStack(spacing: 14) {
            GlyphIcon(glyph, size: 26, tint: tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.text(20, weight: .bold)).foregroundStyle(tint)
                Text(label).caption(size: 14)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Ink.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(tint.opacity(0.55), lineWidth: 1))
        .shadow(color: tint.opacity(0.25), radius: 14)
        .accessibilityElement(children: .combine)
    }
}

/// Put unspent level-up points into stats. Each full 10 points in a stat adds
/// 5% XP to its quests, so every bar shows how close the next 5% is.
struct StatSpendView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(QuestEngine.self) private var engine
    @Query private var players: [Player]
    @State private var lastSpent: Stat?
    @State private var spends = 0

    var body: some View {
        ZStack {
            Backdrop()
            ScrollView {
                if let player = players.first {
                    VStack(spacing: 16) {
                        SystemWindow(title: player.unspentStatPoints == 0 ? "All points spent"
                                     : "\(player.unspentStatPoints) stat point\(player.unspentStatPoints == 1 ? "" : "s") available") {
                            Text("Every 10 points in a stat adds 5% XP to its quests.")
                                .font(.text(16, weight: .medium))
                        }
                        ForEach(Stat.allCases) { stat in
                            row(stat, player: player)
                        }
                        Button("Done") { dismiss() }
                            .buttonStyle(SystemButtonStyle(filled: true))
                    }
                    .padding(20)
                }
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(Ink.washi)
        .sensoryFeedback(.increase, trigger: spends)
    }

    private func row(_ stat: Stat, player: Player) -> some View {
        let value = player.value(for: stat)
        let bonus = (value / 10) * 5
        let canSpend = player.unspentStatPoints > 0
        return VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                GlyphIcon(stat.glyph, size: 22, tint: stat.tint)
                Text(stat.title.uppercased()).font(.hud(18))
                Spacer()
                Text("LV. \(value)").font(.hud(18, weight: .bold)).foregroundStyle(stat.tint)
                    .contentTransition(.numericText(value: Double(value)))
                Button {
                    withAnimation(.snappy) {
                        engine.spendStatPoint(on: stat, player: player)
                        lastSpent = stat
                        spends += 1
                    }
                } label: {
                    GlyphIcon(.plus, size: 18, tint: canSpend ? Ink.sumi : stat.tint)
                        .frame(width: 36, height: 36)
                        .background(stat.tint.opacity(canSpend ? 1 : 0.12), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(PressStyle())
                .disabled(!canSpend)
                .accessibilityLabel("Add a point to \(stat.title)")
            }
            MeterBar(value: Double(value % 10) / 10, tint: stat.tint)
            Text("+\(bonus)% XP · \(10 - value % 10) to +\(bonus + 5)%").caption(size: 13)
        }
        .padding(14)
        .background(Ink.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(stat.tint.opacity(lastSpent == stat ? 0.8 : 0.25), lineWidth: 1))
    }
}
