import SwiftData
import SwiftUI
import TotonouCore

/// The coach reads your real week and tells you what to do about it.
struct CoachView: View {
    @Environment(\.modelContext) private var context
    @Environment(QuestEngine.self) private var engine
    @Query(sort: \Quest.scheduledAt) private var quests: [Quest]
    @Query private var players: [Player]
    @Query(sort: \Arc.startDate, order: .reverse) private var arcs: [Arc]

    @State private var advice: String?
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
                let review = Coach.review(quests: quests, player: player, bosses: arcs.first?.bosses ?? [])
                if review.total == 0 {
                    SystemWindow(title: "Nothing to review yet") {
                        Text("Start an arc and finish a few quests. I read what you actually do.")
                            .font(.text(17, weight: .medium))
                    }
                } else {
                    say(review)
                    if advisor != nil { ask(review) }
                    numbers(review)
                    next(review)
                }
            }
        }
    }

    // MARK: Sections

    private func say(_ review: CoachReview) -> some View {
        SystemWindow(title: "Coach") {
            Text(isThinking ? "Thinking…" : advice ?? review.insights.first ?? "Keep going.")
                .font(.text(18, weight: .medium))
                .lineSpacing(3)
        }
        // Ask the on-device model once per visit. Without it, the window shows
        // the strongest finding from the numbers instead.
        .task {
            guard advice == nil else { return }
            await think(review, question: nil)
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

    private func numbers(_ review: CoachReview) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Last 7 days")
            HStack(alignment: .top) {
                figure("\(review.done)/\(review.total)", "Quests")
                Spacer()
                figure("\(review.xp)", "XP")
                Spacer()
                figure("\(review.missed)", "Missed")
            }
            ForEach(review.insights, id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Circle().fill(Ink.ai).frame(width: 6, height: 6).offset(y: -3)
                    Text(line).font(.text(17)).lineSpacing(3)
                }
            }
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
                            engine.add(suggestion.idea, arc: arcs.first, context: context)
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

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.number(28))
            Text(label).caption()
        }
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
        let answer = try? await advisor.advise(facts: review.facts, question: question)
        withAnimation(.snappy) {
            if let answer { advice = answer }
            isThinking = false
        }
    }
}
