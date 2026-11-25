import Foundation

// The character comparison on the Coach: your seven stats as 0-100 ratings
// next to famous people's. Their ratings are GUESSES, made up for fun from what
// is publicly known about them (a marathon record, a Nobel prize). They are not
// measurements and the app says so wherever they appear.

/// One famous person's guessed character sheet.
public struct FamousProfile: Identifiable, Sendable, Equatable {
    public let name: String
    /// Why they are here, in a few words.
    public let known: String
    /// 0 to 100 per stat. 50 is an average man in his twenties.
    public let ratings: [Stat: Int]
    public var id: String { name }

    public init(_ name: String, _ known: String, _ values: [Int]) {
        self.name = name
        self.known = known
        // In `Stat.allCases` order: STR AGI VIT INT WIS CHA WIL.
        self.ratings = Dictionary(uniqueKeysWithValues: zip(Stat.allCases, values))
    }

    public static let all: [FamousProfile] = [
        FamousProfile("Average man, 20s", "the middle of the pack", [50, 50, 50, 50, 50, 50, 50]),
        FamousProfile("Eliud Kipchoge", "marathon world record holder", [55, 80, 99, 70, 90, 75, 99]),
        FamousProfile("LeBron James", "basketball, 20+ seasons", [92, 92, 92, 75, 80, 90, 92]),
        FamousProfile("Cristiano Ronaldo", "football, trains at 40", [85, 95, 95, 65, 60, 85, 97]),
        FamousProfile("Simone Biles", "most decorated gymnast", [85, 100, 90, 70, 80, 85, 96]),
        FamousProfile("David Goggins", "ultra runner, ex-Navy SEAL", [85, 70, 92, 65, 75, 70, 100]),
        FamousProfile("Bryan Johnson", "longevity, Blueprint", [60, 55, 97, 85, 70, 55, 98]),
        FamousProfile("Albert Einstein", "physicist", [30, 25, 45, 99, 90, 75, 85]),
        FamousProfile("Marcus Aurelius", "Stoic emperor", [55, 50, 55, 85, 99, 80, 95]),
        FamousProfile("Oprah Winfrey", "interviewer, media", [25, 30, 50, 85, 88, 99, 85]),
    ]
}

/// Your ratings, 0 to 100 per stat, from measured numbers only: the average of
/// the percentiles that say something about that stat. A stat with no measure
/// yet (Intelligence has no test here) has no rating rather than a guess.
public enum CharacterRating {
    public static func ratings(_ percentiles: [(stat: Stat, percentile: Double)]) -> [Stat: Int] {
        var result: [Stat: Int] = [:]
        for stat in Stat.allCases {
            let values = percentiles.filter { $0.stat == stat }.map(\.percentile)
            guard !values.isEmpty else { continue }
            result[stat] = Int((values.reduce(0, +) / Double(values.count)).rounded())
        }
        return result
    }
}
