import Charts
import SwiftData
import SwiftUI
import TotonouCore

struct StatusView: View {
    @Environment(QuestEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Query private var players: [Player]
    @Query(sort: \Quest.scheduledAt) private var quests: [Quest]
    @Query(sort: \Arc.startDate, order: .reverse) private var arcs: [Arc]
    @State private var showHistory = false
    @State private var showConnect = false
    @State private var isRenaming = false
    @State private var newName = ""
    @State private var confirmReset = false
    @State private var isResetting = false
    @AppStorage("soundsOn") private var soundsOn = true
    @AppStorage(Push.enabledKey) private var claudeAlertsOn = false

    var body: some View {
        Screen {
            if let player = players.first {
                character(player)
                StatusWindow(player: player, arcs: arcs.active()) {
                    newName = player.name
                    isRenaming = true
                }
                CharacterProfile(player: player, quests: quests)
                skills(player)
                week(player)
                stats(player)
                Button { showConnect = true } label: {
                    HStack(spacing: 8) {
                        GlyphIcon(.sync, size: 18)
                        Text("Connections")
                    }
                }
                .buttonStyle(SystemButtonStyle(tint: Ink.ai))
                Button { showHistory = true } label: {
                    HStack(spacing: 8) {
                        GlyphIcon(.scroll, size: 18)
                        Text("Quest log")
                    }
                }
                .buttonStyle(SystemButtonStyle(tint: Ink.mute))
                settings
            }
        }
        .sheet(isPresented: $showHistory) { QuestHistoryView() }
        .sheet(isPresented: $showConnect) { ConnectView() }
        .alert("Your name", isPresented: $isRenaming) {
            TextField("Name", text: $newName)
            Button("Save") {
                if !newName.isEmpty { players.first?.name = newName }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// Quests finished on each of the last seven days.
    private func week(_ player: Player) -> some View {
        let days = Coach.review(quests: quests, player: player, arcs: []).days
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Last 7 days") {
                Text("\(days.map(\.done).reduce(0, +)) done").caption(size: 15)
            }
            // Swift Charts: describe each mark and what its x and y mean, and
            // the framework draws axes, scales and bars. The pale bar is what
            // was planned that day, the blue one what got done.
            Chart(days) { day in
                BarMark(x: .value("Day", day.label), y: .value("Planned", day.total), stacking: .unstacked)
                    .foregroundStyle(Ink.faint)
                    .cornerRadius(5)
                BarMark(x: .value("Day", day.label), y: .value("Done", day.done), stacking: .unstacked)
                    .foregroundStyle(Ink.ai)
                    .cornerRadius(5)
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(Ink.faint)
                    AxisValueLabel().foregroundStyle(Ink.mute)
                }
            }
            .chartXAxis {
                AxisMarks { _ in AxisValueLabel().foregroundStyle(Ink.mute) }
            }
            .frame(height: 170)
        }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Settings")
            SettingRow(glyph: .bell, title: "Quest reminders", isOn: Binding(
                get: { engine.remindersOn },
                set: { on in
                    let today = quests.filter { Calendar.current.isDateInToday($0.scheduledAt) }
                    Task { await engine.setReminders(on, quests: today, plan: arcs.dailyPlan(), player: players.first, arcs: Array(arcs)) }
                }
            ))
            SettingRow(glyph: .notice, title: "Daily nudges", isOn: Binding(
                get: { engine.dailyNudgesOn },
                set: { on in
                    let today = quests.filter { Calendar.current.isDateInToday($0.scheduledAt) }
                    Task { await engine.setNudges(daily: on, quests: today, player: players.first, arcs: Array(arcs)) }
                }
            ))
            SettingRow(glyph: .flame, title: "Streak and reward alerts", isOn: Binding(
                get: { engine.streakAlertsOn },
                set: { on in
                    let today = quests.filter { Calendar.current.isDateInToday($0.scheduledAt) }
                    Task { await engine.setNudges(streak: on, quests: today, player: players.first, arcs: Array(arcs)) }
                }
            ))
            SettingRow(glyph: .bell, title: "Claude and coach alerts", isOn: Binding(
                get: { claudeAlertsOn },
                set: { on in Task { if on { claudeAlertsOn = await Push.enable() } else { await Push.disable() } } }
            ))
            SettingRow(glyph: .speaker, title: "Sounds", isOn: $soundsOn)
            backup
            Button("Reset progress") { confirmReset = true }
                .buttonStyle(SystemButtonStyle(tint: Ink.shu))
                .disabled(isResetting)
                .padding(.top, 8)
                // It cannot be undone, so it asks first and says what goes.
                .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                    Button("Reset progress", role: .destructive) {
                        isResetting = true
                        Task {
                            await engine.resetProgress(context: context)
                            isResetting = false
                        }
                    }
                } message: {
                    Text("Level, XP, stats, streak, minutes, rewards and finished quests go back to zero, here and in the cloud. Your arcs, objectives and plans stay. This cannot be undone.")
                }
        }
    }

    private var backup: some View {
        let failed = if case .failed = engine.cloudState { true } else { false }
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            GlyphIcon(.cloud, size: 18, tint: failed ? Ink.shu : Ink.mute)
            Text(backupText).caption(failed ? Ink.shu : Ink.mute)
        }
    }

    private var backupText: String {
        switch engine.cloudState {
        case .local: "Saved on this device only"
        case .syncing: "Backing up…"
        case .synced(let date): "Backed up \(date.clock)"
        case .failed(let reason): "Backup failed: \(reason)"
        }
    }

    private func character(_ player: Player) -> some View {
        let progress = player.progress
        let rank = Rank.forLevel(progress.level)
        return VStack(spacing: 14) {
            ZStack {
                EnsoRing(progress: progress.fraction)
                HumanFigure(rank: rank).padding(26)
            }
            .frame(width: 200, height: 200)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    /// Every unique skill: unlocked ones with their level, locked ones hidden.
    private func skills(_ player: Player) -> some View {
        let facts = player.skillFacts()
        let unlocked = engine.skills.filter { $0.level(facts) > 0 }.count
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Skills") {
                Text("\(unlocked) of \(engine.skills.count)").caption(size: 15)
            }
            // Unlocked first, then by how close the rest are.
            ForEach(engine.skills.sorted {
                ($0.level(facts), $0.progress(facts)) > ($1.level(facts), $1.progress(facts))
            }) { skill in
                SkillRow(skill: skill, facts: facts)
            }
        }
    }

    private func stats(_ player: Player) -> some View {
        let values = Stat.allCases.map { player.value(for: $0) }
        let ceiling = Double(max(values.max() ?? 1, 1)) * 1.15
        return VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Stats")
            StatRadar(values: values.map { Double($0) / ceiling })
                .frame(maxWidth: 260)
                .frame(maxWidth: .infinity)
        }
    }
}
