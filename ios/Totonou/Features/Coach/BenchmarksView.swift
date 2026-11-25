import Charts
import SwiftData
import SwiftUI
import TotonouCore

/// What you enter yourself for the strength benchmarks. Nothing else in the
/// app knows your lifts, so these are the only numbers here that are typed in.
enum LiftRecord: String, CaseIterable, Identifiable {
    case bodyWeight, bench, squat, deadlift, pushUps

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bodyWeight: "Body weight"
        case .bench: "Bench press, 1 rep max"
        case .squat: "Back squat, 1 rep max"
        case .deadlift: "Deadlift, 1 rep max"
        case .pushUps: "Push-ups in one set"
        }
    }

    var unit: String { self == .pushUps ? "reps" : "kg" }
}

/// One of your numbers next to its norm.
struct Standing: Identifiable {
    let norm: Norm
    let value: Double
    /// How the value is written: "58 bpm", "1.3x body weight".
    let shown: String
    var id: String { norm.id }
    var percentile: Double { norm.percentile(of: value) }
}

/// The Coach's benchmark section: where you stand against other men your
/// age, metric by metric, with the top 1% and Bryan Johnson for reference.
struct BenchmarksSection: View {
    let player: Player
    let readings: [SignalKey: Double]

    @State private var averageSteps: Double?
    @State private var editingLifts = false

    var body: some View {
        let standings = Self.standings(player: player, readings: readings, averageSteps: averageSteps)
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Benchmarks") {
                Text("Men 20–29").caption(size: 15)
            }
            if standings.isEmpty {
                Text("Connect Apple Health or Garmin, or enter your lifts, to see where you stand.")
                    .caption(size: 15)
            } else {
                overview(standings)
                if let overall = BenchmarkScore.overall(standings.map { $0.norm.benchmark(for: $0.value, shown: $0.shown) }) {
                    // Exercise 2 turns all of these into one number.
                    Text("Overall: better than \(overall) in 100").font(.text(17, weight: .semibold))
                }
                ForEach(Norm.Group.allCases, id: \.self) { group in
                    let rows = standings.filter { $0.norm.group == group }
                    if !rows.isEmpty {
                        Text(group.rawValue).font(.text(18, weight: .bold)).padding(.top, 4)
                        ForEach(rows) { NormRow(standing: $0) }
                    }
                }
            }
            Button {
                editingLifts = true
            } label: {
                HStack(spacing: 8) {
                    GlyphIcon(.dumbbell, size: 16, tint: Ink.ai)
                    Text(player.lifts.isEmpty ? "Add your lifts" : "Update your lifts").caption(Ink.ai, size: 16)
                }
                .padding(.vertical, 6)
            }
            .buttonStyle(PressStyle())
            Text("Food: nothing records what you eat yet, so there is no food benchmark.").caption(size: 13)
        }
        .task { averageSteps = await HealthVitalsSource.averageSteps() }
        .sheet(isPresented: $editingLifts) { LiftsEditor(player: player) }
    }

    /// One bar per metric: how many people in 100 you beat. Swift Charts draws
    /// it from plain values; the colour is the stat each metric belongs to.
    private func overview(_ standings: [Standing]) -> some View {
        Chart(standings) { standing in
            BarMark(x: .value("Better than", standing.percentile), y: .value("Metric", standing.norm.title))
                .foregroundStyle(standing.norm.stat.tint)
                .annotation(position: .trailing) {
                    Text("\(Int(standing.percentile.rounded()))").font(.number(12)).foregroundStyle(Ink.mute)
                }
            RuleMark(x: .value("Median", 50))
                .foregroundStyle(Ink.faint)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .chartXScale(domain: 0...100)
        .chartXAxis { AxisMarks(values: [0, 50, 100]) }
        .frame(height: CGFloat(standings.count) * 30 + 30)
        .accessibilityLabel("How many people in 100 you do better than, per metric")
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
        return list
    }
}

/// One metric: your value, where you stand, and a track from the bottom to the
/// top of the population with the median, the top 1% and Bryan Johnson on it.
struct NormRow: View {
    let standing: Standing

    var body: some View {
        let norm = standing.norm
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(norm.title).font(.text(17, weight: .semibold))
                Spacer()
                Text(standing.shown).font(.number(15))
            }
            // Exercise 24 writes this label; until then, the plain count.
            Text(standingLabel(percentile: standing.percentile)
                 ?? "Better than \(Int(standing.percentile.rounded())) in 100")
                .caption(norm.stat.tint, size: 14)
            NormTrack(standing: standing)
            Text(reference(norm)).caption(size: 12)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    private func reference(_ norm: Norm) -> String {
        var parts = ["Median \(Self.format(norm.median))", "top 1% \(Self.format(norm.topOnePercent))"]
        if let johnson = norm.bryanJohnson { parts.append("Bryan Johnson \(Self.format(johnson))") }
        if let elite = norm.elite { parts.append("elite \(Self.format(elite))") }
        return parts.joined(separator: " · ") + (norm.estimated ? " · partly estimated" : "") + " · " + norm.source
    }

    static func format(_ value: Double) -> String {
        if value >= 100 || value == value.rounded() { return "\(Int(value.rounded()))" }
        // Two decimals for small numbers (1.25x body weight), without trailing zeros.
        var text = String(format: value < 10 ? "%.2f" : "%.1f", value)
        while text.hasSuffix("0") { text.removeLast() }
        return text
    }
}

/// The track itself: 0 to 100 people, with markers.
private struct NormTrack: View {
    let standing: Standing

    var body: some View {
        GeometryReader { proxy in
            let x = { (percentile: Double) -> CGFloat in proxy.size.width * percentile / 100 }
            ZStack(alignment: .leading) {
                Capsule().fill(Ink.faint).frame(height: 6)
                Capsule().fill(standing.norm.stat.tint.opacity(0.85))
                    .frame(width: max(x(standing.percentile), 6), height: 6)
                marker(at: x(50), label: "50")
                marker(at: x(99), label: "1%")
                if let johnson = standing.norm.bryanJohnson {
                    marker(at: x(standing.norm.percentile(of: johnson)), label: "BJ")
                }
                Circle().fill(.white).frame(width: 12, height: 12)
                    .position(x: x(standing.percentile), y: 3)
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
            Text("Your best recent numbers. Strength is compared as a multiple of body weight.")
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
            values = player.lifts.mapValues { NormRow.format($0) }
        }
    }

    private func binding(_ lift: LiftRecord) -> Binding<String> {
        Binding(get: { values[lift.rawValue] ?? "" }, set: { values[lift.rawValue] = $0 })
    }
}
