import Foundation
import TotonouCore

/// One quest the planner proposes: what, which stat it trains, and when.
struct QuestIdea: Sendable, Equatable, Identifiable, DailySlot {
    var title: String
    var stat: Stat
    var hour: Int
    var minute: Int = 0
    var minutes: Int = 15
    var rank: Rank = .d
    /// Title of the arc objective this quest counts toward, if any.
    var objective: String? = nil
    /// Days of the week it runs, 1 = Monday … 7 = Sunday. Empty means every day.
    var weekdays: Set<Int> = []

    var id: String { title }
    /// "3:00 PM", the same 12-hour style as `Date.clock`.
    var clock: String {
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return String(format: "%d:%02d %@", twelve, minute, hour < 12 ? "AM" : "PM")
    }

    /// Stored on the arc as one line of text, which keeps the database simple.
    /// The objective is a seventh field, left off when there is none, so lines
    /// saved before objectives existed still read back.
    var line: String {
        var parts = [title, stat.rawValue, "\(hour)", "\(minute)", "\(minutes)", rank.rawValue]
        if objective != nil || !weekdays.isEmpty {
            parts.append(objective ?? "")
            parts.append(weekdays.sorted().map(String.init).joined())
        }
        return parts.map { $0.replacingOccurrences(of: "|", with: "/") }.joined(separator: "|")
    }

    /// True on the days this quest is planned for.
    func runs(on date: Date) -> Bool {
        weekdays.isEmpty || weekdays.contains(Weekday.isoNumber(of: date))
    }

    /// "Mon Wed Fri", or "Every day".
    var daysLabel: String { Weekday.label(weekdays) }

    init(title: String, stat: Stat, hour: Int, minute: Int = 0, minutes: Int = 15, rank: Rank = .d,
         objective: String? = nil, weekdays: Set<Int> = []) {
        self.title = title
        self.stat = stat
        self.hour = min(max(hour, 5), 23)
        self.minute = min(max(minute, 0), 59)
        self.minutes = min(max(minutes, 0), 240)
        self.rank = rank
        self.objective = objective.flatMap { $0.isEmpty ? nil : $0 }
        self.weekdays = weekdays.filter { (1...7).contains($0) }
    }

    init?(line: String) {
        let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard (6...8).contains(parts.count), let stat = Stat(rawValue: parts[1]), let hour = Int(parts[2]),
              let minute = Int(parts[3]), let minutes = Int(parts[4]), let rank = Rank(rawValue: parts[5]) else { return nil }
        let days = parts.count == 8 ? Set(parts[7].compactMap { Int(String($0)) }) : []
        self.init(title: parts[0], stat: stat, hour: hour, minute: minute, minutes: minutes, rank: rank,
                  objective: parts.count >= 7 ? parts[6] : nil, weekdays: days)
    }
}

/// Days of the week as numbers, 1 = Monday … 7 = Sunday, whatever the phone's region.
enum Weekday {
    static let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    static func isoNumber(of date: Date) -> Int {
        // Calendar counts Sunday as 1; shift so Monday is 1 and Sunday is 7.
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    static func label(_ days: Set<Int>) -> String {
        if days.isEmpty || days.count == 7 { return "Every day" }
        if days == [1, 2, 3, 4, 5] { return "Weekdays" }
        return days.sorted().map { names[$0 - 1] }.joined(separator: " ")
    }
}

/// A measurable target the planner proposes, before it is saved as an `Objective`.
struct ObjectiveIdea: Sendable, Equatable, Identifiable {
    var title: String
    var period: ObjectivePeriod
    var target: Int
    var detail: String = ""

