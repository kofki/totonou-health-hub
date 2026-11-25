import SwiftData
import SwiftUI
import TotonouCore

struct ArcsView: View {
    @Query(sort: \Arc.startDate, order: .reverse) private var arcs: [Arc]
    @State private var showComposer = false
    @State private var showBossComposer = false
    /// The arc whose detail sheet is open.
    @State private var selected: Arc?

    private var active: [Arc] { arcs.active() }
    private var finished: [Arc] { arcs.filter { !$0.isActive() } }

    var body: some View {
        Screen {
            HStack(alignment: .center) {
                Text("Arcs").font(.text(32, weight: .bold))
                Spacer()
                AddButton(title: "New arc") { showComposer = true }
            }

            if active.isEmpty {
                SystemWindow(title: arcs.isEmpty ? "No arc yet" : "No active arc") {
                    Text("An arc is a chapter of your life, in your own words. It sets your goals and your daily quests. You can run several at once.")
                        .font(.text(17, weight: .medium))
                    Button("Start an arc") { showComposer = true }
                        .buttonStyle(SystemButtonStyle(tint: .white, filled: true))
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(active) { arc in
                        Button { selected = arc } label: { ArcRow(arc: arc) }
                            .buttonStyle(PressStyle())
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader("Bosses") {
                        AddButton(title: "Boss") { showBossComposer = true }
                    }
                    // With several arcs running, each boss says which one it belongs to.
                    BossList(bosses: active.flatMap(\.bosses), showArc: active.count > 1)
                }
                everyDay
            }

            if !finished.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("Finished")
                    ForEach(finished) { arc in
                        Button { selected = arc } label: { FinishedArcRow(arc: arc) }
                            .buttonStyle(PressStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showComposer) { ArcComposer() }
        .sheet(isPresented: $showBossComposer) { BossComposer(arcs: active) }
        // .sheet(item:) opens when `selected` gets a value and hands that value
        // to the sheet, so one sheet serves every arc in the list.
        .sheet(item: $selected) { arc in ArcDetail(arc: arc) }
    }

    /// What all the active arcs put on Today, as one list.
    @ViewBuilder private var everyDay: some View {
        let plan = active.dailyPlan()
        if !plan.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Today's plan")
                // By position, not by title: two arcs may hold the same quest
                // until Exercise 16 removes the repeat.
                ForEach(Array(plan.enumerated()), id: \.offset) { _, idea in
                    PlanLine(idea: idea)
                }
            }
        }
    }
}

/// One active arc in the list: what kind it is and how far it has come. Kept
/// short so many arcs fit on one screen. Tap it for goals, plan and bosses.
private struct ArcRow: View {
    let arc: Arc

    var body: some View {
        let progress = arc.progress()
        SystemPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(arc.title).font(.text(20, weight: .bold)).multilineTextAlignment(.leading)
                    Spacer()
                    GlyphIcon(arc.kind.glyph, size: 14, tint: Ink.mute)
                    Text("\(arc.kind.name) · \(arc.dayLabel())").caption()
                }
                ProgressLine(value: arc.fraction())
                // Each objective's count for this day or week, so every target
                // shows from the list. Three at most, to keep cards short.
                ForEach(arc.orderedObjectives.prefix(3)) { objective in
                    HStack(spacing: 8) {
                        GlyphIcon(objective.isMet() ? .check : .target, size: 13,
                                  tint: objective.isMet() ? Rank.d.tint : Ink.mute)
                        Text(objective.title).font(.text(15)).lineLimit(1)
                        Spacer(minLength: 8)
                        Text(objective.label()).font(.number(14)).foregroundStyle(Ink.mute)
                    }
                    .accessibilityElement(children: .combine)
                }
                // Every number here is counted from your own quests, goals and bosses.
                HStack(spacing: 16) {
                    ArcFigure(glyph: .target, done: progress.goalsDone, total: progress.goals, label: "goals")
                    ArcFigure(glyph: .check, done: progress.questsDone, total: progress.questsDue, label: "quests")
                    if progress.tasks > 0 {
                        ArcFigure(glyph: .sword, done: progress.tasksDone, total: progress.tasks, label: "boss")
                    }
                    Spacer(minLength: 0)
                    GlyphIcon(.chevron, size: 14, tint: Ink.mute)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

/// "3/5 goals": one measured count on an arc's card.
private struct ArcFigure: View {
    let glyph: Glyph
    let done: Int
    let total: Int
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            GlyphIcon(glyph, size: 14, tint: Ink.ai)
            Text("\(done)/\(total)").font(.number(15))
            Text(label).caption()
        }
        .accessibilityElement(children: .combine)
    }
}

/// One daily quest of a plan: time, stat, title.
private struct PlanLine: View {
    let idea: QuestIdea

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(idea.clock).font(.number(16)).foregroundStyle(Ink.ai).frame(width: 80, alignment: .leading)
            GlyphIcon(idea.stat.glyph, size: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(idea.title).font(.text(17))
                Text([idea.daysLabel, idea.objective].compactMap { $0 }.joined(separator: " · ")).caption(size: 13)
            }
            Spacer()
        }
    }
}

