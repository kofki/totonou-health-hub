import Charts
import SwiftData
import SwiftUI
import TotonouCore

/// What you enter yourself for the strength benchmarks. Nothing else in the
/// app knows your lifts, so these are the only numbers here that are typed in.
enum LiftRecord: String, CaseIterable, Identifiable {
    case age, bodyWeight, bench, squat, deadlift, pushUps, verticalJump, iq

    var id: String { rawValue }

    var title: String {
        switch self {
        case .age: "Age"
        case .bodyWeight: "Body weight"
        case .bench: "Bench press, 1 rep max"
        case .squat: "Back squat, 1 rep max"
        case .deadlift: "Deadlift, 1 rep max"
        case .pushUps: "Push-ups in one set"
        case .verticalJump: "Vertical jump"
        case .iq: "IQ, from a real test"
        }
    }

    var unit: String {
        switch self {
        case .age: "years"
        case .pushUps: "reps"
        case .verticalJump: "cm"
        case .iq: "points"
        default: "kg"
        }
    }
}

/// One of your numbers next to its norm.
struct Standing: Identifiable {
    let norm: Norm
    let value: Double
    /// How the value is written: "58 bpm", "1.3x body weight".
    let shown: String
    var id: String { norm.id }
    var percentile: Double { norm.percentile(of: value) }
    var athletePercentile: Double? { norm.athletePercentile(of: value) }
}

/// The Coach's benchmark section: where you stand against men your age, metric
/// by metric, and your character next to famous people's (guessed) ones.
struct BenchmarksSection: View {
    let player: Player
    let readings: [SignalKey: Double]

    @State private var averageSteps: Double?
    @State private var editingLifts = false
    @State private var showCharacter = false

    var body: some View {
        let standings = Self.standings(player: player, readings: readings, averageSteps: averageSteps)
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Benchmarks") {
                Text("vs men 20–29").caption(size: 15)
            }
            Picker("Show", selection: $showCharacter) {
                Text("Body").tag(false)
                Text("Character").tag(true)
            }
            .pickerStyle(.segmented)
            if let age = player.lifts[LiftRecord.age.rawValue], !(20...29).contains(Int(age)) {
                Text("These tables are for men 20–29; you entered \(Int(age)).").caption(Ink.shu, size: 14)
            }

            if showCharacter {
                CharacterComparison(mine: CharacterRating.ratings(standings.map { ($0.norm.stat, $0.percentile) }))
            } else if standings.isEmpty {
                Text("Connect Apple Health or Garmin, or add your lifts, to see where you stand.").caption(size: 15)
            } else {
                if let overall = BenchmarkScore.overall(standings.map { $0.norm.benchmark(for: $0.value, shown: $0.shown) }) {
                    // Exercise 2 turns all of these into one number.
                    Text("Overall: better than \(overall) in 100").font(.text(18, weight: .semibold))
                }
                overview(standings)
                ForEach(Norm.Group.allCases, id: \.self) { group in
                    let cards = standings.filter { $0.norm.group == group }
                    if !cards.isEmpty {
                        Text(group.rawValue.uppercased()).font(.hud(15, weight: .bold)).foregroundStyle(Ink.mute)
                            .padding(.top, 4)
                        ForEach(cards) { NormCard(standing: $0) }
                    }
                }
            }

            Button {
                editingLifts = true
            } label: {
                HStack(spacing: 8) {
                    GlyphIcon(.dumbbell, size: 16, tint: Ink.ai)
                    Text(player.lifts.isEmpty ? "Add your lifts and age" : "Update your lifts and age").caption(Ink.ai, size: 16)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(PressStyle())
            TestsRow(player: player)
            Text("No food benchmark yet: nothing records what you eat.").caption(size: 13)
        }
        .task { averageSteps = await HealthVitalsSource.averageSteps() }
        .sheet(isPresented: $editingLifts) { LiftsEditor(player: player) }
    }

