import SwiftUI
import SwiftData
import OSLog

@main
struct AurisApp: App {
    @State private var appState = AppState()
    /// Shared across the main window and the menu-bar extra so both can reflect/control recording.
    @State private var recorder = RecordingViewModel()

    init() {
        Logger(subsystem: "com.bazzi.auris", category: "app").notice("Auris launched build=\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?", privacy: .public)")
    }

    let container: ModelContainer = {
        let schema = Schema([Meeting.self, TranscriptSegment.self, Attachment.self, Tag.self])
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
                .environment(recorder)
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

        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .environment(recorder)
                .modelContainer(container)
                .environment(\.locale, appState.localeOverride ?? Locale.current)
        } label: {
            Image(systemName: appState.isRecording ? "record.circle.fill" : "waveform")
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
        .onAppear { LibraryViewModel.removeSeedData(context) }
    }
}
