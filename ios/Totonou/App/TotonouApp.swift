import SwiftData
import SwiftUI
import TotonouCore
import UserNotifications

@main
struct TotonouApp: App {
    @State private var engine = QuestEngine(cloud: SupabaseConfig.makeStore())

    init() {
        UNUserNotificationCenter.current().delegate = ReminderPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(engine)
                .preferredColorScheme(.dark)
        }
        // One line gives every view below a database for these model types.
        .modelContainer(for: [Player.self, Quest.self, Arc.self, Boss.self, BossTask.self])
    }
}

enum AppTab: CaseIterable {
    case today, arcs, status, coach

    var glyph: Glyph {
        switch self {
        case .today: .torii
        case .arcs: .mountain
        case .status: .person
        case .coach: .book
        }
    }

    var label: String {
        switch self {
        case .today: "Today"
        case .arcs: "Arcs"
        case .status: "Status"
        case .coach: "Coach"
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(QuestEngine.self) private var engine
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Arc.startDate, order: .reverse) private var arcs: [Arc]
    @Query private var players: [Player]
    @Query(sort: \Quest.scheduledAt) private var quests: [Quest]
    @State private var tab: AppTab = .today
    /// Lets the tab bar's dot slide from one tab to the next (matchedGeometryEffect).
    @Namespace private var tabBarSpace

    var body: some View {
        ZStack {
            Backdrop()

            Group {
                switch tab {
                case .today: TodayView()
                case .arcs: ArcsView()
                case .status: StatusView()
                case .coach: CoachView()
                }
            }
            // A new id makes SwiftUI treat each tab as a new view, so it fades
            // in and its sections run their entrance again.
            .id(tab)
            .transition(.opacity)
            .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }

            // Its own layer, so it sits below the status bar on every device.
            VStack {
                rewardBanner
                Spacer(minLength: 0)
            }
            .allowsHitTesting(false)

            if let level = engine.levelUp {
                LevelUpOverlay(level: level) { engine.levelUp = nil }
            }
        }
        .foregroundStyle(Ink.washi)
        .animation(.spring(duration: 0.45, bounce: 0.2), value: engine.notice)
        // Runs again whenever progress changes, so the cloud copy follows along.
        .task(id: backupKey) {
            guard let player = players.first else { return }
            let today = quests.filter { Calendar.current.isDateInToday($0.scheduledAt) }
            await engine.refreshReminders(quests: today, plan: arcs.first?.plan ?? [])
            await engine.backUp(player: player, quests: today)
        }
        .task { Bootstrap.start(context) }
        // Coming back to the app on a new day creates that day's quests.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Bootstrap.rollDailyQuests(context) }
        }
    }

    /// Changes whenever something worth saving changes.
    private var backupKey: [Int] {
        guard let player = players.first else { return [] }
        return [player.totalXP, player.bankedMinutes, quests.count, arcs.count,
                quests.filter(\.isDone).count, quests.filter(\.isFailed).count]
    }

    @ViewBuilder private var rewardBanner: some View {
        if let notice = engine.notice {
            RewardBanner(notice: notice)
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                // .task(id:) restarts when a newer notice replaces this one, so
                // each banner gets its full time on screen.
                .task(id: notice.id) {
                    // If the task is cancelled, sleep throws and we leave the
                    // banner for whichever task replaced this one.
                    guard (try? await Task.sleep(for: .seconds(2.4))) != nil else { return }
                    if engine.notice?.id == notice.id { engine.notice = nil }
                }
        }
    }

    private var tabBar: some View {
        HStack {
            ForEach(AppTab.allCases, id: \.self) { item in
                Button {
                    withAnimation(.snappy(duration: 0.28)) { tab = item }
                } label: {
                    VStack(spacing: 5) {
                        GlyphIcon(item.glyph, size: 24, tint: tab == item ? Ink.ai : Ink.mute)
                            .scaleEffect(tab == item ? 1.1 : 1)
                        Text(item.label).font(.text(12, weight: .medium))
                        ZStack {
                            if tab == item {
                                Capsule()
                                    .fill(Ink.ai)
                                    .shadow(color: Ink.ai, radius: 4)
                                    .matchedGeometryEffect(id: "dot", in: tabBarSpace)
                            }
                        }
                        .frame(width: 18, height: 3)
                    }
                    .foregroundStyle(tab == item ? Ink.washi : Ink.mute)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 4)
        .sensoryFeedback(.selection, trigger: tab)
        .background(
            Ink.sumi
                .overlay(alignment: .top) { Rectangle().fill(Ink.faint).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

/// Shared scroll container so every screen has the same margins.
struct Screen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                // Group(subviews:) hands back the children of `content` one by
                // one, so each section can arrive a beat after the one above it
                // without any screen having to ask for it.
                Group(subviews: content) { subviews in
                    ForEach(Array(subviews.enumerated()), id: \.element.id) { index, subview in
                        subview.appear(index)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
    }
}