    var id: String { title }
    /// "4 a week", "3 a day", "12 in total".
    var rate: String { "\(target) \(period.rate)" }
}

/// What the planner hands back after reading your chapter.
struct ArcDraft: Sendable {
    var kanji: String
    var goals: [String]
    /// Measurable daily and weekly targets. Quests name the one they count toward.
    var objectives: [ObjectiveIdea] = []
    var quests: [QuestIdea]
    /// True when a language model wrote it (on the phone or in the cloud), false for the keyword rules.
    var byAI: Bool
}

/// Turns free text into goals and daily quests.
protocol ArcPlanner: Sendable {
    func plan(title: String, manifesto: String) async throws -> ArcDraft
}

enum Planners {
    /// The best planner this device has: Apple's on-device model where it is
    /// available, otherwise the cloud model, always with the keyword rules as a
    /// safety net.
    static func arc() -> any ArcPlanner {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), OnDeviceAI.isAvailable {
            return FallbackArcPlanner(first: OnDeviceArcPlanner(), then: RuleBasedArcPlanner())
        }
        #endif
        // Exercise 15: until `CloudArcPlanner` is written it throws, and the
        // fallback quietly uses the rules.
        if let backend = CloudAI.backend() {
            return FallbackArcPlanner(first: CloudArcPlanner(backend: backend), then: RuleBasedArcPlanner())
        }
        return RuleBasedArcPlanner()
    }
}

/// Tries one planner and, if it throws, quietly uses another.
struct FallbackArcPlanner: ArcPlanner {
    let first: any ArcPlanner
    let then: any ArcPlanner

    func plan(title: String, manifesto: String) async throws -> ArcDraft {
        do { return try await first.plan(title: title, manifesto: manifesto) }
        catch { return try await then.plan(title: title, manifesto: manifesto) }
    }
}

