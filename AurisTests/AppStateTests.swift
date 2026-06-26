import Testing
import Foundation
@testable import Auris

/// AppState persists to `UserDefaults.standard`, so each test restores the keys it touches.
@MainActor
struct AppStateTests {

    @Test func localeOverrideMapsInterfaceLanguage() {
        let key = "auris.interfaceLanguage"
        let saved = UserDefaults.standard.object(forKey: key)
        defer { restore(key, saved) }

        let state = AppState()

        state.interfaceLanguage = ""
        #expect(state.localeOverride == nil)

        state.interfaceLanguage = "pt-BR"
        #expect(state.localeOverride == Locale(identifier: "pt-BR"))
    }

    @Test func completeOnboardingRoutesToLibrary() {
        let key = "auris.onboarded"
        let saved = UserDefaults.standard.object(forKey: key)
        defer { restore(key, saved) }

        let state = AppState()
        state.route = .onboarding
        state.completeOnboarding()
        #expect(state.route == .library)
    }

    @Test func refreshKeyStatusMirrorsKeychain() {
        let state = AppState()
        state.refreshKeyStatus()
        // Consistency check: the flag always matches the keychain at refresh time.
        #expect(state.hasOpenAIKey == KeychainStore.hasKey)
    }

    private func restore(_ key: String, _ value: Any?) {
        if let value { UserDefaults.standard.set(value, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
    }
}
