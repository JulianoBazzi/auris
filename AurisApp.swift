import SwiftUI
import SwiftData

@main
struct AurisApp: App {
    @State private var appState = AppState()

    let container: ModelContainer = {
        let schema = Schema([Meeting.self, TranscriptSegment.self, Speaker.self, Attachment.self, Tag.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .frame(minWidth: 980, minHeight: 640)
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .appSettings) {
                // Settings live inside the window; nothing here for now.
            }
        }

        MenuBarExtra("Auris", systemImage: "waveform") {
            MenuBarView()
                .environment(appState)
                .modelContainer(container)
                .environment(\.locale, appState.localeOverride ?? Locale.current)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Switches between onboarding and the main library based on app state.
struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            switch appState.route {
            case .onboarding:
                OnboardingView()
            case .library:
                RootSplitView()
            }
        }
        .background(AurisColor.bgWindow)
        .environment(\.locale, appState.localeOverride ?? Locale.current)
        .id(appState.interfaceLanguage)
        .onAppear { LibraryViewModel.seedIfNeeded(context) }
    }
}
