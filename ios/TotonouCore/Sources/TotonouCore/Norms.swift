import Foundation

// Where you stand against other people: for each thing the app can measure,
// a table of population percentiles from published studies, so a number like
// "resting heart rate 58" becomes "better than 70% of men your age".
//
// The tables are for men aged 20 to 29 (the owner). Each one names its source;
// values marked estimated were interpolated where a study gives fewer points.
// Nothing here is your data: your numbers come from Health, Garmin, Screen
// Time and the lifts you enter yourself.

public struct Norm: Identifiable, Sendable, Equatable {
    public enum Group: String, Sendable, CaseIterable {
        case fitness = "Fitness"
        case heart = "Heart"
        case recovery = "Recovery"
        case strength = "Strength"
        case habits = "Habits"
    }

    public let id: String
    public let title: String
    public let unit: String
    public let group: Group
    /// The stat it says something about, for the overall score (Exercise 2).
    public let stat: Stat
    /// False for things where less is better (resting heart rate, screen time).
    public let higherIsBetter: Bool
    /// The value at the 10th, 25th, 50th, 75th, 90th and 99th percentile, in
    /// that order: "better than 10 people in 100" first. For lower-is-better
    /// norms the numbers fall along the list.
    public let points: [Double]
    /// World-class level, when it means something (an elite endurance athlete).
    public let elite: Double?
    /// Bryan Johnson's publicly reported value, when there is one.
    public let bryanJohnson: Double?
    public let source: String
    /// True when part of the table was interpolated rather than published.
    public let estimated: Bool

    public init(id: String, title: String, unit: String, group: Group, stat: Stat = .vitality, higherIsBetter: Bool = true,
                points: [Double], elite: Double? = nil, bryanJohnson: Double? = nil, source: String,
                estimated: Bool = false) {
        self.id = id
        self.title = title
        self.unit = unit
        self.group = group
        self.stat = stat
        self.higherIsBetter = higherIsBetter
        self.points = points
        self.elite = elite
        self.bryanJohnson = bryanJohnson
        self.source = source
        self.estimated = estimated
    }

    /// The percentiles `points` stand for.
    public static let ranks: [Double] = [10, 25, 50, 75, 90, 99]

    /// How many people out of 100 you do better than, 0 to 100. Straight lines
    /// between the published points; below the 10th and above the 99th it
    /// tapers towards 0 and 100.
    public func percentile(of value: Double) -> Double {
        guard points.count == Self.ranks.count else { return 50 }
        // (value, rank) pairs sorted by value, so the search below can walk up.
        let pairs = zip(points, Self.ranks).sorted { $0.0 < $1.0 }
        // Past either end: carry on along the slope of the two nearest points,
        // stopping just short of 0 and 100 (nobody beats everyone).
        func extend(_ a: (Double, Double), _ b: (Double, Double)) -> Double {
            let slope = (b.1 - a.1) / max(b.0 - a.0, 0.0001)
            return min(max(a.1 + (value - a.0) * slope, 0.1), 99.9)
        }
        if value <= pairs[0].0 { return extend(pairs[0], pairs[1]) }
        if value >= pairs[pairs.count - 1].0 { return extend(pairs[pairs.count - 1], pairs[pairs.count - 2]) }
        for (low, high) in zip(pairs, pairs.dropFirst()) where value <= high.0 {
            let share = (value - low.0) / max(high.0 - low.0, 0.0001)
            return clamp(low.1 + share * (high.1 - low.1))
        }
        return 50
    }

    /// The value it takes to be better than `percentile` people in 100.
    public func value(atPercentile percentile: Double) -> Double {
        let pairs = Array(zip(Self.ranks, points))
        if percentile <= pairs[0].0 { return pairs[0].1 }
        for (low, high) in zip(pairs, pairs.dropFirst()) where percentile <= high.0 {
            let share = (percentile - low.0) / (high.0 - low.0)
            return low.1 + share * (high.1 - low.1)
        }
        return pairs[pairs.count - 1].1
    }

    public var median: Double { points[2] }
    /// Better than 99 people in 100.
    public var topOnePercent: Double { value(atPercentile: 99) }

    private func clamp(_ value: Double) -> Double { min(max(value, 0), 100) }

    /// As a `Benchmark`, the shape the overall score (Exercise 2) reads.
    public func benchmark(for value: Double, shown: String) -> Benchmark {
        Benchmark(id: id, title: title, value: shown, percentile: Int(percentile(of: value).rounded()), stat: stat)
    }
}
