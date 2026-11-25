import CryptoKit
import Foundation
import Supabase
import TotonouCore

// The link between the app and Claude, through the `mcp` Edge Function
// (supabase/functions/mcp/index.ts). Claude runs on your own Claude account
// (the phone app, claude.ai, or Claude Code), so there is no API key and no
// cost per call. The two sides never talk directly:
//
//   app ──uploads snapshot──▶ claude_snapshots ──get_overview──▶ Claude
//   app ◀──applies changes── claude_changes  ◀──add_quests…──── Claude
//
// The phone stays the source of truth: Claude only leaves requests, and the
// engine applies them like any other quest (ClaudeChanges.swift).

/// Where Claude connects. Paste this into Claude as a custom connector.
enum ClaudeServer {
    static var url: URL? { URL(string: SupabaseConfig.url + "/functions/v1/mcp") }

    /// The address with the token in it, for claude.ai, whose custom
    /// connectors cannot send a header. Treat it like a password.
    static func connectorURL(token: String) -> String? {
        guard let url, var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        parts.queryItems = [URLQueryItem(name: "token", value: token)]
        return parts.string
    }

    /// The Claude Code command that adds the server, token in a header.
    static func claudeCodeCommand(token: String) -> String? {
        guard let url else { return nil }
        return "claude mcp add --transport http totonou \(url.absoluteString) --header \"Authorization: Bearer \(token)\""
    }
}

/// One request Claude left for the app.
struct ClaudeChange: Decodable, Sendable, Identifiable {
    enum Kind: String, Decodable, Sendable {
        case addQuest = "add_quest"
        case removeQuest = "remove_quest"
        case addArc = "add_arc"
        case addDailyQuest = "add_daily_quest"
        case endArc = "end_arc"
        case addObjective = "add_objective"
        case coachMessage = "coach_message"
        case setSteps = "set_steps"
        case shareQuest = "share_quest"
    }

    let id: UUID
    let kind: Kind
    let payload: Payload
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, kind, payload
        case createdAt = "created_at"
    }

    /// Every field any kind of change can carry. Each kind fills a few; the
    /// function has already checked them (see `quest()` in the function).
    struct Payload: Decodable, Sendable {
        var title: String?
        var why: String?
        var stat: String?
        var rank: String?
        var time: String?
        var minutes: Int?
        var mustDo: Bool?
        var signal: String?
        var target: Double?
        var date: String?
        var weekdays: [Int]?
        var arc: String?
        /// For a quest: the objective it counts toward. Titles, as Claude sees them.
        var objective: String?
        /// For a quest: the title of the quest on the same day it is a step of.
        var partOf: String?
        /// For a quest or daily quest: its checklist, each with title, minutes and rank.
        var steps: [Payload]?
        /// For an objective: quest titles from other arcs that also count toward it.
        var sharedQuests: [String]?
        /// For share_quest: true to stop sharing.
        var remove: Bool?
        var kind: String?
        var manifesto: String?
        var goals: [String]?
        var objectives: [Payload]?
        var period: String?
        var count: Int?
        var detail: String?
        var startDate: String?
        var endDate: String?
        var dailyQuests: [Payload]?
        var text: String?
    }
}

/// What the app needs from the server side. A protocol, like every outside
/// system here, so previews and tests can run without a network.
protocol ClaudeLink: Sendable {
    /// Replace the document Claude reads with this one.
    func upload(snapshot: Data) async throws
    /// Changes Claude left that the app has not applied yet, oldest first.
    func pendingChanges() async throws -> [ClaudeChange]
    /// Stamp a change as applied, with what happened, so it is not applied twice.
    func markApplied(_ id: UUID, result: String) async throws
    /// A fresh token. Older ones keep working (the Claude connector and the Mac
    /// relay each have their own); only the five newest are kept.
    func newToken() async throws -> String
    /// Disconnect Claude: no token works any more.
    func revokeTokens() async throws
    /// Whether a token exists, so the screen can say "Connected".
    func hasToken() async throws -> Bool
}

enum ClaudeLinks {
    /// The link this app has, or nil when Supabase is not configured.
    static func make() -> (any ClaudeLink)? {
        SupabaseConfig.client.map(SupabaseClaudeLink.init)
    }
}

struct SupabaseClaudeLink: ClaudeLink {
    let client: SupabaseClient

    private struct SnapshotRow: Encodable {
        let userID: UUID
        let data: AnyJSON
        let updatedAt: Date
        enum CodingKeys: String, CodingKey {
            case userID = "user_id", data, updatedAt = "updated_at"
        }
    }

