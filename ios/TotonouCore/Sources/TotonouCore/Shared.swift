import Foundation

public struct JapaneseWord: Codable, Equatable, Sendable {
    public let word: String
    public let reading: String
    public let meaning: String

    public init(word: String, reading: String, meaning: String) {
        self.word = word
        self.reading = reading
        self.meaning = meaning
    }
}

public enum WordBook {
    public static let all: [JapaneseWord] = [
        .init(word: "整う", reading: "ととのう", meaning: "to be in order; body and mind aligned"),
        .init(word: "継続", reading: "けいぞく", meaning: "continuation; keeping at it"),
        .init(word: "鍛錬", reading: "たんれん", meaning: "forging; disciplined training"),
        .init(word: "一歩", reading: "いっぽ", meaning: "one step"),
        .init(word: "集中", reading: "しゅうちゅう", meaning: "concentration"),
        .init(word: "克己", reading: "こっき", meaning: "self-mastery"),
        .init(word: "初心", reading: "しょしん", meaning: "beginner's mind"),
        .init(word: "改善", reading: "かいぜん", meaning: "steady improvement"),
        .init(word: "静寂", reading: "せいじゃく", meaning: "stillness; silence"),
        .init(word: "覚醒", reading: "かくせい", meaning: "awakening"),
    ]

    /// Same word all day, a different one tomorrow.
    public static func word(for date: Date, calendar: Calendar = .current) -> JapaneseWord {
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        return all[day % all.count]
    }
}

/// What the widget shows. The app will eventually write this to a shared App Group
/// container and the widget will read it; for now the widget uses `.sample`.
public struct WidgetSnapshot: Codable, Sendable {
    public var questTitle: String
    public var questTime: String
    public var questRank: Rank
    public var streak: Int
    public var level: Int
    public var word: JapaneseWord

    public init(questTitle: String, questTime: String, questRank: Rank, streak: Int, level: Int, word: JapaneseWord) {
        self.questTitle = questTitle
        self.questTime = questTime
        self.questRank = questRank
        self.streak = streak
        self.level = level
        self.word = word
    }

    /// Shown before the app has written anything: no invented quest.
    public static func empty(on date: Date = .now) -> WidgetSnapshot {
        WidgetSnapshot(questTitle: "No quests yet", questTime: "", questRank: .e, streak: 0, level: 1,
                       word: WordBook.word(for: date))
    }

    /// The App Group both the app and the widget belong to (Config/*.entitlements).
    /// Its UserDefaults are a small store that both processes can read.
    public static let groupID = "group.dev.kenzo.totonou"
    private static let key = "widgetSnapshot"

    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults(suiteName: Self.groupID)?.set(data, forKey: Self.key)
    }

    public static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: groupID)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// For Xcode previews and the widget gallery placeholder only.
    public static let sample = WidgetSnapshot(
        questTitle: "Run 5 km · Zone 2",
        questTime: "17:30",
        questRank: .c,
        streak: 11,
        level: 7,
        word: WordBook.all[0]
    )
}
