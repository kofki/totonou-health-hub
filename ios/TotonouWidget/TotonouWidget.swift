import SwiftUI
import TotonouCore
import WidgetKit

// The next-quest widget: home screen (small, medium) and lock screen.
//
// EXERCISE 7 · 窓 · Make the widget real                    (WidgetKit)
//   Right now every entry is WidgetSnapshot.sample. To show live data:
//   1. Add the App Groups capability to BOTH targets with the same group id.
//   2. In the app, encode a WidgetSnapshot with JSONEncoder and write it to
//      UserDefaults(suiteName: "<your group id>") whenever a quest changes, then
//      call WidgetCenter.shared.reloadAllTimelines().
//   3. Here, decode it in `currentSnapshot()` and fall back to .sample.
//   4. Then add a second widget (streak, or the word of the day) and list it in
//      the bundle below.

struct QuestEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct QuestProvider: TimelineProvider {
    private func currentSnapshot() -> WidgetSnapshot {
        // TODO(you): Exercise 7, step 3.
        .sample
    }

    func placeholder(in context: Context) -> QuestEntry {
        QuestEntry(date: .now, snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuestEntry) -> Void) {
        completion(QuestEntry(date: .now, snapshot: currentSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuestEntry>) -> Void) {
        let entry = QuestEntry(date: .now, snapshot: currentSnapshot())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
    }
}

struct QuestWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuestEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("\(snapshot.questTime) \(snapshot.questTitle)")
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Next · \(snapshot.questTime)").font(.text(12, weight: .medium)).widgetAccentable()
                Text(snapshot.questTitle).font(.text(15, weight: .semibold)).lineLimit(1)
                Text("Level \(snapshot.level) · \(snapshot.streak) day streak").font(.text(12))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .systemMedium:
            HStack(alignment: .top, spacing: 18) {
                quest
                Rectangle().fill(Ink.faint).frame(width: 1)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Word").caption(size: 11)
                    Text(snapshot.word.word).font(.text(24, weight: .bold))
                    Text(snapshot.word.reading).caption(size: 11)
                    Spacer(minLength: 0)
                    Text(snapshot.word.meaning).caption(size: 12).lineLimit(2)
                }
                .frame(width: 96, alignment: .leading)
            }
        default:
            quest
        }
    }

    private var quest: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Next quest").caption(Ink.ai, size: 12)
                Spacer()
                Text(snapshot.questRank.rawValue).font(.number(14, weight: .bold)).foregroundStyle(snapshot.questRank.tint)
            }
            Text(snapshot.questTitle).font(.text(17, weight: .semibold)).lineLimit(3).minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.questTime).font(.number(15))
                Spacer()
                Text("Lv \(snapshot.level)").font(.number(15))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct NextQuestWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextQuest", provider: QuestProvider()) { entry in
            QuestWidgetView(entry: entry)
                .foregroundStyle(Ink.washi)
                .containerBackground(Ink.sumi, for: .widget)
        }
        .configurationDisplayName("Next Quest")
        .description("Your next quest, your streak, and a word.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct TotonouWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextQuestWidget()
    }
}
