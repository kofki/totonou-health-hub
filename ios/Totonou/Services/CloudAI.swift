import Foundation
import Supabase
import TotonouCore

// The cloud language model, for phones without Apple Intelligence (anything
// older than an iPhone 15 Pro). The app never talks to the model directly and
// holds no API key: it calls the `ai` Edge Function in Supabase
// (supabase/functions/ai/index.ts), which holds the key, checks who is calling
// and counts calls per day. Unlike the on-device model, what is sent here does
// leave the phone: the coach's fact sheet, or an arc's name and manifesto.

/// What the app sends to the function. One struct for both kinds of request;
/// the fields a kind does not use stay nil and are left out of the JSON.
struct AIRequest: Encodable, Sendable, Equatable {
    var kind: String
    var facts: String?
    var question: String?
    var title: String?
    var manifesto: String?

    static func coach(facts: String, question: String?) -> AIRequest {
        AIRequest(kind: "coach", facts: facts, question: question)
    }

    static func plan(title: String, manifesto: String) -> AIRequest {
        AIRequest(kind: "plan", title: title, manifesto: manifesto)
    }
}

/// Somewhere that answers an `AIRequest` with raw JSON. A protocol, like every
/// outside system here, so previews and tests can answer without a network.
protocol AIBackend: Sendable {
    func send(_ request: AIRequest) async throws -> Data
}

enum CloudAIError: Error {
    /// The function answered, but not in the shape we expected.
    case badAnswer
    /// Exercise 15 has not been written yet.
    case notWritten
}

enum CloudAI {
    /// The backend this app has, or nil when Supabase is not configured.
    static func backend() -> (any AIBackend)? {
        SupabaseConfig.client.map(SupabaseAIBackend.init)
    }
}

/// The real backend: the `ai` Edge Function.
struct SupabaseAIBackend: AIBackend {
    let client: SupabaseClient

    func send(_ request: AIRequest) async throws -> Data {
        // The function only answers signed-in users. The engine signs in at
        // launch; this covers a call that gets there first.
        if (try? await client.auth.session) == nil { try await client.auth.signInAnonymously() }
        // The closure hands back the raw bytes, so each caller decodes its own
        // shape. A status outside 200-299 makes `invoke` throw instead.
        return try await client.functions.invoke("ai", options: FunctionInvokeOptions(body: request)) { data, _ in data }
    }
}

/// The coach, answered by the cloud model. Same rules as the on-device one: it
/// is given the measured facts and nothing else.
struct CloudCoachAdvisor: CoachAdvisor {
    let backend: any AIBackend

    /// The function's reply to a coach request: {"text": "..."}.
    private struct Answer: Decodable {
        let text: String
    }

    func advise(facts: String, question: String?) async throws -> String {
        let data = try await backend.send(.coach(facts: facts, question: question))
        let answer = try JSONDecoder().decode(Answer.self, from: data)
        guard !answer.text.isEmpty else { throw CloudAIError.badAnswer }
        return answer.text
    }
}

/// The coach answered by Claude Code on your Mac (scripts/coach-relay), on your
/// own Claude account. The question waits in the `coach_questions` table until
/// the relay answers it, so this polls for the answer for up to two minutes.
struct ClaudeRelayAdvisor: CoachAdvisor {
    let client: SupabaseClient
    var answersOnOpen: Bool { false }

    enum RelayError: Error { case noAnswerYet }

    private struct NewQuestion: Encodable {
        let question: String
    }

    private struct Row: Decodable {
        let id: UUID
        let answer: String?
        let answeredAt: Date?
        enum CodingKeys: String, CodingKey { case id, answer, answeredAt = "answered_at" }
    }

    func advise(facts: String, question: String?) async throws -> String {
        // The relay reads the facts itself through get_overview, so only the question is sent.
        guard let question = question?.trimmingCharacters(in: .whitespacesAndNewlines), !question.isEmpty else {
            throw RelayError.noAnswerYet
        }
        if (try? await client.auth.session) == nil { try await client.auth.signInAnonymously() }
        let asked: Row = try await client.from("coach_questions").insert(NewQuestion(question: question))
            .select("id, answer, answered_at").single().execute().value
        for _ in 0..<40 {
            try await Task.sleep(for: .seconds(3))
            let row: Row = try await client.from("coach_questions").select("id, answer, answered_at")
                .eq("id", value: asked.id).single().execute().value
            if let answer = row.answer { return answer }
        }
        throw RelayError.noAnswerYet
    }

    /// Today's latest answer, so one that arrived after you left the tab still shows.
    func latestAnswerToday() async -> String? {
        guard (try? await client.auth.session) != nil else { return nil }
        let start = Calendar.current.startOfDay(for: .now)
        let rows: [Row]? = try? await client.from("coach_questions").select("id, answer, answered_at")
            .not("answer", operator: .is, value: "null")
            .gte("answered_at", value: ISO8601DateFormatter().string(from: start))
            .order("answered_at", ascending: false).limit(1).execute().value
        return rows?.first?.answer
    }
}
