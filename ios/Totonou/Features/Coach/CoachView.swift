import SwiftData
import SwiftUI
import TotonouCore

/// The coach reads your real week and tells you what to do about it.
struct CoachView: View {
    @Environment(\.modelContext) private var context
    @Environment(QuestEngine.self) private var engine
    @Environment(\.openURL) private var openURL
    @Query(sort: \Quest.scheduledAt) private var quests: [Quest]
    @Query private var players: [Player]
    @Query(sort: \Arc.startDate, order: .reverse) private var arcs: [Arc]

    @State private var advice: String?
    /// The latest advice Claude left through the MCP server (ClaudeChanges.swift).
    @AppStorage(ClaudeCoachNote.textKey) private var claudeNote = ""
    @AppStorage(ClaudeCoachNote.dateKey) private var claudeNoteDate = 0.0
    @State private var isThinking = false
    @State private var question = ""
    /// Titles of the suggestions already added, so each can be added once.
    @State private var added: Set<String> = []

    private let advisor = Coach.advisor()

    var body: some View {
        Screen {
            HStack(alignment: .center) {
                Text("Coach").font(.text(32, weight: .bold))
                Spacer()
                // Exercise 9 teaches it to blink.
                CoachKitsune().frame(width: 60, height: 60)
            }

            if let player = players.first {
                let review = Coach.review(quests: quests, player: player, arcs: arcs.active(),
                                          readings: engine.readings)
                if review.total == 0 {
                    SystemWindow(title: "Nothing to review yet") {
                        Text("Start an arc and finish a few quests. I read what you actually do.")
                            .font(.text(17, weight: .medium))
                    }
                } else {
                    // Top to bottom: what to do, the one-tap way to do it, then the evidence.
                    say(review)
                    if !review.suggestions.isEmpty { next(review) }
                    numbers(review)
                    if !review.insights.isEmpty { findings(review) }
                    saw(review)
                    if advisor != nil { ask(review) }
                    askClaude
                }
            }
        }
    }

    // MARK: Sections

    private func say(_ review: CoachReview) -> some View {
        SystemWindow(title: "Today") {
            Text(isThinking ? (advisor?.answersOnOpen == false ? "Asking Claude on your Mac…" : "Thinking…")
                 : advice ?? todaysClaudeNote ?? review.insights.first?.text ?? "Finish your next quest.")
                .font(.text(18, weight: .medium))
                .lineSpacing(3)
        }
        // Ask the model (on-device or cloud) once per visit. Without it, the window shows
        // the strongest finding from the numbers instead.
        .task {
            guard advice == nil else { return }
            if let relay = advisor as? ClaudeRelayAdvisor {
                // An answer that came in while you were away.
                advice = await relay.latestAnswerToday()
            } else {
                await think(review, question: nil)
            }
        }
    }

    private func ask(_ review: CoachReview) -> some View {
        HStack(spacing: 10) {
            TextField("", text: $question, prompt: Text("Ask the coach…").foregroundStyle(Ink.mute))
                .font(.text(17))
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(Ink.raised, in: RoundedRectangle(cornerRadius: Radius.control))
                .onSubmit { send(review) }
            Button("Ask") { send(review) }
                .buttonStyle(SystemButtonStyle(filled: true))
                .frame(width: 84)
                .disabled(question.isEmpty || isThinking)
        }
    }

    /// A longer talk with Claude in the Claude app, on your own account. Claude
    /// reads your game through the Totonou connector and can leave its advice
    /// here with set_coach_message.
    private var askClaude: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button("Ask Claude") {
                let request = ClaudePrompt.coach(question: question)
                UIPasteboard.general.string = request
                if let url = ClaudePrompt.url(for: request) { openURL(url) }
                question = ""
            }
            .buttonStyle(SystemButtonStyle())
            Text("Opens Claude with your question. Needs Connect → Claude.").caption()
        }
    }

    private func numbers(_ review: CoachReview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Last 7 days")
            HStack(alignment: .top) {
                figure(.check, "\(review.done)/\(review.total)", "Quests", Ink.ai)
                Spacer()
                figure(.flame, "\(review.streak)", "Streak", Ink.shu)
                Spacer()
                figure(.warning, "\(review.missed)", "Missed", review.missed > 0 ? Ink.shu : Ink.mute)
            }
        }
    }

    private func findings(_ review: CoachReview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Findings")
            ForEach(review.insights) { insight in
                HStack(alignment: .top, spacing: 12) {
                    GlyphIcon(glyph(insight.kind), size: 20, tint: Ink.ai)
                    Text(insight.text).font(.text(17)).lineSpacing(3)
                }
            }
        }
    }

    /// Exactly what the coach was given, so any advice can be checked.
    private func saw(_ review: CoachReview) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(review.facts, id: \.self) { Text($0).caption(size: 14) }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Text("What the coach saw").font(.text(16, weight: .semibold))
        }
        .tint(Ink.mute)
    }

    private func glyph(_ kind: CoachInsight.Kind) -> Glyph {
        switch kind {
        case .timing: .hourglass
        case .missed: .warning
        case .stats: .target
        case .boss: .sword
        case .health: .heart
        case .streak: .flame
        }
    }

    private func next(_ review: CoachReview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Do next")
            ForEach(review.suggestions) { suggestion in
                SystemPanel(tint: Ink.mute) {
                    HStack(spacing: 12) {
                        GlyphIcon(suggestion.idea.stat.glyph, size: 22, tint: Ink.ai)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(suggestion.title).font(.text(18, weight: .medium))
                            Text(suggestion.idea.title).caption()
                        }
                        Spacer()
                        Button(added.contains(suggestion.id) ? "Added" : "Add") {
                            engine.add(suggestion.idea, arc: arc(for: suggestion), context: context)
                            added.insert(suggestion.id)
                        }
                        .buttonStyle(SystemButtonStyle())
                        .frame(width: 90)
                        .disabled(added.contains(suggestion.id))
                    }
                }
            }
        }
    }

    private func figure(_ glyph: Glyph, _ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                GlyphIcon(glyph, size: 18, tint: tint)
                Text(value).font(.number(28))
            }
            Text(label).caption()
        }
    }

    /// A boss suggestion joins that boss's arc; anything else joins the newest active arc.
    private func arc(for suggestion: CoachSuggestion) -> Arc? {
        let active = arcs.active()
        let boss = active.flatMap(\.bosses).first { boss in
            boss.tasks.contains { $0.title == suggestion.idea.title }
        }
        return boss?.arc ?? active.first
    }

    /// Claude's note, only on the day it was written: yesterday's advice is stale.
    private var todaysClaudeNote: String? {
        guard !claudeNote.isEmpty, Calendar.current.isDateInToday(Date(timeIntervalSince1970: claudeNoteDate)) else { return nil }
        return claudeNote
    }

    // MARK: Thinking

    private func send(_ review: CoachReview) {
        let asked = question
        question = ""
        Task { await think(review, question: asked) }
    }

    private func think(_ review: CoachReview, question: String?) async {
        guard let advisor else { return }
        isThinking = true
        let answer: String?
        do {
            answer = try await advisor.advise(facts: review.factSheet, question: question)
        } catch {
            // The relay is the one that can be away; say so instead of failing quietly.
            answer = advisor.answersOnOpen ? nil
                : "No answer yet. Is your Mac on, with the coach relay running? The answer shows here when it comes."
        }
        withAnimation(.snappy) {
            if let answer { advice = answer }
            isThinking = false
        }
    }
}
