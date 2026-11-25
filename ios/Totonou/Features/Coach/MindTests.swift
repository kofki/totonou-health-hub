import SwiftUI
import TotonouCore

// Short tests that measure what Health and Garmin cannot: reaction time
// (Agility), digit memory (Intelligence), stopping to think (Wisdom) and a
// published charisma questionnaire (Charisma). Each saves one number into
// `Player.lifts`, under the keys in `TestRecord`, where the benchmarks read it.

enum TestRecord: String, CaseIterable, Identifiable {
    case reaction, memory, reflection, charisma

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reaction: "Reaction"
        case .memory: "Memory"
        case .reflection: "Reflection"
        case .charisma: "Charisma"
        }
    }

    /// The stat it measures.
    var stat: Stat {
        switch self {
        case .reaction: .agility
        case .memory: .intelligence
        case .reflection: .wisdom
        case .charisma: .charisma
        }
    }

    /// The key its result is saved under in `Player.lifts`.
    var key: String {
        switch self {
        case .reaction: "reactionMs"
        case .memory: "digitSpan"
        case .reflection: "reflection"
        case .charisma: "charismaScore"
        }
    }

    var minutes: String {
        switch self {
        case .reaction: "1 min"
        case .memory: "2 min"
        case .reflection: "2 min"
        case .charisma: "1 min"
        }
    }
}

/// The row of test buttons under the benchmarks.
struct TestsRow: View {
    let player: Player
    @State private var open: TestRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TESTS").font(.hud(15, weight: .bold)).foregroundStyle(Ink.mute)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                ForEach(TestRecord.allCases) { test in
                    Button { open = test } label: {
                        SystemPanel {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    GlyphIcon(test.stat.glyph, size: 16, tint: test.stat.tint)
                                    Text(test.title).font(.text(16, weight: .semibold))
                                }
                                Text(player.lifts[test.key].map { result(test, $0) } ?? "\(test.stat.title) · \(test.minutes)")
                                    .caption(size: 13)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .buttonStyle(PressStyle())
                }
            }
        }
        // .sheet(item:) opens when `open` gets a test and passes that test in.
        .sheet(item: $open) { test in
            switch test {
            case .reaction: ReactionTest(player: player)
            case .memory: MemoryTest(player: player)
            case .reflection: ReflectionTest(player: player)
            case .charisma: CharismaTest(player: player)
            }
        }
    }

    private func result(_ test: TestRecord, _ value: Double) -> String {
        switch test {
        case .reaction: "\(Int(value)) ms"
        case .memory: "\(Int(value)) digits"
        case .reflection: "\(Int(value)) of 3"
        case .charisma: String(format: "%.1f of 5", value)
        }
    }
}

// MARK: Reaction (Agility)

/// Tap as soon as the panel turns green, five times. The middle time counts,
/// so one lucky or sleepy tap does not decide it.
private struct ReactionTest: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss

    private enum Phase: Equatable { case ready, waiting, go(Date), early, done }
    @State private var phase = Phase.ready
    @State private var times: [Double] = []
    @State private var wait: Task<Void, Never>?

    private var result: Double? {
        guard times.count == 5 else { return nil }
        // Exercise 25 finds the middle time; until then, the average.
        return medianTime(times) ?? times.reduce(0, +) / Double(times.count)
    }

    var body: some View {
        SheetFrame(title: "Reaction") {
            Text("Tap the panel the moment it turns green. Five rounds.").caption(size: 15)
            Button(action: tap) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(color)
                    .frame(height: 260)
                    .overlay(Text(label).font(.text(22, weight: .bold)).foregroundStyle(.white))
            }
            .buttonStyle(.plain)
            Text("Round \(min(times.count + 1, 5)) of 5" + (times.isEmpty ? "" : " · " + times.map { "\(Int($0))" }.joined(separator: ", ") + " ms"))
                .caption(size: 14)
            if let result {
                Button("Save \(Int(result)) ms") {
                    player.lifts[TestRecord.reaction.key] = result.rounded()
                    dismiss()
                }
                .buttonStyle(SystemButtonStyle(filled: true))
            }
        }
        .onDisappear { wait?.cancel() }
    }

    private var color: Color {
        switch phase {
        case .go: Ink.jade
        case .early: Ink.shu
        default: Ink.raised
        }
    }

    private var label: String {
        switch phase {
        case .ready: times.count == 5 ? "Done" : "Tap to start"
        case .waiting: "Wait for green…"
        case .go: "Tap!"
        case .early: "Too soon. Tap to retry"
        case .done: "Done"
        }
    }

    private func tap() {
        switch phase {
        case .ready, .early:
            guard times.count < 5 else { return }
            phase = .waiting
            // A random wait, so the moment cannot be guessed.
            wait = Task {
                try? await Task.sleep(for: .milliseconds(Int.random(in: 1500...4000)))
                guard !Task.isCancelled else { return }
                phase = .go(.now)
            }
        case .waiting:
            wait?.cancel()
            phase = .early
        case .go(let start):
            times.append(Date.now.timeIntervalSince(start) * 1000)
            phase = times.count == 5 ? .done : .ready
        case .done:
            break
        }
    }
}

