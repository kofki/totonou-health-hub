import SwiftData
import SwiftUI
import TotonouCore

/// What you see instead of Instagram.
///
/// Spending minutes here opens the apps locked by the Screen Time lock
/// (ScreenTimeLock.swift) for that long. iOS shows its own lock screen on the
/// locked apps; a custom one would be a ShieldConfiguration extension.
struct ShieldView: View {
    let quest: Quest?
    let locked: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(QuestEngine.self) private var engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var players: [Player]
    @State private var unlockedUntil: Date?
    @State private var cost = 30
    @State private var usedPass = 0
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

                if let player = players.first {
                    VStack(spacing: 10) {
                        if !locked {
                            HStack(spacing: 10) {
                                ForEach([15, 30, 45], id: \.self) { minutes in
                                    Button { cost = minutes } label: {
                                        VStack(spacing: 2) {
                                            Text("\(minutes)").font(.number(24, weight: .bold))
                                            Text("min").font(.text(12, weight: .semibold))
                                        }
                                        .foregroundStyle(cost == minutes ? Ink.sumi : Ink.ai)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Ink.ai.opacity(cost == minutes ? 1 : 0.1), in: RoundedRectangle(cornerRadius: 14))
                                    }
                                    .buttonStyle(PressStyle())
                                }
                            }
                            Button("Unlock for \(cost) min (\(player.bankedMinutes) banked)") {
                                engine.spend(minutes: cost, player: player)
                                withAnimation(.snappy) {
                                    unlockedUntil = Date.now.addingTimeInterval(TimeInterval(cost * 60))
                                }
                            }
                            .buttonStyle(SystemButtonStyle(tint: Ink.ai, filled: true))
                            .disabled(player.bankedMinutes < cost)
                        }
                        // The one way through a penalty: scarce, and logged.
                        Button("Emergency pass: 5 min (\(player.emergencyPasses) left)") {
                            if engine.usePass(player: player) {
                                usedPass += 1
                                withAnimation(.snappy) { unlockedUntil = Date.now.addingTimeInterval(5 * 60) }
                            }
                        }
                        .buttonStyle(SystemButtonStyle(tint: Ink.shu))
                        .disabled(player.emergencyPasses == 0)
                        Button("Back to quest") { dismiss() }
                            .buttonStyle(SystemButtonStyle(tint: Ink.mute))
                        Text("Preview: nothing outside Totonou is locked until the Screen Time lock is built.")
                            .caption(size: 12)
                    }
                    .sensoryFeedback(.warning, trigger: usedPass)
                }
            }
            .padding(24)
        }
        .foregroundStyle(Ink.washi)
        .preferredColorScheme(.dark)
    }
}
