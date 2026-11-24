import SwiftUI
import TotonouCore
import WidgetKit
#if canImport(AlarmKit)
import ActivityKit
import AlarmKit
#endif

// The next-quest widget: home screen (small, medium) and lock screen.
//
// EXERCISE 7 · 窓 · Make the widget real                    (WidgetKit)
//   Status: steps 1–3 handed over to Claude on 2026-11-24 (owner's choice):
//   1. App Group group.dev.totonou.app on both targets (Config/*.entitlements).
//   2. QuestEngine.publishWidget writes a WidgetSnapshot through the group's
//      UserDefaults and reloads the timelines (WidgetSnapshot.save()).
//   3. currentSnapshot() reads it back, and shows "No quests yet" before the
//      app has written anything (no sample data on a real screen).
//   4. Still yours, as a stretch: add a second widget (streak, or the word of
//      the day) and list it in the bundle below.

struct QuestEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct QuestProvider: TimelineProvider {
    private func currentSnapshot() -> WidgetSnapshot {
        WidgetSnapshot.load() ?? .empty()
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
        #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
            QuestAlarmActivity()
        }
        #endif
    }
}

#if canImport(AlarmKit)
/// What a snoozed quest alarm shows on the Lock Screen and in the Dynamic
/// Island while it counts down. AlarmKit draws the ringing alert itself, but a
/// countdown needs a Live Activity, and Live Activities live in a widget extension.
@available(iOS 26.0, *)
struct QuestAlarmActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<QuestAlarmData>.self) { context in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Snoozed").caption(Ink.ai, size: 13)
                    Text(context.attributes.metadata?.title ?? "Quest").font(.text(17, weight: .semibold))
                }
                Spacer()
                countdown(context.state).font(.number(28, weight: .bold))
            }
            .padding()
            .foregroundStyle(Ink.washi)
            .activityBackgroundTint(Ink.sumi)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.metadata?.title ?? "Quest").font(.text(15, weight: .semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdown(context.state).font(.number(20, weight: .bold))
                }
            } compactLeading: {
                Text("Quest").font(.text(12, weight: .semibold)).foregroundStyle(Ink.ai)
            } compactTrailing: {
                countdown(context.state).font(.number(13, weight: .semibold))
            } minimal: {
                countdown(context.state).font(.number(11, weight: .semibold))
            }
        }
    }

    @ViewBuilder
    private func countdown(_ state: AlarmPresentationState) -> some View {
        if case .countdown(let countdown) = state.mode {
            // A timer Text counts down by itself; the widget does not need to redraw.
            Text(timerInterval: Date.now...countdown.fireDate, countsDown: true).monospacedDigit()
        } else {
            Text("–")
        }
    }
}
#endif
