import SwiftData
import SwiftUI
import TotonouCore

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(QuestEngine.self) private var engine
    @Query(sort: \Quest.scheduledAt) private var allQuests: [Quest]
    @Query private var players: [Player]
    @Query(sort: \Arc.startDate, order: .reverse) private var arcs: [Arc]
    @State private var showShield = false
    @State private var showComposer = false
    /// The quest whose info window is open.
    @State private var selected: Quest?

    private var quests: [Quest] {
        allQuests.filter { Calendar.current.isDateInToday($0.scheduledAt) }
    }

    /// Recovery quests jump the queue.
    private var next: Quest? {
        quests.first { $0.isRecovery && $0.isOpen } ?? quests.first { $0.isOpen }
    }

    /// Everything still to do after the next quest, in time order.
    private var later: [Quest] { quests.filter { $0.isOpen && $0 !== next } }
    private var finished: [Quest] { quests.filter { !$0.isOpen } }
    private var locked: Bool { engine.isLocked(quests) }

    var body: some View {
        Screen {
            if let player = players.first {
                hero(player)
                if arcs.isEmpty {
                    firstArc
                } else {
                    if locked { penalty }
                    if let next {
                        nextQuest(next, player: player)
                    } else {
                        allClear
                    }
                    bank(player)
                    if !later.isEmpty { laterList }
                    if !finished.isEmpty {
                        DoneSection(quests: finished) { quest in
                            QuestRow(quest: quest, open: { select(quest) }, complete: { complete(quest, player) })
                        }
                    }
                }
            }
        }
        // Pull down to check Apple Health for quests that finished themselves.
        .refreshable {
            if let player = players.first { await engine.sync(quests: quests, player: player) }
        }
        .overlay { questWindow }
        .fullScreenCover(isPresented: $showShield) {
            ShieldView(quest: next, locked: locked)
        }
        .sheet(isPresented: $showComposer) { ArcComposer() }
        .task(id: quests.count) {
            engine.enforcePenalties(quests: quests, context: context)
        }
    }

    // MARK: Sections

    /// Who you are right now: character, level, progress to the next level, streak.
    private func hero(_ player: Player) -> some View {
        let progress = player.progress
        return HStack(spacing: 16) {
            HunterFigure(rank: Rank.forLevel(progress.level))
                .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 8) {
                Text("\(Date.now.greeting)、\(player.name)").caption(Ink.ai, size: 15)
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("Level").font(.text(30, weight: .bold))
                    RollingNumber(value: progress.level).font(.number(30, weight: .bold))
                }
                ProgressLine(value: progress.fraction)
                Text("\(progress.into) / \(progress.needed) XP").caption()
            }
            VStack(spacing: 4) {
                GlyphIcon(.flame, size: 24, tint: Ink.shu)
                RollingNumber(value: StreakCalculator.currentStreak(completionDays: player.completionDays, today: .now))
                    .font(.number(22))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Streak")
        }
    }

    /// Shown until the first arc exists. Without an arc there are no quests.
    private var firstArc: some View {
        SystemWindow(title: "Welcome, hunter") {
            Text("Write your first arc.").font(.text(22, weight: .bold))
            Text("Describe the next chapter of your life. Your daily quests come from it.")
                .caption(.white.opacity(0.85), size: 16)
            Button("Start an arc") { showComposer = true }
                .buttonStyle(SystemButtonStyle(tint: .white, filled: true))
        }
    }

    private var penalty: some View {
        SystemWindow(title: "Penalty", tint: Ink.shu) {
            Text("Finish the recovery quest to unlock everything.").font(.text(17, weight: .medium))
        }
    }

    private func nextQuest(_ quest: Quest, player: Player) -> some View {
        SystemWindow(title: quest.isRecovery ? "Recovery quest" : "Quest", tint: quest.isRecovery ? Ink.shu : Ink.ai) {
            Text(quest.title).font(.text(24, weight: .bold))
            Text("\(quest.scheduledAt.clock) · \(reward(quest))").caption(.white.opacity(0.85), size: 16)
            if quest.source == .manual {
                Button("Complete") { complete(quest, player) }
                    .buttonStyle(SystemButtonStyle(tint: .white, filled: true))
            } else {
                HStack(spacing: 8) {
                    GlyphIcon(quest.source.glyph, size: 18, tint: .white)
                    Text("Completes from \(quest.source.name)").font(.text(16, weight: .medium))
                }
            }
        }
        .onTapGesture { select(quest) }
    }

    private var allClear: some View {
        SystemWindow(title: "All clear") {
            Text(quests.isEmpty ? "No quests today." : "Every quest is done. Rest.")
                .font(.text(20, weight: .bold))
        }
    }

    private func bank(_ player: Player) -> some View {
        Button {
            showShield = true
        } label: {
            SystemPanel(tint: Ink.mute) {
                HStack(spacing: 12) {
                    GlyphIcon(.hourglass, size: 22, tint: Ink.washi)
                    Text("Screen time").font(.text(18, weight: .medium))
                    Spacer()
                    RollingNumber(value: player.bankedMinutes).font(.number(22))
                    Text("min").caption(size: 15)
                    GlyphIcon(.chevron, size: 14)
                }
            }
        }
        .buttonStyle(PressStyle())
    }

    private var laterList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text("Later today").font(.text(22, weight: .bold))
                Text("\(later.count)").font(.number(17)).foregroundStyle(Ink.mute)
            }
            ForEach(later) { quest in
                QuestRow(quest: quest, open: { select(quest) }) {
                    if let player = players.first { complete(quest, player) }
                }
            }
        }
    }

    /// The quest's details in a system window, over a dimmed screen.
    @ViewBuilder private var questWindow: some View {
        if let quest = selected {
            ZStack {
                Ink.deep.opacity(0.75).ignoresSafeArea()
                    .onTapGesture { withAnimation(.snappy) { selected = nil } }
                SystemWindow(title: "Quest info", tint: quest.isRecovery ? Ink.shu : Ink.ai) {
                    Text(quest.title).font(.text(24, weight: .bold))
                    VStack(spacing: 6) {
                        Text("Rank \(quest.rank.rawValue) · \(quest.stat.title)")
                        Text("Due \(quest.scheduledAt.clock)")
                        Text("Reward: \(reward(quest))")
                    }
                    .font(.text(17, weight: .medium))
                    if quest.isOpen, let player = players.first {
                        Button("Complete") {
                            complete(quest, player)
                            selected = nil
                        }
                        .buttonStyle(SystemButtonStyle(tint: .white, filled: true))
                    }
                    Button("Close") { withAnimation(.snappy) { selected = nil } }
                        .buttonStyle(SystemButtonStyle(tint: .white))
                }
                .padding(24)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
    }

    // MARK: Helpers

    private func reward(_ quest: Quest) -> String {
        quest.isRecovery ? "clears the penalty" : "+\(quest.rank.xp) XP · +\(quest.rank.earnedMinutes) min"
    }

    private func select(_ quest: Quest) {
        withAnimation(.spring(duration: 0.3, bounce: 0.3)) { selected = quest }
    }

    private func complete(_ quest: Quest, _ player: Player) {
        withAnimation(.snappy) { engine.complete(quest, player: player) }
    }
}

/// One line of the list: a tick box on the left, the quest, its rank on the right.
struct QuestRow: View {
    let quest: Quest
    let open: () -> Void
    let complete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            leading
            Button(action: open) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(quest.title)
                            .font(.text(18, weight: .medium))
                            .strikethrough(quest.isDone, color: Ink.mute)
                            .foregroundStyle(quest.isOpen ? Ink.washi : Ink.mute)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 6) {
                            Text(quest.scheduledAt.clock)
                            if quest.isCritical { Text("Critical").foregroundStyle(Ink.shu) }
                            if quest.isFailed { Text("Missed").foregroundStyle(Ink.shu) }
                        }
                        .caption()
                    }
                    Spacer(minLength: 8)
                    RankBadge(rank: quest.rank, size: 32, dimmed: !quest.isOpen)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
        }
        .padding(.vertical, 8)
        .sensoryFeedback(.success, trigger: quest.isDone)
    }

    @ViewBuilder private var leading: some View {
        if quest.isDone {
            Circle().fill(Ink.ai.opacity(0.25))
                .overlay(GlyphIcon(.check, size: 16, tint: Ink.ai))
                .frame(width: 30, height: 30)
                .frame(width: 44, height: 44)
        } else if quest.isFailed {
            Circle().strokeBorder(Ink.shu.opacity(0.6), lineWidth: 1.5)
                .frame(width: 30, height: 30)
                .frame(width: 44, height: 44)
        } else if quest.source == .manual {
            Button(action: complete) {
                Circle().strokeBorder(Ink.washi.opacity(0.7), lineWidth: 1.5)
                    .frame(width: 30, height: 30)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Complete \(quest.title)")
        } else {
            // This quest finishes itself; the icon says where the proof comes from.
            GlyphIcon(quest.source.glyph, size: 20, tint: Ink.ai)
                .frame(width: 44, height: 44)
                .accessibilityLabel("Completes from \(quest.source.name)")
        }
    }
}
