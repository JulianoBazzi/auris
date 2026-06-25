import Foundation

struct MeetingSummary: Codable {
    var executiveSummary: String
    var topics: [String]
    var actionItems: [String]
}

protocol Summarizing: AnyObject {
    func summarize(transcript: String, imageData: [Data], language: String) async throws -> MeetingSummary
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
    private let model: String
    private let session: URLSession

    init(model: String = "gpt-4o", session: URLSession = .shared) {
        self.model = model
        self.session = session
    }

    func summarize(transcript: String, imageData: [Data], language: String) async throws -> MeetingSummary {
        guard let apiKey = KeychainStore.read() else { throw SummarizationError.missingKey }

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

        let body: [String: Any] = [
            "model": model,
            "response_format": ["type": "json_object"],
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": content]
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
              let text = message["content"] as? String,
              let summaryData = text.data(using: .utf8)
        else { throw SummarizationError.badResponse("Malformed response") }

        return try JSONDecoder().decode(MeetingSummary.self, from: summaryData)
    }
}