    /// One bar per metric: how many men your age in 100 you beat. Swift Charts
    /// draws it from plain values; the colour is the stat each metric belongs to.
    private func overview(_ standings: [Standing]) -> some View {
        Chart(standings) { standing in
            BarMark(x: .value("Beats", standing.percentile), y: .value("Metric", standing.norm.title))
                .foregroundStyle(standing.norm.stat.tint)
                .annotation(position: .trailing) {
                    Text("\(Int(standing.percentile.rounded()))").font(.number(12)).foregroundStyle(Ink.mute)
                }
            RuleMark(x: .value("Average", 50))
                .foregroundStyle(Ink.faint)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .chartXScale(domain: 0...100)
        .chartXAxis { AxisMarks(values: [0, 50, 100]) }
        .frame(height: CGFloat(standings.count) * 32 + 30)
        .accessibilityLabel("How many men your age in 100 you do better than, per metric")
    }

    /// Your numbers that have a norm. Only what was measured or entered: a
    /// metric with no value is left out, never guessed.
    static func standings(player: Player, readings: [SignalKey: Double], averageSteps: Double?) -> [Standing] {
        var list: [Standing] = []
        func add(_ id: String, _ value: Double?, _ shown: (Double) -> String) {
            guard let value, value > 0, let norm = NormCatalog.norm(id) else { return }
            list.append(Standing(norm: norm, value: value, shown: shown(value)))
        }
        add("vo2Max", readings[.vo2Max]) { "\(Int($0.rounded())) ml/kg/min" }
        add("restingHeartRate", readings[.restingHeartRate]) { "\(Int($0.rounded())) bpm" }
        // Garmin reports overnight RMSSD, Apple Health SDNN: they have different norms.
        let garminHRV = UserDefaults.standard.bool(forKey: GarminSource.worksKey)
        add(garminHRV ? "hrvRMSSD" : "hrvSDNN", readings[.hrv]) { "\(Int($0.rounded())) ms" }
        add("steps", averageSteps) { "\(Int($0.rounded())) a day" }
        add("sleepHours", readings[.sleepHours]) { String(format: "%.1f h", $0) }
        add("sleepScore", readings[.sleepScore]) { "\(Int($0.rounded()))" }
        let history = ScreenTimeLock.usageHistory().map(\.minutes)
        if !history.isEmpty {
            add("screenMinutes", Double(history.reduce(0, +)) / Double(history.count)) { "\(Int($0.rounded())) min a day" }
        }
        // Lifts are compared as a multiple of body weight, as strength standards are.
        let weight = player.lifts[LiftRecord.bodyWeight.rawValue] ?? 0
        if weight > 0 {
            for lift in [LiftRecord.bench, .squat, .deadlift] {
                if let kg = player.lifts[lift.rawValue], kg > 0 {
                    add(lift.rawValue, kg / weight) { String(format: "%.2fx body weight (%.0f kg)", $0, kg) }
                }
            }
        }
        add("pushUps", player.lifts[LiftRecord.pushUps.rawValue]) { "\(Int($0)) reps" }
        add("verticalJump", player.lifts[LiftRecord.verticalJump.rawValue]) { "\(Int($0)) cm" }
        add("iq", player.lifts[LiftRecord.iq.rawValue]) { "\(Int($0))" }
        // The in-app tests (MindTests.swift).
        add("reactionMs", player.lifts[TestRecord.reaction.key]) { "\(Int($0)) ms" }
        add("digitSpan", player.lifts[TestRecord.memory.key]) { "\(Int($0)) digits" }
        // A reflection score of 0 is a real result, so it may not be skipped as "missing".
        if let score = player.lifts[TestRecord.reflection.key], let norm = NormCatalog.norm("reflection") {
            list.append(Standing(norm: norm, value: score, shown: "\(Int(score)) of 3"))
        }
        add("charismaScore", player.lifts[TestRecord.charisma.key]) { String(format: "%.1f of 5", $0) }
        return list
    }
}

/// One metric as a card: your number, a track against men your age, one
/// against athletes when there is a table, and the details folded away.
struct NormCard: View {
    let standing: Standing
    @State private var open = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let norm = standing.norm
        Button {
            withAnimation(reduceMotion ? nil : .snappy) { open.toggle() }
        } label: {
            SystemPanel {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(norm.title).font(.text(18, weight: .semibold))
                        Spacer()
                        Text(standing.shown).font(.number(17, weight: .bold))
                    }
                    TrackLine(label: "Men 20–29", percentile: standing.percentile, tint: norm.stat.tint,
                              johnson: norm.bryanJohnson.map(norm.percentile(of:)))
                    if let athletes = standing.athletePercentile {
                        TrackLine(label: "Athletes", percentile: athletes, tint: norm.stat.tint.opacity(0.6), johnson: nil)
                    }
                    if open { details(norm) }
                    HStack(spacing: 4) {
                        Text(open ? "Less" : "Details").caption(size: 13)
                        GlyphIcon(.chevron, size: 10, tint: Ink.mute).rotationEffect(.degrees(open ? -90 : 90))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(PressStyle())
        .accessibilityElement(children: .combine)
    }

    /// The reference numbers, one per line, so they read as a list.
    @ViewBuilder private func details(_ norm: Norm) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            fact("Average man, 20s", NormCard.format(norm.median))
            fact("Top 1%", NormCard.format(norm.topOnePercent))
            if let group = norm.athleteGroup { fact("Athletes", group) }
            if let world = norm.worldClass {
                fact("World class", NormCard.format(world) + (norm.worldClassBy.map { ", \($0)" } ?? ""))
            }
            if let johnson = norm.bryanJohnson { fact("Bryan Johnson", NormCard.format(johnson)) }
            fact("Source", norm.source + (norm.estimated ? " (partly estimated)" : ""))
        }
        .padding(.top, 2)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label).caption(size: 13).frame(width: 118, alignment: .leading)
            Text(value).font(.text(14)).foregroundStyle(Ink.washi).multilineTextAlignment(.leading)
        }
    }

    static func format(_ value: Double) -> String {
        if value >= 100 || value == value.rounded() { return "\(Int(value.rounded()))" }
        // Two decimals for small numbers (1.25x body weight), without trailing zeros.
        var text = String(format: value < 10 ? "%.2f" : "%.1f", value)
        while text.hasSuffix("0") { text.removeLast() }
        return text
    }
}

