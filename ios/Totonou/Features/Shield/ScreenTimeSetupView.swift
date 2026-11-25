import FamilyControls
import SwiftUI
import TotonouCore

/// Set up the Screen Time lock: allow it, choose the apps, switch it on.
struct ScreenTimeSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var lock = ScreenTimeLock.shared
    @State private var picking = false
    @State private var lockInOn = ScreenTimeLock.shared.lockInHours != nil
    @State private var lockInStart = ScreenTimeLock.shared.lockInHours?.start ?? 23
    @State private var lockInEnd = ScreenTimeLock.shared.lockInHours?.end ?? 7

    var body: some View {
        ZStack {
            Backdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SystemWindow(title: "Screen Time lock") {
                        Text("The apps you choose stay locked. Spend minutes you earned from quests to open them for that long.")
                            .font(.text(17, weight: .medium))
                    }

                    if !lock.isAuthorized {
                        SystemPanel {
                            Text("Apple asks for Face ID or your passcode once. Only this phone is affected.")
                                .font(.text(16)).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button("Allow Screen Time") { Task { await lock.authorize() } }
                            .buttonStyle(SystemButtonStyle(filled: true))
                    } else {
                        SystemPanel {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(summary).font(.text(18, weight: .semibold))
                                if let minutes = ScreenTimeLock.usageToday() {
                                    // Apple reports usage in steps, so this is a lower bound.
                                    Text("Used today: \(minutes == 0 ? "under 15" : "at least \(minutes)") min.").caption()
                                }
                                if let until = lock.unlockedUntil {
                                    // Exercise 19 turns this into a live countdown.
                                    UnlockCountdown(from: lock.unlockedFrom ?? .now, until: until)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button(lock.hasApps ? "Change apps" : "Choose apps") { picking = true }
                            .buttonStyle(SystemButtonStyle(filled: !lock.hasApps))
                        if lock.hasApps {
                            Button(lock.isOn ? "Turn the lock off" : "Lock these apps") { lock.setOn(!lock.isOn) }
                                .buttonStyle(SystemButtonStyle(tint: lock.isOn ? Ink.shu : Ink.ai, filled: !lock.isOn))
                        }
                        if lock.isOn { lockIn }
                    }

                    // What iOS reports right now, to see why something does not lock.
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Permission: \(lock.permissionText)").caption()
                        Text("Lock switched on: \(lock.isOn ? "yes" : "no")").caption()
                        Text("Locked by iOS now: \(lock.shieldedText)").caption()
                        if let problem = lock.problem {
                            Text(problem).caption(Ink.shu)
                        }
                    }

                    Button("Done") { dismiss() }
                        .buttonStyle(SystemButtonStyle(tint: Ink.mute))
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
        }
        .foregroundStyle(Ink.washi)
        // Read the permission again when the screen opens: it may have settled since launch.
        .task { lock.refresh() }
        // Apple's own picker. The app gets back tokens, never the app names.
        .familyActivityPicker(isPresented: $picking, selection: $lock.selection)
    }

    /// Lock-in hours: no spending minutes between these hours, so late nights
    /// stay off the apps. Saved as soon as it changes.
    private var lockIn: some View {
        SystemPanel {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $lockInOn) {
                    Text("Lock-in hours").font(.text(18, weight: .semibold))
                }
                .tint(Ink.ai)
                Text("The locked apps stay shut between these hours, even with minutes banked.").caption(size: 14)
                if lockInOn {
                    HStack {
                        Picker("From", selection: $lockInStart) {
                            ForEach(0..<24, id: \.self) { Text(Self.hour($0)).tag($0) }
                        }
                        Text("to").caption()
                        Picker("To", selection: $lockInEnd) {
                            ForEach(0..<24, id: \.self) { Text(Self.hour($0)).tag($0) }
                        }
                    }
                    .tint(Ink.ai)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: [lockInOn ? 1 : 0, lockInStart, lockInEnd]) {
            lock.setLockIn(on: lockInOn, start: lockInStart, end: lockInEnd)
        }
    }

    /// "11 PM", in the same 12-hour style as the rest of the app.
    static func hour(_ hour: Int) -> String {
        let twelve = hour % 12 == 0 ? 12 : hour % 12
        return "\(twelve) \(hour < 12 ? "AM" : "PM")"
    }

    private var summary: String {
        let apps = lock.selection.applicationTokens.count
        let groups = lock.selection.categoryTokens.count
        let chosen = [apps > 0 ? "\(apps) app\(apps == 1 ? "" : "s")" : nil,
                      groups > 0 ? "\(groups) categor\(groups == 1 ? "y" : "ies")" : nil].compactMap { $0 }
        if chosen.isEmpty { return "No apps chosen yet." }
        return (lock.isOn ? "Locked: " : "Chosen, not locked: ") + chosen.joined(separator: ", ") + "."
    }
}
