import SwiftData
import SwiftUI
import TotonouCore

/// Shows the engine's current celebration full screen. One at a time: closing
/// it brings up the next in the queue.
struct CelebrationView: View {
    let celebration: Celebration
    var spend: () -> Void
    let dismiss: () -> Void

    var body: some View {
        switch celebration.kind {
        case .levelUp(let event):
            LevelUpOverlay(event: event, spend: spend, dismiss: dismiss)
        case .milestone(let milestone):
            MilestoneScreen(milestone: milestone, dismiss: dismiss)
        case .achievement(let achievement):
            AchievementScreen(achievement: achievement, dismiss: dismiss)
        case .dayClear(let event):
            DayClearScreen(event: event, dismiss: dismiss)
        case .freezeUsed(let days, let streak):
            FreezeScreen(days: days, streak: streak, dismiss: dismiss)
        case .skill(let skill, let level):
            SkillScreen(skill: skill, level: level, dismiss: dismiss)
        }
    }
}

private struct SkillScreen: View {
    let skill: SkillDefinition
    let level: Int
    let dismiss: () -> Void

    var body: some View {
        Moment(tint: skill.tint, dismiss: dismiss) {
            KitsuneSpirit(tails: 3, tint: skill.tint).frame(width: 90, height: 90)
        } content: {
            SystemWindow(title: level == 1 ? "New skill acquired" : "Skill level up", tint: Ink.ai) {
                GlyphIcon(skill.icon, size: 48, tint: .white)
                Text(skill.name).font(.text(28, weight: .bold))
                Text("Lv. \(level)").font(.number(34, weight: .heavy)).foregroundStyle(skill.tint == Ink.ai ? .white : skill.tint)
                Text(skill.detail).font(.text(17, weight: .medium))
            }
        }
    }
}

/// The frame every celebration shares: dark backdrop, drifting motes, a figure
/// on top, content, and one button at the bottom.
private struct Moment<Figure: View, Content: View>: View {
    var tint: Color = Ink.ai
    var button = "Continue"
    let dismiss: () -> Void
    @ViewBuilder var figure: Figure
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        ZStack {
            // Opaque: windows are translucent, so nothing may show through.
            Backdrop()
            Ink.deep.opacity(0.7).ignoresSafeArea()
            InkMist(count: 30, tint: tint).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    figure
                    content
                    Button(button, action: dismiss)
                        .buttonStyle(SystemButtonStyle(tint: tint, filled: true))
                        .padding(.top, 6)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 48)
                .foregroundStyle(Ink.washi)
                .opacity(shown ? 1 : 0)
                .scaleEffect(shown || reduceMotion ? 1 : 0.94)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear { withAnimation(.spring(duration: 0.5, bounce: 0.3)) { shown = true } }
        .sensoryFeedback(.success, trigger: shown)
    }
}

private struct MilestoneScreen: View {
    let milestone: StreakMilestone
    let dismiss: () -> Void

    var body: some View {
        Moment(tint: Ink.kin, button: "Claim", dismiss: dismiss) {
            HStack(spacing: 6) {
                Koi().frame(width: 92, height: 92)
                GlyphIcon(.flame, size: 64, tint: Ink.shu).shadow(color: Ink.shu, radius: 20)
            }
        } content: {
            Text("\(milestone.days)").font(.number(88, weight: .heavy)).shadow(color: Ink.shu.opacity(0.8), radius: 24)
            SystemLine("\(milestone.days)-day streak", tint: Ink.kin, size: 22)
            SystemWindow(title: "Milestone chest", tint: Ink.kin) {
                GlyphIcon(.chest, size: 52, tint: .white)
                Text("Opened for keeping at it \(milestone.days) days in a row.").font(.text(17, weight: .medium))
            }
            RewardCard(glyph: .hourglass, value: "+\(milestone.minutes) min", label: "Banked screen time")
            if milestone.freezes > 0 {
                RewardCard(glyph: .freeze, value: "+\(milestone.freezes) streak freeze", label: "Hold up to \(Rewards.maxFreezes)")
            }
        }
    }
}

