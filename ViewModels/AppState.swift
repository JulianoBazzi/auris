import Foundation
import SwiftUI
import Observation

enum AppRoute: Equatable {
    case onboarding
    case library
}

/// Global app settings + navigation, persisted to UserDefaults.
@Observable
final class AppState {
    var route: AppRoute
    var selectedMeetingID: UUID?
    var showDetailPanel: Bool = true

    var transcriptionLocale: String {
        didSet { defaults.set(transcriptionLocale, forKey: Keys.transcriptionLocale) }
    }
    var summaryLanguage: String {
        didSet { defaults.set(summaryLanguage, forKey: Keys.summaryLanguage) }
    }
    /// "" = follow system; otherwise "en" / "pt-BR" / "es".
    var interfaceLanguage: String {
        didSet { defaults.set(interfaceLanguage, forKey: Keys.interfaceLanguage) }
    }
    var hasOpenAIKey: Bool

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let onboarded = "auris.onboarded"
        static let transcriptionLocale = "auris.transcriptionLocale"
        static let summaryLanguage = "auris.summaryLanguage"
        static let interfaceLanguage = "auris.interfaceLanguage"
    }

    init() {
        let onboarded = defaults.bool(forKey: Keys.onboarded)
        route = onboarded ? .library : .onboarding
        transcriptionLocale = defaults.string(forKey: Keys.transcriptionLocale) ?? "en-US"
        summaryLanguage = defaults.string(forKey: Keys.summaryLanguage) ?? "en"
        interfaceLanguage = defaults.string(forKey: Keys.interfaceLanguage) ?? ""
        hasOpenAIKey = KeychainStore.hasKey
    }

    var localeOverride: Locale? {
        interfaceLanguage.isEmpty ? nil : Locale(identifier: interfaceLanguage)
    }

    func completeOnboarding() {
        defaults.set(true, forKey: Keys.onboarded)
        route = .library
    }

    func refreshKeyStatus() {
        hasOpenAIKey = KeychainStore.hasKey
    }
}
