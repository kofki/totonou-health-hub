import SwiftData
import SwiftUI
import TotonouCore

extension SignalKey {
    func goal(_ target: Double) -> String {
        switch self {
        case .steps: "\(Int(target).formatted()) steps"
        case .runKm: "Run \(target.formatted(.number.precision(.fractionLength(0...1)))) km"
        case .focusMinutes: "\(Int(target)) mindful minutes"
        case .sleepHours: "\(target.formatted(.number.precision(.fractionLength(0...1)))) hours of sleep"
        case .activeCalories: "\(Int(target)) active kcal"
        case .restingHeartRate: "Resting heart rate \(Int(target))"
        case .hrv: "HRV \(Int(target)) ms"
        case .vo2Max: "VO2 max \(Int(target))"
        case .bodyBattery: "Body Battery \(Int(target))"
        case .stress: "Stress \(Int(target))"
        case .sleepScore: "Sleep score \(Int(target))"
        case .screenMinutes: "\(Int(target)) min on chosen apps"
        }
    }

    func reading(_ value: Double) -> String {
        switch self {
        case .steps: Int(value).formatted()
        case .runKm, .sleepHours: value.formatted(.number.precision(.fractionLength(1)))
        case .focusMinutes, .activeCalories, .restingHeartRate, .hrv, .vo2Max, .bodyBattery, .stress, .sleepScore, .screenMinutes: "\(Int(value))"
        }
    }

    var unit: String {
        switch self {
        case .steps: "steps"
        case .runKm: "km"
        case .focusMinutes: "min"
        case .sleepHours: "h"
        case .activeCalories: "kcal"
        case .restingHeartRate: "bpm"
        case .hrv: "ms"
        case .vo2Max: "ml/kg/min"
        case .bodyBattery, .stress, .sleepScore: "/100"
        case .screenMinutes: "min"
        }
    }
}

/// How far a quest with a Health target has got, from the last sync.
struct GoalProgress: View {
    let quest: Quest
    @Environment(QuestEngine.self) private var engine

    var body: some View {
        if let raw = quest.signalKey, let key = SignalKey(rawValue: raw), let target = quest.target {
            let now = quest.isDone ? target : (engine.readings[key] ?? 0)
            VStack(spacing: 6) {
                SystemLine("Goal: \(key.goal(target))", size: 16)
                MeterBar(value: min(now / target, 1), tint: .white, segments: 0)
                Text("\(key.reading(now)) / \(key.reading(target)) \(key.unit) · from Apple Health")
                    .font(.text(13, weight: .medium)).opacity(0.85)
            }
        }
    }
}

/// Every quest opens in one of these: what it is, how hard, what it pays,
/// when it is due, and what happens if you miss it.
struct QuestInfoWindow: View {
    let quest: Quest
    let player: Player
    let todays: [Quest]
    @Query private var arcs: [Arc]

    /// Objectives of other arcs this quest also counts toward.
    private var sharedObjectives: [Objective] {
        arcs.sharedObjectives(for: quest.title, home: quest.arc, on: quest.scheduledAt)
    }
    let close: () -> Void