/// A label, a track and where you stand on it, on one line.
private struct TrackLine: View {
    let label: String
    let percentile: Double
    let tint: Color
    let johnson: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).caption(size: 13)
                Spacer()
                // Exercise 24 writes this label; until then, the plain share.
                Text(standingLabel(percentile: percentile) ?? "Beats \(Int(percentile.rounded()))%")
                    .font(.text(14, weight: .semibold)).foregroundStyle(tint)
            }
            NormTrack(percentile: percentile, tint: tint, johnson: johnson)
        }
    }
}

/// The track itself: 0 to 100 people, with markers.
private struct NormTrack: View {
    let percentile: Double
    let tint: Color
    /// Where Bryan Johnson stands on the same track, if he has a number.
    let johnson: Double?

    var body: some View {
        GeometryReader { proxy in
            let x = { (percentile: Double) -> CGFloat in proxy.size.width * percentile / 100 }
            ZStack(alignment: .leading) {
                Capsule().fill(Ink.faint).frame(height: 6)
                Capsule().fill(tint.opacity(0.85))
                    .frame(width: max(x(percentile), 6), height: 6)
                marker(at: x(50), label: "avg")
                marker(at: x(99), label: "top 1%")
                if let johnson { marker(at: x(johnson), label: "BJ") }
                Circle().fill(.white).frame(width: 12, height: 12)
                    .position(x: x(percentile), y: 3)
            }
        }
        .frame(height: 24)
    }

    private func marker(at x: CGFloat, label: String) -> some View {
        VStack(spacing: 2) {
            Rectangle().fill(Ink.mute).frame(width: 1.5, height: 10)
            Text(label).font(.number(9)).foregroundStyle(Ink.mute)
        }
        .position(x: x, y: 12)
    }
}

/// Enter your lifts and body weight. Empty fields are left out.
private struct LiftsEditor: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String] = [:]

    var body: some View {
        SheetFrame(title: "Your lifts") {
            Text("Your age, and your best recent numbers. Strength is compared as a multiple of body weight.")
                .caption(size: 15)
            ForEach(LiftRecord.allCases) { lift in
                HStack {
                    Text(lift.title).font(.text(16))
                    Spacer()
                    TextField("0", text: binding(lift))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.number(17))
                        .frame(width: 80)
                    Text(lift.unit).caption(size: 14).frame(width: 36, alignment: .leading)
                }
                .padding(.vertical, 4)
            }
            Button("Save") {
                var lifts: [String: Double] = [:]
                for (key, text) in values {
                    if let number = Double(text.replacingOccurrences(of: ",", with: ".")), number > 0 { lifts[key] = number }
                }
                player.lifts = lifts
                dismiss()
            }
            .buttonStyle(SystemButtonStyle(filled: true))
        }
        .onAppear {
            values = player.lifts.mapValues { NormCard.format($0) }
        }
    }

    private func binding(_ lift: LiftRecord) -> Binding<String> {
        Binding(get: { values[lift.rawValue] ?? "" }, set: { values[lift.rawValue] = $0 })
    }
}

/// Your seven stats as 0-100 ratings next to a famous person's guessed ones.
private struct CharacterComparison: View {
    /// Your ratings, from measured numbers; a stat with nothing measured is missing.
    let mine: [Stat: Int]
    @State private var other = FamousProfile.all[1]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Menu {
                ForEach(FamousProfile.all) { person in
                    Button("\(person.name), \(person.known)") { other = person }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("You vs \(other.name)").font(.text(18, weight: .semibold))
                    GlyphIcon(.chevron, size: 12, tint: Ink.ai).rotationEffect(.degrees(90))
                }
            }
            HStack(spacing: 14) {
                legend(.white, "You")
                legend(Ink.mute, other.name)
            }
            ForEach(Stat.allCases) { stat in row(stat) }
            Text("\(other.name)'s numbers are guesses for fun, not measurements. Yours come from your benchmarks; a stat shows – until a test or a number measures it (see Tests below).")
                .caption(size: 13)
        }
    }

    private func row(_ stat: Stat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                GlyphIcon(stat.glyph, size: 16, tint: stat.tint)
                Text(stat.title).font(.text(15, weight: .semibold))
                Spacer()
                Text(mine[stat].map(String.init) ?? "–").font(.number(15, weight: .bold))
                Text("/ \(other.ratings[stat] ?? 0)").font(.number(13)).foregroundStyle(Ink.mute)
            }
            bar(Double(mine[stat] ?? 0), tint: stat.tint)
            bar(Double(other.ratings[stat] ?? 0), tint: Ink.mute)
        }
    }

    private func bar(_ value: Double, tint: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Ink.faint)
                Capsule().fill(tint).frame(width: proxy.size.width * value / 100)
            }
        }
        .frame(height: 5)
    }

    private func legend(_ tint: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            Capsule().fill(tint).frame(width: 14, height: 5)
            Text(label).caption(size: 13)
        }
    }
}