private struct AddButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                GlyphIcon(.plus, size: 16, tint: Ink.ai)
                Text(title).caption(Ink.ai, size: 16)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

/// Everything about one arc: goals, daily plan, bosses, and the way to end it.
private struct ArcDetail: View {
    let arc: Arc
    @Environment(QuestEngine.self) private var engine
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showBossComposer = false
    @State private var confirmEnd = false
    @State private var confirmDelete = false

    var body: some View {
        SheetFrame(title: arc.title) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(arc.dayLabel()).font(.text(22, weight: .bold))
                        HStack(spacing: 6) {
                            GlyphIcon(arc.kind.glyph, size: 14, tint: Ink.mute)
                            Text(arc.isActive() ? arc.kind.name : arc.isCompleted ? "Completed" : "Ended early")
                                .caption(size: 15)
                        }
                    }
                    Spacer()
                    // Tap it. It gets back up.
                    Daruma(progress: arc.fraction()).frame(width: 88, height: 88)
                }
                ProgressLine(value: arc.fraction())
            }

            if !arc.objectives.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    SectionHeader("Objectives")
                    // Exercise 18 draws each row.
                    ForEach(arc.orderedObjectives) { objective in ObjectiveRow(objective: objective) }
                }
            }

            if !arc.goals.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    SectionHeader("Goals")
                    // Tick a goal when you reach it. An objective's bar is its goals.
                    ForEach(arc.goals, id: \.self) { goal in
                        Button {
                            withAnimation(.snappy) { engine.setGoal(goal, done: !arc.isDone(goal), arc: arc) }
                        } label: {
                            HStack(spacing: 12) {
                                CheckBox(isOn: arc.isDone(goal), tint: Ink.ai)
                                Text(goal).font(.text(17)).multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                        .disabled(!arc.isActive())
                    }
                }
            }

            measured

            if !arc.plan.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Plan")
                    ForEach(arc.plan) { idea in PlanLine(idea: idea) }
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                SectionHeader("Bosses") {
                    if arc.isActive() { AddButton(title: "Boss") { showBossComposer = true } }
                }
                BossList(bosses: arc.bosses, showArc: false)
            }

            if arc.isActive() {
                if arc.kind == .objective && arc.allGoalsDone {
                    // Every goal is ticked: this closes the arc as completed.
                    Button("Objective reached") { close() }
                        .buttonStyle(SystemButtonStyle(filled: true))
                }
                Button("End arc") { confirmEnd = true }
                    .buttonStyle(SystemButtonStyle(tint: Ink.shu))
            } else {
                Button("Restart arc") {
                    engine.restart(arc, context: context)
                    dismiss()
                }
                .buttonStyle(SystemButtonStyle(filled: true))
                Button("Delete arc") { confirmDelete = true }
                    .buttonStyle(SystemButtonStyle(tint: Ink.shu))
            }
        }
        // Deleting cannot be undone either.
        .confirmationDialog("Delete \(arc.title)?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete arc", role: .destructive) {
                engine.delete(arc, context: context)
                dismiss()
            }
        } message: {
            Text("The arc, its objectives and bosses are removed. Quests you finished and the XP they paid stay.")
        }
        .sheet(isPresented: $showBossComposer) { BossComposer(arcs: [arc]) }
        // Ending cannot be undone, so ask first.
        .confirmationDialog("End \(arc.title)?", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("End arc", role: .destructive) { close() }
        } message: {
            Text("Its unfinished quests leave Today. What you already did stays.")
        }
    }
}

extension ArcDetail {
    private func close() {
        engine.end(arc, context: context)
        dismiss()
    }

    /// What the database says about this arc so far.
    @ViewBuilder fileprivate var measured: some View {
        let progress = arc.progress()
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Progress")
            HStack(spacing: 16) {
                ArcFigure(glyph: .check, done: progress.questsDone, total: progress.questsDue, label: "quests")
                if progress.tasks > 0 {
                    ArcFigure(glyph: .sword, done: progress.tasksDone, total: progress.tasks, label: "boss tasks")
                }
            }
            if progress.questsDue == 0 {
                Text("No quest of this arc has come due yet.").caption(size: 15)
            }
        }
    }
}

