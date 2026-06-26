import Foundation

/// Tracks cumulative OpenAI API usage (tokens + number of summaries) so the UI can show an
/// estimated cost, matching the "Uso da API (GPT)" card in the design. Persisted in the app group.
enum UsageStore {
    /// Approximate blended price per 1K tokens for gpt-4o, in USD. Used only for an *estimate*.
    private static let usdPer1KTokens = 0.005

    private enum Keys {
        static let tokens = "auris.usage.tokens"
        static let summaries = "auris.usage.summaries"
    }

    static var tokenCount: Int {
        AppGroup.defaults.integer(forKey: Keys.tokens)
    }

    static var summaryCount: Int {
        AppGroup.defaults.integer(forKey: Keys.summaries)
    }

    /// Estimated spend in USD based on accumulated tokens.
    static var estimatedCostUSD: Double {
        Double(tokenCount) / 1000.0 * usdPer1KTokens
    }

    /// Records one completed summary call.
    static func record(tokens: Int) {
        let d = AppGroup.defaults
        d.set(tokenCount + max(0, tokens), forKey: Keys.tokens)
        d.set(summaryCount + 1, forKey: Keys.summaries)
    }

    static func reset() {
        let d = AppGroup.defaults
        d.removeObject(forKey: Keys.tokens)
        d.removeObject(forKey: Keys.summaries)
    }
}