private struct AchievementScreen: View {
    let achievement: Achievement
    let dismiss: () -> Void

    var body: some View {
        let tint = achievement.rarity.tint
        Moment(tint: tint, dismiss: dismiss) {
            GlyphIcon(achievement.glyph, size: 72, tint: tint)
                .frame(width: 120, height: 120)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(tint.opacity(0.8), lineWidth: 1.5))
                .shadow(color: tint, radius: 24)
        } content: {
            SystemWindow(title: "Achievement unlocked", tint: tint == Ink.mute ? Ink.ai : tint) {
                Text(achievement.title.uppercased()).font(.hud(30))
                SystemLine(achievement.rarity.title, tint: tint == Ink.mute ? .white : tint)
                Text(achievement.detail).font(.text(17, weight: .medium))
            }
            RewardCard(glyph: .star, value: achievement.title, label: "New title. Wear it from Rewards.", tint: tint)
        }
    }
}

private struct DayClearScreen: View {
    let event: DayClearEvent
    let dismiss: () -> Void

    @Environment(QuestEngine.self) private var engine
    @Query(sort: \Arc.startDate, order: .reverse) private var arcs: [Arc]

    var body: some View {
        Moment(tint: Ink.ai, button: "Good night", dismiss: dismiss) {
            Lantern().frame(width: 96, height: 96)
        } content: {
            SystemWindow(title: "Day clear") {
                Text("\(event.done) / \(event.done)").font(.number(56, weight: .heavy))
                SystemLine("Every quest is done")
                HStack(spacing: 12) {
                    Text("Clear bonus").font(.text(16, weight: .medium))
                    RewardChip(glyph: .star, text: "+\(Rewards.dailyClearXP) XP")
                    RewardChip(glyph: .hourglass, text: "+\(Rewards.dailyClearMinutes) min")
                }
            }
            SystemPanel {
                line(.hourglass, "Screen time earned", "+\(event.minutes) min", Ink.ai)
                line(.flame, "Streak", "\(event.streak) days", Ink.shu)
                if !event.statLines.isEmpty {
                    line(.rankUp, "Stats moved", event.statLines, Ink.jade)
                }
            }
            if let tomorrow = event.tomorrow {
                SystemPanel(glow: true) {
                    HStack(spacing: 12) {
                        GlyphIcon(.alarm, size: 26, tint: Ink.ai)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tomorrow \(tomorrow.clock)").font(.text(17, weight: .semibold))
                            Text(tomorrow.title).caption(size: 14)
                        }
                        Spacer()
                        if engine.alarms.isSupported {
                            Toggle("Wake-up alarm", isOn: Binding(
                                get: { engine.wakeAlarmID != nil },
                                set: { on in Task { await engine.setWakeAlarm(on, plan: arcs.dailyPlan()) } }
                            ))
                            .labelsHidden()
                            .tint(Ink.ai)
                        }
                    }
                }
            }
        }
    }

    private func line(_ glyph: Glyph, _ label: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            GlyphIcon(glyph, size: 20, tint: tint)
            Text(label).caption(size: 16)
            Spacer()
            Text(value).font(.number(19, weight: .bold)).foregroundStyle(tint)
        }
    }
}

private struct FreezeScreen: View {
    let days: Int
    let streak: Int
    let dismiss: () -> Void

    var body: some View {
        Moment(tint: Ink.ai, dismiss: dismiss) {
            Omamori().frame(width: 96, height: 96)
        } content: {
            SystemWindow(title: "Notification", notice: true, leading: true) {
                Text("You missed \(days == 1 ? "a day" : "\(days) days"). \(days == 1 ? "A streak freeze was" : "\(days) streak freezes were") used.")
                    .font(.text(17, weight: .medium))
                SystemLine("Your \(streak)-day streak is safe", tint: Ink.ai)
            }
        }
    }
}