    @Environment(QuestEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @State private var newStep = ""

    private var tint: Color { quest.isRecovery ? Ink.shu : Ink.ai }

    var body: some View {
        ZStack {
            // Nearly opaque: the window itself is translucent, so the screen
            // behind must not show through it.
            Ink.deep.opacity(0.96).ignoresSafeArea()
                .onTapGesture(perform: close)
            ScrollView {
                VStack(spacing: 14) {
                    window
                    if quest.isOpen { options }
                    if quest.isOpen && quest.parent == nil && !quest.isRecovery { steps }
                }
                .padding(.horizontal, 22)
                .padding(.top, 60)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            // Pinned under the scrolling part, so the buttons are always in
            // reach however long the window is.
            .safeAreaInset(edge: .bottom) { actions }
        }
        .foregroundStyle(Ink.washi)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button("Close", action: close)
                .buttonStyle(SystemButtonStyle(tint: tint))
            if quest.isOpen && quest.source == .manual {
                Button(quest.isBlocked ? "Steps first" : "Complete") {
                    withAnimation(.snappy) { engine.complete(quest, player: player) }
                    close()
                }
                .buttonStyle(SystemButtonStyle(tint: tint, filled: true))
                .disabled(quest.isBlocked)
            }
            if quest.isDone {
                // Ticked by mistake: open it again and take back what it paid.
                Button("Not done") {
                    withAnimation(.snappy) { engine.untick(quest, player: player) }
                }
                .buttonStyle(SystemButtonStyle(tint: tint))
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Ink.deep.opacity(0.96).ignoresSafeArea())
    }

    private var window: some View {
        SystemWindow(title: quest.isRecovery ? "Recovery quest" : "Quest info", tint: tint, onClose: close) {
            Text(quest.title.uppercased()).font(.hud(30))
            HStack(spacing: 10) {
                RankBadge(rank: quest.rank, size: 32)
                Text("RANK \(quest.rank.rawValue) · \(quest.rank.difficulty.uppercased())").font(.hud(16, weight: .bold))
                GlyphIcon(quest.stat.glyph, size: 18, tint: .white)
                Text(quest.stat.title.uppercased()).font(.hud(16, weight: .bold))
            }
            GoalProgress(quest: quest)
            if quest.isRecovery {
                SystemLine("Clears the penalty", tint: .white)
            } else {
                VStack(spacing: 6) {
                    SystemLine("Reward", size: 15)
                    HStack(spacing: 16) {
                        reward(.star, "+\(Rewards.questXP(rank: quest.rank, statValue: player.value(for: quest.stat))) XP")
                        reward(.hourglass, "+\(quest.rank.earnedMinutes) min")
                        reward(quest.stat.glyph, "+\(quest.rank.statPoints)")
                    }
                }
            }
            Text("TIME LIMIT: \(quest.scheduledAt.clock) – \(quest.dueAt.clock)").font(.hud(15, weight: .semibold))
            ForEach(sharedObjectives) { objective in
                Text("ALSO COUNTS FOR \(objective.arc?.title.uppercased() ?? "") · \(objective.title.uppercased())")
                    .font(.hud(14, weight: .semibold)).opacity(0.85)
            }
            if quest.source != .manual && quest.source != .health {
                Text("FROM \(quest.source.name.uppercased())").font(.hud(14, weight: .semibold)).opacity(0.85)
            }
            if quest.isCritical && quest.isOpen {
                SystemLine("Failing this quest results in a penalty.", tint: Ink.shu, size: 15)
            }
            if quest.isDone { ClearStamp() }
            if quest.isFailed { SystemLine("Quest failed", tint: Ink.shu) }
        }
    }

    private func reward(_ glyph: Glyph, _ text: String) -> some View {
        HStack(spacing: 4) {
            GlyphIcon(glyph, size: 18, tint: .white)
            Text(text.uppercased()).font(.hud(16, weight: .bold))
        }
    }

    private var options: some View {
        VStack(spacing: 8) {
            if engine.alarms.isSupported {
                option(.alarm, "Alarm 10 min before", tint: Ink.ai, isOn: Binding(
                    get: { quest.alarmID != nil },
                    set: { on in Task { await engine.setAlarm(on, for: quest) } }
                ))
            }
            if !quest.isRecovery {
                option(.warning, "Must do today", tint: Ink.shu, isOn: Binding(
                    get: { quest.isCritical },
                    set: { on in withAnimation(.snappy) { engine.setMustDo(on, quest: quest, todays: todays) } }
                ))
            }
        }
    }

    /// The quest's steps, and a field to add one. Each step pays its own reward.
    private var steps: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(quest.orderedSubquests) { step in
                HStack(spacing: 10) {
                    GlyphIcon(step.isDone ? .check : .target, size: 16, tint: step.isDone ? Ink.ai : Ink.mute)
                    Text(step.title).font(.text(16)).strikethrough(step.isDone, color: Ink.mute)
                    Spacer()
                    Text("+\(step.rank.xp) XP").font(.number(13)).foregroundStyle(Ink.mute)
                }
            }
            HStack(spacing: 8) {
                TextField("", text: $newStep, prompt: Text("Add a step…").foregroundStyle(Ink.mute))
                    .font(.text(16))
                    .submitLabel(.done)
                    .onSubmit(addStep)
                Button("Add", action: addStep)
                    .font(.text(15, weight: .semibold))
                    .foregroundStyle(Ink.ai)
                    .disabled(newStep.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Ink.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func addStep() {
        withAnimation(.snappy) { engine.addStep(newStep, to: quest, context: context) }
        newStep = ""
    }

    private func option(_ glyph: Glyph, _ title: String, tint: Color, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 10) {
                GlyphIcon(glyph, size: 22, tint: tint)
                Text(title).font(.text(16, weight: .semibold))
            }
        }
        .tint(tint)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Ink.raised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
