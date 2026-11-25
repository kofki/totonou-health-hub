import Foundation
import Supabase
import UIKit
import UserNotifications

// Push notifications: alerts sent by the server while the app is closed, when
// Claude changes your plan or answers a Coach question. The phone gives the
// app a token from Apple; the token goes into `push_devices`, and the `mcp`
// function sends to it (supabase/functions/_shared/apns.ts).

@MainActor
enum Push {
    static let enabledKey = "claudeAlertsOn"
    private static let tokenKey = "pushToken"

    /// Builds from Xcode talk to Apple's test push service; TestFlight and the
    /// App Store use the real one. The server needs to know which.
    private static var environment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }

    /// Ask for permission, then ask Apple for a token. The token arrives in
    /// `AppDelegate` and is saved by `save(token:)`.
    static func enable() async -> Bool {
        let allowed = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        UserDefaults.standard.set(allowed, forKey: enabledKey)
        if allowed { UIApplication.shared.registerForRemoteNotifications() }
        return allowed
    }

    /// Stop the server sending here.
    static func disable() async {
        UserDefaults.standard.set(false, forKey: enabledKey)
        UIApplication.shared.unregisterForRemoteNotifications()
        guard let client = SupabaseConfig.client, let token = UserDefaults.standard.string(forKey: tokenKey) else { return }
        _ = try? await client.from("push_devices").delete().eq("token", value: token).execute()
    }

    /// Called again on every launch while switched on, because Apple can change the token.
    static func refresh() {
        if UserDefaults.standard.bool(forKey: enabledKey) { UIApplication.shared.registerForRemoteNotifications() }
    }

    private struct Device: Encodable {
        let token: String
        let environment: String
        let updatedAt: Date
        enum CodingKeys: String, CodingKey { case token, environment, updatedAt = "updated_at" }
    }

    static func save(token data: Data) async {
        // Apple's token is raw bytes; APNs expects them as hex.
        let token = data.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)
        guard UserDefaults.standard.bool(forKey: enabledKey), let client = SupabaseConfig.client else { return }
        if (try? await client.auth.session) == nil { _ = try? await client.auth.signInAnonymously() }
        _ = try? await client.from("push_devices")
            .upsert(Device(token: token, environment: environment, updatedAt: .now), onConflict: "token")
            .execute()
    }
}

/// SwiftUI apps have no app delegate unless they ask for one
/// (`@UIApplicationDelegateAdaptor` in TotonouApp). The push token only arrives here.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { await Push.save(token: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Push registration failed: \(error.localizedDescription)")
    }
}