/// The square tick used for goals and boss tasks.
private struct CheckBox: View {
    let isOn: Bool
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .strokeBorder(isOn ? tint : Ink.mute, lineWidth: 1.5)
            .background(isOn ? tint.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .frame(width: 24, height: 24)
            .overlay { if isOn { GlyphIcon(.check, size: 14, tint: tint) } }
    }
}

/// Bosses, soonest deadline first. Used for one arc and for all of them together.
private struct BossList: View {
    let bosses: [Boss]
    let showArc: Bool
    @Environment(QuestEngine.self) private var engine
    @Query private var players: [Player]

    var body: some View {
        if bosses.isEmpty {
            Text("A boss is a deadline. Its HP is the tasks you have left.").caption(size: 15)
        }
        ForEach(bosses.sorted { $0.deadline < $1.deadline }) { boss in
            BossCard(boss: boss, arcTitle: showArc ? boss.arc?.title : nil) { task in
                if let player = players.first {
                    withAnimation(.snappy) { engine.strike(task, player: player) }
                }
            }
        }
    }
}

private struct BossCard: View {
    let boss: Boss
    /// Shown under the name when bosses of several arcs share a list.
    var arcTitle: String?
    let strike: (BossTask) -> Void

    /// Counts hits landed in this session. Each new one plays the shake once.
    @State private var hits = 0

    var body: some View {
        SystemPanel(tint: Ink.shu) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    OniMask(hp: boss.hp)
                        .frame(width: 48, height: 48)
                        .modifier(Shake(animatableData: CGFloat(hits)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(boss.name).font(.text(20, weight: .semibold))
                        if !boss.isDefeated {
                            Text("\(boss.daysLeft) days left").caption(Ink.shu)
                        }
                        if let arcTitle { Text(arcTitle).caption() }
                    }
                    Spacer()
                    if boss.isDefeated { ClearStamp() }
                }
                HStack(spacing: 10) {
                    ProgressLine(value: boss.hp, tint: Ink.shu)
                    Text("\(boss.remaining)/\(boss.tasks.count)").font(.number(15)).foregroundStyle(Ink.mute)
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(boss.orderedTasks) { task in
                        Button {
                            strike(task)
                            withAnimation(.linear(duration: 0.4)) { hits += 1 }
                        } label: {
                            HStack(spacing: 12) {
                                CheckBox(isOn: task.isDone, tint: Ink.shu)
                                Text(task.title)
                                    .font(.text(17))
                                    .strikethrough(task.isDone, color: Ink.mute)
                                    .foregroundStyle(task.isDone ? Ink.mute : Ink.washi)
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressStyle())
                        .disabled(task.isDone)
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: hits)
    }
}

/// A sheet with the app's backdrop, a title and a Close button.
private struct SheetFrame<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Backdrop()
            Screen {
                HStack {
                    Text(title).font(.text(28, weight: .bold))
                    Spacer()
                    Button("Close") { dismiss() }.buttonStyle(.plain).caption(size: 16)
                }
                content
            }
        }
        .foregroundStyle(Ink.washi)
        .tint(Ink.ai)
        .preferredColorScheme(.dark)
    }
}

private struct Field: View {
    let prompt: String
    @Binding var text: String
    var size: CGFloat = 18
    var lines: ClosedRange<Int> = 1...1

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(Ink.mute), axis: .vertical)
                .font(.text(size, weight: size > 20 ? .semibold : .regular))
                .lineLimit(lines)
            Rectangle().fill(Ink.faint).frame(height: 1)
        }
    }
}

