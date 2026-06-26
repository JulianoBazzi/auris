import Foundation

/// Shared container between the main app and the WidgetKit extension.
enum AppGroup {
    static let id = "group.com.bazzi.auris"

    /// App-group UserDefaults, falling back to `.standard` if the group is unavailable
    /// (e.g. entitlement missing during development).
    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}
