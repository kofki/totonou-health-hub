import SwiftData
import SwiftUI
import TotonouCore
import UserNotifications

@main
struct TotonouApp: App {
    @State private var engine: QuestEngine
    /// Made here rather than with `.modelContainer(for:)`, so code outside the
    /// views (a HealthKit wake-up while no screen is open) can reach the same database.
    private let container: ModelContainer

    init() {
        UNUserNotificationCenter.current().delegate = ReminderPresenter.shared
        let container = try! ModelContainer(for: Player.self, Quest.self, Arc.self, Boss.self, BossTask.self, Objective.self)
        let engine = QuestEngine(cloud: SupabaseConfig.makeStore())
        self.container = container
        _engine = State(initialValue: engine)
        HealthWatcher.shared.start {
            await engine.syncInBackground(container: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(engine)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}

enum AppTab: CaseIterable {
    case today, arcs, rewards, status, coach

    var glyph: Glyph {
        switch self {
        case .today: .torii
        case .arcs: .mountain
        case .rewards: .chest
        case .status: .person
        case .coach: .book
        }
    }

    var label: String {
        switch self {
        case .today: "Today"
        case .arcs: "Arcs"
        case .rewards: "Rewards"
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
    @State private var showSpend = false
    /// Lets the tab bar's dot slide from one tab to the next (matchedGeometryEffect).
    @Namespace private var tabBarSpace

    var body: some View {
        ZStack {
            Backdrop()

            Group {
                switch tab {
                case .today: TodayView()
                case .arcs: ArcsView()
                case .rewards: RewardsView()
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

            if let celebration = engine.celebration {
                CelebrationView(celebration: celebration, spend: { showSpend = true }) {
                    withAnimation(.easeOut(duration: 0.25)) { engine.dismissCelebration() }
                }
                // A new id per celebration, so each one plays its entrance from the start.
                .id(celebration.id)
                .transition(.opacity)
            }
        }
        .foregroundStyle(Ink.washi)
        .animation(.spring(duration: 0.45, bounce: 0.2), value: engine.notice)
        .sheet(isPresented: $showSpend) { StatSpendView() }
        // Runs again whenever progress changes, so the cloud copy follows along.
        .task(id: backupKey) {
            // At launch the key changes several times in a row while the day's
            // quests are made and data loads. A short wait means only the last
            // change backs up: a newer key cancels this task, and the sleep throws.
            guard (try? await Task.sleep(for: .seconds(1.5))) != nil, let player = players.first else { return }
            let today = quests.filter { Calendar.current.isDateInToday($0.scheduledAt) }
            engine.publishWidget(player: player, quests: today)
            await engine.refreshReminders(quests: today, plan: arcs.dailyPlan())
            await engine.backUp(player: player, quests: today)
            await engine.shareWithClaude(context: context)
        }
        .task {
            Bootstrap.start(context)
            await arrive()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-previewCelebrations") { engine.previewCelebrations() }
            #endif
        }
        // Coming back to the app on a new day creates that day's quests.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Bootstrap.rollDailyQuests(context)
            Task { await arrive() }
        }
    }

    /// Everything that should be fresh whenever the app is opened.
    private func arrive() async {
        guard let player = try? context.fetch(FetchDescriptor<Player>()).first else { return }
        engine.refreshStreak(player: player)
        await engine.refreshSkills()
        await engine.importReminders(context: context, player: player)
        await engine.syncInBackground(container: context.container)
        await engine.applyClaudeChanges(context: context)
    }

    /// Changes whenever something worth saving changes.
    private var backupKey: [Int] {
        guard let player = players.first else { return [] }
        return [player.totalXP, player.bankedMinutes, quests.count, arcs.active().count,
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