/// Write a chapter, let the planner turn it into goals and daily quests, then begin.
struct ArcComposer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var title = ""
    @State private var manifesto = ""
    @State private var draft: ArcDraft?
    @State private var isPlanning = false
    @State private var kind = ArcKind.seasonal
    @State private var sentToClaude = false
    @Environment(\.openURL) private var openURL

    private let planner = Planners.arc()

    var body: some View {
        SheetFrame(title: "New arc") {
            Field(prompt: "Name, e.g. Winter Arc", text: $title, size: 24)
            VStack(alignment: .leading, spacing: 8) {
                Picker("Kind", selection: $kind) {
                    ForEach(ArcKind.allCases, id: \.self) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(kind == .seasonal ? "Runs for 90 days." : "No end date. It runs until you reach it.")
                    .caption()
            }
            Field(prompt: "Who are you by the end of it? What changes?", text: $manifesto, lines: 4...10)

            if let draft {
                SystemWindow(title: "Your plan") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(draft.goals, id: \.self) { goal in
                            Text("• \(goal)").font(.text(17, weight: .semibold))
                        }
                        if !draft.objectives.isEmpty {
                            Rectangle().fill(.white.opacity(0.3)).frame(height: 1).padding(.vertical, 4)
                            ForEach(draft.objectives) { objective in
                                HStack {
                                    Text(objective.title).font(.text(17))
                                    Spacer()
                                    Text(objective.rate).font(.number(15))
                                }
                            }
                        }
                        Rectangle().fill(.white.opacity(0.3)).frame(height: 1).padding(.vertical, 4)
                        ForEach(draft.quests) { idea in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(idea.clock).font(.number(16)).frame(width: 80, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(idea.title).font(.text(17))
                                    Text(idea.daysLabel).font(.text(13)).opacity(0.7)
                                }
                                Spacer()
                            }
                        }
                    }
                    .multilineTextAlignment(.leading)
                }
                Text(draft.byAI ? "Written by AI." : "Written by simple keyword rules.")
                    .caption()
                Button("Begin arc") { begin(draft) }
                    .buttonStyle(SystemButtonStyle(filled: true))
                Button("Try again") { plan() }
                    .buttonStyle(SystemButtonStyle(tint: Ink.mute))
            } else {
                if isPlanning {
                    // The coach reads what you wrote.
                    CoachKitsune()
                        .frame(width: 64, height: 64)
                        .frame(maxWidth: .infinity)
                        .phaseAnimator([0.4, 1.0]) { fox, phase in
                            fox.opacity(phase)
                        } animation: { _ in
                            .easeInOut(duration: 0.7)
                        }
                }
                Button(isPlanning ? "Reading…" : "Make my plan") { plan() }
                    .buttonStyle(SystemButtonStyle(filled: true))
                    .disabled(isPlanning || title.isEmpty || manifesto.isEmpty)
                // Claude plans it with your whole game in view, through the
                // Totonou connector (Connect → Claude), on your Claude account.
                Button("Plan with Claude") { askClaude() }
                    .buttonStyle(SystemButtonStyle())
                    .disabled(isPlanning || title.isEmpty || manifesto.isEmpty)
                Text(sentToClaude
                     ? "Claude has your arc, and the request is also copied. The arc appears here when you come back."
                     : "Needs Claude connected: Connect → Claude.")
                    .caption()
            }
        }
    }

    /// Opens Claude with the arc written as a request. Claude reads the game
    /// with get_overview and creates the arc with create_arc; the app applies
    /// it when you come back (QuestEngine.applyClaudeChanges).
    private func askClaude() {
        let request = ClaudePrompt.newArc(title: title, kind: kind, manifesto: manifesto)
        UIPasteboard.general.string = request
        if let url = ClaudePrompt.url(for: request) { openURL(url) }
        sentToClaude = true
    }

    private func plan() {
        isPlanning = true
        draft = nil
        Task {
            let result = try? await planner.plan(title: title, manifesto: manifesto)
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                draft = result
                isPlanning = false
            }
        }
    }

    private func begin(_ draft: ArcDraft) {
        QuestPlanner.begin(title: title, manifesto: manifesto, draft: draft, kind: kind, context: context)
        dismiss()
    }
}

/// A deadline, broken into the tasks that will beat it.
private struct BossComposer: View {
    /// The arcs the boss can join. With more than one, the sheet asks which.
    let arcs: [Arc]
    @State private var arcIndex = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var days = 14
    @State private var tasks = ""

    private var lines: [String] {
        tasks.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        SheetFrame(title: "New boss") {
            Field(prompt: "Name, e.g. Algorithms final", text: $name, size: 24)
            if arcs.count > 1 {
                HStack {
                    Text("Arc").font(.text(18))
                    Spacer()
                    Picker("Arc", selection: $arcIndex) {
                        ForEach(arcs.indices, id: \.self) { Text(arcs[$0].title).tag($0) }
                    }
                }
            }
            Stepper(value: $days, in: 1...180) {
                Text("Due in \(days) days").font(.text(18))
            }
            Field(prompt: "Tasks, one per line", text: $tasks, lines: 4...12)
            Button("Add boss") { add() }
                .buttonStyle(SystemButtonStyle(tint: Ink.shu, filled: true))
                .disabled(name.isEmpty || lines.isEmpty || arcs.isEmpty)
        }
    }

    private func add() {
        guard arcs.indices.contains(arcIndex) else { return }
        let arc = arcs[arcIndex]
        let today = Calendar.current.startOfDay(for: .now)
        let boss = Boss(name: name, deadline: Calendar.current.date(byAdding: .day, value: days, to: today)!, arc: arc)
        context.insert(boss)
        for (index, title) in lines.enumerated() {
            let task = BossTask(title: title, order: index)
            task.boss = boss
            context.insert(task)
        }
        dismiss()
    }
}
