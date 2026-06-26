import Foundation
import SwiftUI
import Observation

enum AppRoute: Equatable {
    case onboarding
    case library
}

/// Global app settings + navigation, persisted to UserDefaults.
@MainActor
@Observable
final class AppState {
    var route: AppRoute
    var selectedMeetingID: UUID?
    var showDetailPanel: Bool = true
    /// True while a recording is active (recording or paused). Drives the menu-bar indicator.
    /// In-memory only; mirrored from the RecordingViewModel's phase.
    var isRecording: Bool = false

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
    /// OpenAI model id used for summaries + AI suggestions (e.g. "gpt-4o").
    var summaryModel: String {
        didSet { defaults.set(summaryModel, forKey: Keys.summaryModel) }
    }
    /// Name used to label the user's own (microphone) speech in transcripts.
    var userDisplayName: String {
        didSet { defaults.set(userDisplayName, forKey: Keys.userDisplayName) }
    }
    /// Transcribe system audio (remote participants) as a second stream.
    var transcribeSystemAudio: Bool {
        didSet { defaults.set(transcribeSystemAudio, forKey: Keys.transcribeSystemAudio) }
    }
    /// Play an audible notice when a recording starts (default for the consent sheet).
    var playNotice: Bool {
        didSet { defaults.set(playNotice, forKey: Keys.playNotice) }
    }
    var hasOpenAIKey: Bool

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let onboarded = "auris.onboarded"
        static let transcriptionLocale = "auris.transcriptionLocale"
        static let summaryLanguage = "auris.summaryLanguage"
        static let interfaceLanguage = "auris.interfaceLanguage"
        static let summaryModel = "auris.summaryModel"
        static let userDisplayName = "auris.userDisplayName"
        static let transcribeSystemAudio = "auris.transcribeSystemAudio"
        static let playNotice = "auris.playNotice"
    }

    init() {
        let onboarded = defaults.bool(forKey: Keys.onboarded)
        route = onboarded ? .library : .onboarding
        transcriptionLocale = defaults.string(forKey: Keys.transcriptionLocale) ?? "en-US"
        summaryLanguage = defaults.string(forKey: Keys.summaryLanguage) ?? "en"
        interfaceLanguage = defaults.string(forKey: Keys.interfaceLanguage) ?? ""
        summaryModel = defaults.string(forKey: Keys.summaryModel) ?? "gpt-4o"
        userDisplayName = defaults.string(forKey: Keys.userDisplayName) ?? ""
        transcribeSystemAudio = defaults.object(forKey: Keys.transcribeSystemAudio) as? Bool ?? true
        playNotice = defaults.object(forKey: Keys.playNotice) as? Bool ?? true
        hasOpenAIKey = KeychainStore.hasKey
    }

    var localeOverride: Locale? {
        interfaceLanguage.isEmpty ? nil : Locale(identifier: interfaceLanguage)
    }

    /// Localizes a catalog key using the app's selected interface language (not the system
    /// language). `String(localized:)` follows the system locale, so labels created outside of
    /// SwiftUI `Text` (e.g. transcript speaker names) need this to match the displayed UI language.
    func localizedUI(_ key: String) -> String {
        if !interfaceLanguage.isEmpty,
           let path = Bundle.main.path(forResource: interfaceLanguage, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: key, table: nil)
        }
        return Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }

    func completeOnboarding() {
        defaults.set(true, forKey: Keys.onboarded)
        route = .library
    }

    func refreshKeyStatus() {
        hasOpenAIKey = KeychainStore.hasKey
    }
}
