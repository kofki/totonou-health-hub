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
    @State private var showConnect = false
    /// The quest whose info window is open.
    @State private var selected: Quest?
    /// Today's calendar events, read when the screen appears and on refresh.
    @State private var events: [CalendarEventInfo] = []

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
                    dayList
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
            if let player = players.first {
                await engine.importReminders(context: context, player: player)
                await engine.sync(quests: quests, player: player)
            }
            events = engine.day.events(on: .now)
        }
        .task { events = engine.day.events(on: .now) }
        .overlay { questWindow }
        .fullScreenCover(isPresented: $showShield) {
            ShieldView(quest: next, locked: locked)
        }
        .sheet(isPresented: $showComposer) { ArcComposer() }
        .sheet(isPresented: $showConnect, onDismiss: { events = engine.day.events(on: .now) }) { ConnectView() }
        .task(id: quests.count) {
            engine.enforcePenalties(quests: quests, context: context)
        }
    }

    // MARK: Sections

    /// Who you are right now: character, level, progress to the next level, streak.
    private func hero(_ player: Player) -> some View {
        let progress = player.progress
        return HStack(spacing: 16) {
            HumanFigure(rank: Rank.forLevel(progress.level))
                .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 8) {
                Text("\(Date.now.greeting), \(player.name)").caption(Ink.ai, size: 15)
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("Level").font(.text(30, weight: .bold))
                    RollingNumber(value: progress.level).font(.number(30, weight: .bold))
                }
                ProgressLine(value: progress.fraction)
                Text("\(progress.into) / \(progress.needed) XP").caption()
            }
            VStack(spacing: 4) {
                GlyphIcon(.flame, size: 24, tint: Ink.shu)
                RollingNumber(value: player.streak())
                    .font(.number(22))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Streak")
        }
    }

    /// Shown until the first arc exists. Without an arc there are no quests.
    private var firstArc: some View {
        SystemWindow(title: "Welcome, human") {
            Text("Write your first arc.").font(.text(22, weight: .bold))
            Text("Describe the next chapter of your life. Your daily quests come from it.")
                .caption(.white.opacity(0.85), size: 16)
            Button("Start an arc") { showComposer = true }
                .buttonStyle(SystemButtonStyle(tint: .white, filled: true))
        }
    }

    private var penalty: some View {
        SystemWindow(title: "Penalty", tint: Ink.shu, notice: true, leading: true) {
            (Text("A must-do quest was missed. You are in the ") + Text("penalty zone").foregroundStyle(Ink.shu)
                + Text(". Everything stays locked until the recovery quest is done."))
                .font(.text(17, weight: .medium))
        }
    }

    private func nextQuest(_ quest: Quest, player: Player) -> some View {
        SystemWindow(title: quest.isRecovery ? "Recovery quest" : "Next quest", tint: quest.isRecovery ? Ink.shu : Ink.ai) {
            Text(quest.title.uppercased()).font(.hud(28))
            HStack(spacing: 8) {
                RankBadge(rank: quest.rank, size: 30)
                Text(quest.scheduledAt.clock).font(.number(15, weight: .bold))
                if quest.isRecovery {
                    Text("Clears the penalty").font(.text(15, weight: .medium))
                } else {
                    QuestRewards(quest: quest, player: player)
                }
            }
            GoalProgress(quest: quest)
            if quest.isCritical { SystemLine("Must do today", tint: Ink.shu, size: 15) }
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

    /// Your calendar for today, with quests already on it hidden.
    @ViewBuilder private var dayList: some View {
        if !engine.day.hasCalendarAccess {
            Button { showConnect = true } label: {
                SystemPanel(glow: true) {
                    HStack(spacing: 12) {
                        GlyphIcon(.calendar, size: 24, tint: Ink.ai)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connect your life").font(.text(18, weight: .semibold))
                            Text("Calendar, Health, Reminders, Alarms").caption(size: 14)
                        }
                        Spacer()
                        GlyphIcon(.chevron, size: 14)
                    }
                }
            }
            .buttonStyle(PressStyle())
        } else {
            let questIDs = Set(quests.compactMap(\.externalID))
            let shown = events.filter { !questIDs.contains($0.id) }
            if !shown.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text("Your day").font(.text(22, weight: .bold))
                        Text("\(shown.count)").font(.number(17)).foregroundStyle(Ink.mute)
                    }
                    ForEach(shown) { event in
                        EventRow(event: event) {
                            withAnimation(.snappy) { engine.addQuest(from: event, context: context) }
                        }
                    }
                }
            }
        }
    }

    /// The quest's details in a system window, over a dimmed screen.
    @ViewBuilder private var questWindow: some View {
        if let quest = selected, let player = players.first {
            QuestInfoWindow(quest: quest, player: player, todays: quests) {
                withAnimation(.snappy) { selected = nil }
            }
            .transition(.scale(scale: 0.92).combined(with: .opacity))
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

/// A calendar event on Today. Events are context, not quests: they are muted,
/// and the + turns one into a quest.
struct EventRow: View {
    let event: CalendarEventInfo
    let makeQuest: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(event.isAllDay ? "All day" : event.start.clock)
                .font(.number(15)).foregroundStyle(Ink.mute)
                .frame(width: 52, alignment: .leading)
            Rectangle().fill(BusyFilter.isBusy(event) ? Ink.washi.opacity(0.4) : Ink.faint).frame(width: 3, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.text(17, weight: .medium)).foregroundStyle(Ink.mute)
                Text(event.calendarName).caption(size: 13)
            }
            Spacer(minLength: 8)
            Button(action: makeQuest) {
                GlyphIcon(.plus, size: 16, tint: Ink.ai)
                    .frame(width: 36, height: 36)
                    .background(Ink.ai.opacity(0.1), in: Circle())
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("Make \(event.title) a quest")
        }
        .padding(.vertical, 6)
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
                            if quest.isCritical { Text("Must do").foregroundStyle(Ink.shu) }
                            if quest.alarmID != nil { GlyphIcon(.alarm, size: 13, tint: Ink.ai) }
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
