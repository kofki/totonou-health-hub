import SwiftData
import SwiftUI
import TotonouCore

/// One screen to connect every outside source. Each row asks iOS for its own
/// permission when you tap it, never before.
struct ConnectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(QuestEngine.self) private var engine
    @Query(sort: \Arc.startDate, order: .reverse) private var arcs: [Arc]
    @Query private var players: [Player]

    /// iOS never tells an app whether Health read access was granted (that
    /// itself would reveal something), so the app remembers that it asked.
    @AppStorage("healthAsked") private var healthAsked = false
    @State private var refresh = 0

    var body: some View {
        ZStack {
            Backdrop()
            ScrollView {
                VStack(spacing: 16) {
                    AppWordmark(size: 24).padding(.top, 8)
                    SystemWindow(title: "Connect your life") {
                        Text("Quests finish themselves when real data says you did them.")
                            .font(.text(17, weight: .medium))
                    }
                    VStack(spacing: 4) {
                        row(.heart, "Apple Health", "Steps, runs, sleep, mindful minutes. Garmin syncs in through Health.",
                            done: healthAsked) {
                            healthAsked = await HealthKitSignalSource.requestAccess()
                        }
                        row(.calendar, "Calendar", "Every calendar on this iPhone. Add Google in Settings → Calendar → Accounts.",
                            done: engine.day.hasCalendarAccess) {
                            _ = await engine.day.requestCalendarAccess()
                        }
                        row(.bell, "Reminders", "Reminders due today become quests.", done: engine.day.hasRemindersAccess) {
                            if await engine.day.requestRemindersAccess(), let player = players.first {
                                await engine.importReminders(context: context, player: player)
                            }
                        }
                        if engine.alarms.isSupported {
                            row(.alarm, "Alarms", "A daily wake-up alarm before your first quest, with Done and Snooze.",
                                done: engine.wakeAlarmID != nil) {
                                await engine.setWakeAlarm(true, plan: arcs.first?.plan ?? [])
                            }
                        }
                        row(.lock, "Screen Time lock", "Locks chosen apps until you spend earned minutes. Needs a paid Apple developer account first.",
                            done: false, available: false) {}
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Ink.raised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .id(refresh)

                    Button("Done") { dismiss() }
                        .buttonStyle(SystemButtonStyle(filled: true))
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(Ink.washi)
    }

    private func row(_ glyph: Glyph, _ title: String, _ detail: String, done: Bool, available: Bool = true,
                     connect: @escaping () async -> Void) -> some View {
        HStack(spacing: 14) {
            GlyphIcon(glyph, size: 26, tint: available ? Ink.ai : Ink.mute)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.text(17, weight: .semibold)).foregroundStyle(available ? Ink.washi : Ink.mute)
                Text(detail).caption(size: 13)
            }
            Spacer(minLength: 8)
            if done {
                GlyphIcon(.check, size: 20, tint: Ink.ai).accessibilityLabel("Connected")
            } else {
                Button(available ? "Allow" : "Later") {
                    Task {
                        await connect()
                        refresh += 1
                    }
                }
                .font(.text(14, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(available ? Ink.ai : Ink.mute)
                .background((available ? Ink.ai : Ink.washi).opacity(0.12), in: Capsule())
                .disabled(!available)
            }
        }
        .padding(.vertical, 12)
    }
}
