import Foundation

struct MeetingSummary: Codable {
    var executiveSummary: String
    var topics: [String]
    var actionItems: [String]
}

/// AI-suggested metadata for a finished meeting (title, an alternative, tags, accent color).
struct MeetingSuggestion: Codable {
    var title: String
    var alternativeTitle: String
    var tags: [String]
    var colorHex: String
}

protocol Summarizing: AnyObject {
    func summarize(transcript: String, imageData: [Data], language: String) async throws -> MeetingSummary
    /// Suggests a title, alternative title, tags and accent color from the transcript.
    func suggestMetadata(transcript: String, language: String) async throws -> MeetingSuggestion
}

enum SummarizationError: LocalizedError {
    case missingKey
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "No OpenAI API key set. Add it in Settings."
        case .badResponse(let m): return "OpenAI error: \(m)"
        }
    }
}

/// Calls the OpenAI Chat Completions API to turn a transcript (+ optional images) into a
/// structured summary. The API key comes from the Keychain.
final class SummarizationService: Summarizing {
    private let session: URLSession

    /// Read at call time so changing the model in Settings takes effect without recreating the service.
    private var model: String {
        UserDefaults.standard.string(forKey: "auris.summaryModel") ?? "gpt-4o"
    }

    init(session: URLSession = .shared) {
        self.session = session
    }

    func summarize(transcript: String, imageData: [Data], language: String) async throws -> MeetingSummary {
        let system = """
        You are a meeting assistant. Summarize the transcript into JSON with keys: \
        executiveSummary (string), topics (array of strings), actionItems (array of strings). \
        Write all output in the language with code "\(language)". Be concise and factual.
        """

        var content: [[String: Any]] = [["type": "text", "text": "Transcript:\n\(transcript)"]]
        for data in imageData {
            let b64 = data.base64EncodedString()
            content.append([
                "type": "image_url",
                "image_url": ["url": "data:image/png;base64,\(b64)"]
            ])
        }

        let text = try await chat(system: system, userContent: content)
        guard let summaryData = text.data(using: .utf8) else {
            throw SummarizationError.badResponse("Malformed response")
        }
        return try JSONDecoder().decode(MeetingSummary.self, from: summaryData)
    }

    func suggestMetadata(transcript: String, language: String) async throws -> MeetingSuggestion {
        // No key (or any failure) → local heuristic, so the flow always produces a suggestion.
        guard KeychainStore.hasKey else { return Self.heuristicSuggestion(transcript: transcript) }

        let palette = "#3B82F6, #34D399, #B07CF6, #FBBF24, #F87171"
        let system = """
        You name meetings. From the transcript, return JSON with keys: title (string, max 6 words), \
        alternativeTitle (string, a different angle), tags (array of 1-3 short strings), \
        colorHex (one of: \(palette)). Write title/tags in the language with code "\(language)".
        """
        do {
            let text = try await chat(system: system,
                                      userContent: [["type": "text", "text": "Transcript:\n\(transcript)"]])
            guard let data = text.data(using: .utf8) else { throw SummarizationError.badResponse("Malformed") }
            return try JSONDecoder().decode(MeetingSuggestion.self, from: data)
        } catch {
            return Self.heuristicSuggestion(transcript: transcript)
        }
    }

    /// Title from the first words of the transcript; no tags; default accent color.
    static func heuristicSuggestion(transcript: String) -> MeetingSuggestion {
        let firstLine = transcript
            .split(whereSeparator: \.isNewline).first
            .map(String.init) ?? transcript
        let words = firstLine
            .replacingOccurrences(of: ":", with: " ")
            .split(separator: " ")
            .prefix(6)
            .joined(separator: " ")
        let title = words.isEmpty ? "" : String(words)
        return MeetingSuggestion(title: title, alternativeTitle: "", tags: [], colorHex: "#3B82F6")
    }

    /// Shared Chat Completions call. Returns the assistant message text and records token usage.
    private func chat(system: String, userContent: [[String: Any]]) async throws -> String {
        guard let apiKey = KeychainStore.read() else { throw SummarizationError.missingKey }

        let body: [String: Any] = [
            "model": model,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": userContent]
            ]
        ]

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "unknown"
            throw SummarizationError.badResponse(msg)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String
        else { throw SummarizationError.badResponse("Malformed response") }

        if let usage = json["usage"] as? [String: Any],
           let total = usage["total_tokens"] as? Int {
            UsageStore.record(tokens: total)
        }
        return text
    }
}