/// Reads keywords. No intelligence, but it always works, offline and instantly.
struct RuleBasedArcPlanner: ArcPlanner {
    func plan(title: String, manifesto: String) async throws -> ArcDraft {
        try await Task.sleep(for: .seconds(0.8))
        let text = (title + " " + manifesto).lowercased()
        func mentions(_ words: String...) -> Bool { words.contains { text.contains($0) } }

        var goals: [String] = []
        var objectives: [ObjectiveIdea] = []
        var quests: [QuestIdea] = []
        let weekdays: Set<Int> = [1, 2, 3, 4, 5]

        // Each block: one outcome in words, the counts that get there, and the
        // quests that count toward them, on the days they happen.
        if mentions("gym", "lift", "strong", "muscle", "lean", "fat", "weight", "body", "health") {
            goals.append("Add 10 kg to your squat")
            objectives += [ObjectiveIdea(title: "Strength sessions", period: .week, target: 4,
                                         detail: "45 min, compound lifts first, log the weights"),
                           ObjectiveIdea(title: "Protein meals", period: .day, target: 3, detail: "30 g of protein or more")]
            quests += [QuestIdea(title: "Strength session: lower body", stat: .strength, hour: 18, minutes: 45, rank: .c,
                                 objective: "Strength sessions", weekdays: [1, 4]),
                       QuestIdea(title: "Strength session: upper body", stat: .strength, hour: 18, minutes: 45, rank: .c,
                                 objective: "Strength sessions", weekdays: [2, 6]),
                       QuestIdea(title: "Protein breakfast, 30 g", stat: .recovery, hour: 8, minutes: 10, rank: .e,
                                 objective: "Protein meals"),
                       QuestIdea(title: "Protein lunch, 30 g", stat: .recovery, hour: 13, minutes: 10, rank: .e,
                                 objective: "Protein meals"),
                       QuestIdea(title: "Protein dinner, 30 g", stat: .recovery, hour: 19, minute: 30, minutes: 10, rank: .e,
                                 objective: "Protein meals")]
        }
        if mentions("run", "cardio", "5k", "10k", "endurance", "marathon") {
            goals.append("5 km under 25:00")
            objectives.append(ObjectiveIdea(title: "Runs", period: .week, target: 3, detail: "Two easy, one with intervals"))
            quests += [QuestIdea(title: "Run 5 km easy", stat: .endurance, hour: 7, minutes: 35, rank: .c,
                                 objective: "Runs", weekdays: [2, 7]),
                       QuestIdea(title: "Run 6 x 400 m intervals", stat: .endurance, hour: 7, minutes: 40, rank: .b,
                                 objective: "Runs", weekdays: [5])]
        }
        if mentions("study", "exam", "school", "learn", "course", "work", "code", "read", "career", "professional", "job") {
            goals.append("Finish one real project you can show")
            objectives.append(ObjectiveIdea(title: "Deep-work blocks", period: .week, target: 5,
                                            detail: "90 min, phone in another room, one task named in advance"))
            quests += [QuestIdea(title: "Name tomorrow's one task", stat: .discipline, hour: 21, minutes: 5, rank: .e,
                                 weekdays: [7, 1, 2, 3, 4]),
                       QuestIdea(title: "Deep work, 90 min", stat: .intellect, hour: 9, minutes: 90, rank: .b,
                                 objective: "Deep-work blocks", weekdays: weekdays)]
        }
        if mentions("founder", "startup", "company", "business", "launch", "customer", "product") {
            goals.append("Ten paying customers")
            objectives += [ObjectiveIdea(title: "Customer conversations", period: .week, target: 5,
                                         detail: "A real call or meeting, notes written after"),
                           ObjectiveIdea(title: "Shipped changes", period: .week, target: 3, detail: "Live, not on a branch")]
            quests += [QuestIdea(title: "Reach out to 3 prospects", stat: .discipline, hour: 10, minutes: 20, rank: .d,
                                 weekdays: weekdays),
                       QuestIdea(title: "Customer call, notes after", stat: .intellect, hour: 14, minutes: 30, rank: .c,
                                 objective: "Customer conversations", weekdays: weekdays),
                       QuestIdea(title: "Ship one change", stat: .intellect, hour: 16, minutes: 60, rank: .b,
                                 objective: "Shipped changes", weekdays: [1, 3, 5])]
        }
        if mentions("social", "content", "post", "youtube", "tiktok", "instagram", "audience", "followers") {
            goals.append("1,000 followers who engage")
            objectives += [ObjectiveIdea(title: "Posts published", period: .week, target: 3),
                           ObjectiveIdea(title: "Replies to comments", period: .day, target: 1, detail: "Every comment from the last day")]
            quests += [QuestIdea(title: "Draft and publish a post", stat: .intellect, hour: 12, minutes: 45, rank: .c,
                                 objective: "Posts published", weekdays: [1, 3, 5]),
                       QuestIdea(title: "Reply to every comment", stat: .discipline, hour: 18, minutes: 15, rank: .e,
                                 objective: "Replies to comments")]
        }
        if mentions("sleep", "rest", "tired", "energy") {
            goals.append("Wake up rested without an alarm")
            objectives.append(ObjectiveIdea(title: "Nights in bed by 23:00", period: .week, target: 6))
            quests.append(QuestIdea(title: "Screens off, in bed by 23:00", stat: .recovery, hour: 22, minute: 30, minutes: 30,
                                    objective: "Nights in bed by 23:00"))
        }
        if mentions("phone", "scroll", "screen", "distract") {
            goals.append("Screen time under two hours a day")
            objectives.append(ObjectiveIdea(title: "Phone-free mornings", period: .week, target: 5,
                                            detail: "No phone for the first hour"))
            quests.append(QuestIdea(title: "No phone for the first hour", stat: .discipline, hour: 7, minutes: 60, rank: .d,
                                    objective: "Phone-free mornings"))
        }
        if goals.isEmpty {
            goals = ["Make this chapter count: name the outcome"]
            objectives = [ObjectiveIdea(title: "Hard things done", period: .week, target: 5,
                                        detail: "The task you would rather avoid, done before noon")]
            quests = [QuestIdea(title: "One hard thing before noon", stat: .discipline, hour: 9, minutes: 45, rank: .c,
                                objective: "Hard things done", weekdays: weekdays),
                      QuestIdea(title: "Walk 20 min", stat: .endurance, hour: 13, minutes: 20, rank: .e),
                      QuestIdea(title: "Evening review: what moved", stat: .discipline, hour: 21, minutes: 5, rank: .e)]
        }
        return ArcDraft(kanji: "道", goals: goals, objectives: objectives, quests: quests, byAI: false)
    }
}

extension Stat {
    /// A best guess from loose text, for anything a language model returns.
    init(loose text: String) {
        let text = text.lowercased()
        self = Stat.allCases.first { text.contains($0.rawValue) } ?? .discipline
    }
}
