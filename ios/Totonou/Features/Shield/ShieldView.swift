import SwiftData
import SwiftUI
import TotonouCore

/// What you see instead of Instagram.
///
/// This is a preview inside the app. The real intercept is a ShieldConfiguration
/// extension driven by the Screen Time API (FamilyControls, ManagedSettings,
/// DeviceActivity), which needs a paid Apple Developer account and Apple's
/// Family Controls entitlement before it can run on a device.
struct ShieldView: View {
    let quest: Quest?
    let locked: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(QuestEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var players: [Player]
    @State private var unlockedUntil: Date?

    private let cost = 15
    private var tint: Color { locked ? Ink.shu : Ink.ai }

    var body: some View {
        ZStack {
            Backdrop()
            InkMist(count: 40, tint: tint).ignoresSafeArea()
            GlyphIcon(.lock, size: 220, tint: tint)
                .offset(y: -150)
                // The lock breathes: slower than a heartbeat, so it calms.
                .phaseAnimator(reduceMotion ? [0.5] : [0.0, 1.0]) { lock, phase in
                    lock.opacity(0.10 + phase * 0.08).scaleEffect(1 + phase * 0.03)
                } animation: { _ in
                    .easeInOut(duration: 3.2)
                }

            VStack(alignment: .leading, spacing: 24) {
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Text(locked ? "Everything is locked." : "Instagram is locked.")
                        .font(.text(32, weight: .bold))
                    Text(locked ? "Finish the recovery quest to open it again." : "Do this first.")
                        .font(.text(18))
                        .foregroundStyle(Ink.mute)
                }

                if let quest {
                    SystemWindow(title: "Quest", tint: tint) {
                        Text(quest.title).font(.text(22, weight: .bold))
                        Text("\(quest.scheduledAt.clock) · +\(quest.rank.earnedMinutes) min").caption(.white.opacity(0.85), size: 16)
                    }
                }

                if let unlockedUntil {
                    Text("Unlocked until \(unlockedUntil.clock)").caption(Ink.ai, size: 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                VStack(spacing: 10) {
                    Button("Back to quest") { dismiss() }
                        .buttonStyle(SystemButtonStyle(tint: tint, filled: true))
                    if let player = players.first {
                        Button("Spend \(cost) min (\(player.bankedMinutes) left)") {
                            engine.spend(minutes: cost, player: player)
                            withAnimation(.snappy) {
                                unlockedUntil = Date.now.addingTimeInterval(TimeInterval(cost * 60))
                            }
                        }
                        .buttonStyle(SystemButtonStyle(tint: Ink.mute))
                        .disabled(locked || player.bankedMinutes < cost)
                    }
                }
            }
            .padding(24)
        }
        .foregroundStyle(Ink.washi)
        .preferredColorScheme(.dark)
    }
}
