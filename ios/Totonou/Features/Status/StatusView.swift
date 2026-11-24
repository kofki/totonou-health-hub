import Charts
import SwiftData
import SwiftUI
import TotonouCore

struct StatusView: View {
    @Environment(QuestEngine.self) private var engine
    @Query private var players: [Player]
    @Query(sort: \Quest.scheduledAt) private var quests: [Quest]
    @Query(sort: \Arc.startDate, order: .reverse) private var arcs: [Arc]
    @State private var showHistory = false
    @State private var isRenaming = false
    @State private var newName = ""
    @AppStorage("soundsOn") private var soundsOn = true

    var body: some View {
        Screen {
            if let player = players.first {
                character(player)
                week(player)
                stats(player)
                WordOfDayCard(word: WordBook.word(for: .now))
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
        let days = Coach.review(quests: quests, player: player, bosses: []).days
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
                    Task { await engine.setReminders(on, quests: today, plan: arcs.first?.plan ?? []) }
                }
            ))
            SettingRow(glyph: .speaker, title: "Sounds", isOn: $soundsOn)
            backup
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
                HunterFigure(rank: rank).padding(26)
            }
            .frame(width: 220, height: 220)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Level").font(.text(36, weight: .bold))
                RollingNumber(value: progress.level).font(.number(36, weight: .bold))
            }
            Button {
                newName = player.name
                isRenaming = true
            } label: {
                Text("\(player.name) · \(rank.rawValue)-Rank · \(progress.into) / \(progress.needed) XP")
                    .caption(size: 15)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func stats(_ player: Player) -> some View {
        let values = Stat.allCases.map { player.value(for: $0) }
        let ceiling = Double(max(values.max() ?? 1, 1)) * 1.15
        return VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Stats")
            StatRadar(values: values.map { Double($0) / ceiling })
                .frame(maxWidth: 260)
                .frame(maxWidth: .infinity)
            ForEach(Stat.allCases) { stat in
                HStack(spacing: 12) {
                    GlyphIcon(stat.glyph, size: 20, tint: Ink.ai)
                    Text(stat.title).font(.text(17)).frame(width: 96, alignment: .leading)
                    ProgressLine(value: Double(player.value(for: stat)) / ceiling)
                    RollingNumber(value: player.value(for: stat)).font(.number(18)).frame(width: 36, alignment: .trailing)
                }
            }
        }
    }
}