// MARK: Memory (Intelligence)

/// Forward digit span: digits appear one at a time; type them back. Each
/// right answer adds a digit; two misses at one length end the test.
private struct MemoryTest: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss

    @State private var length = 3
    @State private var digits: [Int] = []
    @State private var shown: Int?
    @State private var answer = ""
    @State private var showing = false
    @State private var misses = 0
    @State private var best = 0
    @State private var finished = false

    var body: some View {
        SheetFrame(title: "Memory") {
            Text("Digits appear one at a time. Type them back in order.").caption(size: 15)
            Text(showing ? (shown.map(String.init) ?? " ") : "\(length) digits")
                .font(.number(72, weight: .bold))
                .frame(maxWidth: .infinity, minHeight: 140)
            if finished {
                Text("Longest correct: \(best) digits").font(.text(20, weight: .semibold))
                Button("Save") {
                    player.lifts[TestRecord.memory.key] = Double(best)
                    dismiss()
                }
                .buttonStyle(SystemButtonStyle(filled: true))
            } else if digits.isEmpty || showing {
                Button("Show \(length) digits") { Task { await play() } }
                    .buttonStyle(SystemButtonStyle(filled: true))
                    .disabled(showing)
            } else {
                TextField("Type them", text: $answer)
                    .keyboardType(.numberPad)
                    .font(.number(28))
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(Ink.raised, in: RoundedRectangle(cornerRadius: 12))
                Button("Check") { check() }
                    .buttonStyle(SystemButtonStyle(filled: true))
                if misses > 0 { Text("Missed once at this length. One more try.").caption(Ink.shu, size: 14) }
            }
        }
    }

    private func play() async {
        digits = (0..<length).map { _ in Int.random(in: 0...9) }
        answer = ""
        showing = true
        for digit in digits {
            shown = digit
            try? await Task.sleep(for: .milliseconds(800))
            shown = nil
            try? await Task.sleep(for: .milliseconds(200))
        }
        showing = false
    }

    private func check() {
        if answer.filter(\.isNumber) == digits.map(String.init).joined() {
            best = length
            length += 1
            misses = 0
        } else {
            misses += 1
            if misses == 2 { finished = true }
        }
        digits = []
    }
}

// MARK: Reflection (Wisdom)

/// The Cognitive Reflection Test (Frederick, 2005): three questions whose
/// first answer is wrong. It measures stopping to think. Take it once: once
/// you know the answers, it measures nothing.
private struct ReflectionTest: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss
    @State private var answers = ["", "", ""]

    private let questions = [
        ("A bat and a ball cost $1.10 in total. The bat costs $1.00 more than the ball. How many cents does the ball cost?", "cents", 5.0),
        ("If it takes 5 machines 5 minutes to make 5 widgets, how many minutes would it take 100 machines to make 100 widgets?", "minutes", 5.0),
        ("In a lake there is a patch of lily pads. Every day it doubles in size. It takes 48 days to cover the lake. How many days to cover half of it?", "days", 47.0),
    ]

    var body: some View {
        SheetFrame(title: "Reflection") {
            Text("Three questions. Take your time: the first answer that comes to mind is usually wrong. Take it only once.")
                .caption(size: 15)
            ForEach(questions.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    Text(questions[index].0).font(.text(16))
                    HStack {
                        TextField("0", text: $answers[index])
                            .keyboardType(.numberPad)
                            .font(.number(20))
                            .frame(width: 90)
                            .padding(8)
                            .background(Ink.raised, in: RoundedRectangle(cornerRadius: 10))
                        Text(questions[index].1).caption(size: 14)
                    }
                }
                .padding(.vertical, 4)
            }
            Button("Save") {
                let score = zip(questions, answers).filter { Double($0.1) == $0.0.2 }.count
                player.lifts[TestRecord.reflection.key] = Double(score)
                dismiss()
            }
            .buttonStyle(SystemButtonStyle(filled: true))
            .disabled(answers.contains { $0.isEmpty })
        }
    }
}

// MARK: Charisma

/// The General Charisma Inventory (Tskhay, Zhu, Zou and Rule, 2018): six
/// statements, each rated 1 to 5. The score is their average.
private struct CharismaTest: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss
    @State private var ratings = [3, 3, 3, 3, 3, 3]

    private let items = [
        "Has a presence in a room", "Has the ability to influence people", "Knows how to lead a group",
        "Makes people feel comfortable", "Smiles at people often", "Can get along with anyone",
    ]

    var body: some View {
        SheetFrame(title: "Charisma") {
            Text("I am someone who… Rate each honestly: 1 strongly disagree, 5 strongly agree.").caption(size: 15)
            ForEach(items.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 6) {
                    Text(items[index]).font(.text(16))
                    Picker(items[index], selection: $ratings[index]) {
                        ForEach(1...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.vertical, 4)
            }
            Button("Save") {
                player.lifts[TestRecord.charisma.key] = Double(ratings.reduce(0, +)) / Double(ratings.count)
                dismiss()
            }
            .buttonStyle(SystemButtonStyle(filled: true))
        }
    }
}
