import SwiftData
import SwiftUI
import TotonouCore

struct ArcsView: View {
    @Environment(QuestEngine.self) private var engine
    @Query(sort: \Arc.startDate, order: .reverse) private var arcs: [Arc]
    @Query private var players: [Player]
    @State private var showComposer = false
    @State private var showBossComposer = false

    var body: some View {
        Screen {
            HStack(alignment: .center) {
                Text("Arcs").font(.text(32, weight: .bold))
                Spacer()
                addButton("New arc") { showComposer = true }
            }

            if let arc = arcs.first {
                arcCard(arc)
                plan(arc)
                bosses(arc)
                if arcs.count > 1 { earlier }
            } else {
                SystemWindow(title: "No arc yet") {
                    Text("An arc is a chapter of your life, in your own words. It sets your goals and your daily quests.")
                        .font(.text(17, weight: .medium))
                    Button("Start an arc") { showComposer = true }
                        .buttonStyle(SystemButtonStyle(tint: .white, filled: true))
                }
            }
        }
        .sheet(isPresented: $showComposer) { ArcComposer() }
        .sheet(isPresented: $showBossComposer) {
            if let arc = arcs.first { BossComposer(arc: arc) }
        }
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
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

    private func arcCard(_ arc: Arc) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(arc.title).font(.text(30, weight: .bold))
                    Text("Day \(arc.day()) of \(arc.totalDays)").caption(size: 15)
                }
                Spacer()
                // Tap it. It gets back up.
                Daruma(progress: Double(arc.day()) / Double(arc.totalDays))
                    .frame(width: 88, height: 88)
            }
            ProgressLine(value: Double(arc.day()) / Double(arc.totalDays))
            VStack(alignment: .leading, spacing: 12) {
                ForEach(arc.goals, id: \.self) { goal in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Circle().fill(Ink.ai).frame(width: 6, height: 6).offset(y: -3)
                        Text(goal).font(.text(17))
                    }
                }
            }
        }
    }

    /// The quests this arc puts on Today, every day.
    @ViewBuilder private func plan(_ arc: Arc) -> some View {
        if !arc.plan.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Every day")
                ForEach(arc.plan) { idea in
                    HStack(spacing: 12) {
                        Text(idea.clock).font(.number(16)).foregroundStyle(Ink.ai).frame(width: 52, alignment: .leading)
                        GlyphIcon(idea.stat.glyph, size: 18)
                        Text(idea.title).font(.text(17))
                        Spacer()
                    }
                }
            }
        }
    }

    private func bosses(_ arc: Arc) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Bosses") {
                addButton("Boss") { showBossComposer = true }
            }
            if arc.bosses.isEmpty {
                Text("A boss is a deadline. Its HP is the tasks you have left.").caption(size: 15)
            }
            ForEach(arc.bosses.sorted { $0.deadline < $1.deadline }) { boss in
                BossCard(boss: boss) { task in
                    if let player = players.first {
                        withAnimation(.snappy) { engine.strike(task, player: player) }
                    }
                }
            }
        }
    }

    private var earlier: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Earlier arcs")
            ForEach(arcs.dropFirst()) { arc in
                Text(arc.title).font(.text(17)).foregroundStyle(Ink.mute)
            }
        }
    }
}

private struct BossCard: View {
    let boss: Boss
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
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(task.isDone ? Ink.shu : Ink.mute, lineWidth: 1.5)
                                    .background(task.isDone ? Ink.shu.opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 6))
                                    .frame(width: 24, height: 24)
                                    .overlay { if task.isDone { GlyphIcon(.check, size: 14, tint: Ink.shu) } }
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
    @Query(sort: \Quest.scheduledAt) private var quests: [Quest]
    @State private var title = ""
    @State private var manifesto = ""
    @State private var draft: ArcDraft?
    @State private var isPlanning = false

    private let planner = Planners.arc()

    var body: some View {
        SheetFrame(title: "New arc") {
            Field(prompt: "Name, e.g. Winter Arc", text: $title, size: 24)
            Field(prompt: "Who are you by the end of it? What changes?", text: $manifesto, lines: 4...10)

            if let draft {
                SystemWindow(title: "Your plan") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(draft.goals, id: \.self) { goal in
                            Text("• \(goal)").font(.text(17, weight: .semibold))
                        }
                        Rectangle().fill(.white.opacity(0.3)).frame(height: 1).padding(.vertical, 4)
                        ForEach(draft.quests) { idea in
                            HStack(spacing: 10) {
                                Text(idea.clock).font(.number(16)).frame(width: 52, alignment: .leading)
                                Text(idea.title).font(.text(17))
                                Spacer()
                            }
                        }
                    }
                    .multilineTextAlignment(.leading)
                }
                Text(draft.byAI ? "Written by on-device AI." : "Written by simple keyword rules. Turn on Apple Intelligence for a real plan.")
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
            }
        }
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
        let todays = quests.filter { Calendar.current.isDateInToday($0.scheduledAt) }
        QuestPlanner.begin(title: title, manifesto: manifesto, draft: draft, todays: todays, context: context)
        dismiss()
    }
}

/// A deadline, broken into the tasks that will beat it.
private struct BossComposer: View {
    let arc: Arc
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
            Stepper(value: $days, in: 1...180) {
                Text("Due in \(days) days").font(.text(18))
            }
            Field(prompt: "Tasks, one per line", text: $tasks, lines: 4...12)
            Button("Add boss") { add() }
                .buttonStyle(SystemButtonStyle(tint: Ink.shu, filled: true))
                .disabled(name.isEmpty || lines.isEmpty)
        }
    }

    private func add() {
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