    private struct TokenRow: Codable {
        let tokenHash: String
        enum CodingKeys: String, CodingKey { case tokenHash = "token_hash" }
    }

    private struct TokenAge: Decodable {
        let tokenHash: String
        enum CodingKeys: String, CodingKey { case tokenHash = "token_hash" }
    }

    private func userID() async throws -> UUID {
        if let session = try? await client.auth.session { return session.user.id }
        return try await client.auth.signInAnonymously().user.id
    }

    func upload(snapshot: Data) async throws {
        let row = SnapshotRow(userID: try await userID(),
                              data: try JSONDecoder().decode(AnyJSON.self, from: snapshot), updatedAt: .now)
        try await client.from("claude_snapshots").upsert(row, onConflict: "user_id").execute()
    }

    func pendingChanges() async throws -> [ClaudeChange] {
        _ = try await userID()
        // Row-level security limits this to your own rows.
        return try await client.from("claude_changes")
            .select("id, kind, payload, created_at")
            .is("applied_at", value: nil)
            .order("created_at")
            .limit(100)
            .execute()
            .value
    }

    func markApplied(_ id: UUID, result: String) async throws {
        try await client.from("claude_changes")
            .update(["applied_at": ISO8601DateFormatter().string(from: .now), "result": result])
            .eq("id", value: id)
            .execute()
    }

    func newToken() async throws -> String {
        _ = try await userID()
        let token = ClaudeToken.make()
        try await client.from("claude_tokens").insert(TokenRow(tokenHash: ClaudeToken.hash(token))).execute()
        // Keep the five newest; older links stop working.
        let all: [TokenAge] = try await client.from("claude_tokens").select("token_hash")
            .order("created_at", ascending: false).execute().value
        let old = all.dropFirst(5).map(\.tokenHash)
        if !old.isEmpty {
            try await client.from("claude_tokens").delete().in("token_hash", values: old).execute()
        }
        return token
    }

    func revokeTokens() async throws {
        let id = try await userID()
        try await client.from("claude_tokens").delete().eq("user_id", value: id).execute()
    }

    func hasToken() async throws -> Bool {
        _ = try await userID()
        let rows: [TokenRow] = try await client.from("claude_tokens").select("token_hash").limit(1).execute().value
        return !rows.isEmpty
    }
}

/// A random secret, and the hash the database keeps instead of it.
enum ClaudeToken {
    /// 32 random bytes as URL-safe text: long enough that guessing is hopeless.
    static func make() -> String {
        // `SymmetricKey` is CryptoKit's way to get bytes from the system's
        // secure random generator; we only want its bytes.
        let bytes = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        return "tt_" + bytes.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// SHA-256 as lowercase hex, the same as the function computes.
    static func hash(_ token: String) -> String {
        SHA256.hash(data: Data(token.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Requests the app writes for Claude, to open in the Claude app or claude.ai.
enum ClaudePrompt {
    static func newArc(title: String, kind: ArcKind, manifesto: String) -> String {
        let length = kind == .seasonal ? "a seasonal arc of 90 days starting today" : "an objective arc with no end date"
        return """
        Use the Totonou connector. I want to start \(length) called "\(title)".
        In my words: \(manifesto)

        First call get_overview so you know my other arcs, my stats and when I actually finish quests. \
        Then propose: one to three outcomes with numbers, two to four daily or weekly objectives, and \
        specific quests that each count toward one objective, on the weekdays they happen, at times \
        that fit around my other arcs. Ask me what you need to know. When I agree, create it with create_arc.
        """
    }

    /// The coach question, or a general check-in when the box is empty.
    static func coach(question: String) -> String {
        let ask = question.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        Use the Totonou connector and be my coach. Call get_overview first and use only what it measured.
        \(ask.isEmpty ? "How am I doing across my arcs, and what should I do today?" : ask)

        Be direct and specific. If a change to my quests or objectives would help, propose it and make it \
        only after I agree. When we are done, leave a one-line summary for the app with set_coach_message.
        """
    }

    /// claude.ai's new-chat address with the request filled in. It opens the
    /// Claude app when it is installed. The request is also on the clipboard,
    /// in case the text does not come through.
    static func url(for request: String) -> URL? {
        var parts = URLComponents(string: "https://claude.ai/new")
        parts?.queryItems = [URLQueryItem(name: "q", value: request)]
        return parts?.url
    }
}
