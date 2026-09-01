import Foundation

extension UserDefaults {
    /// Shared defaults in the App Group, so the app and widget agree on settings.
    static var appGroup: UserDefaults { UserDefaults(suiteName: AppGroup.identifier) ?? .standard }
}

enum SettingsKeys {
    static let streakMinMinutes = "streak_min_minutes"
    static let accentColor = "accent_color"
    static let goldMinMinutes = "gold_min_minutes"
    static let heatmapDivisions = "heatmap_divisions"
    static let darkestMinutes = "darkest_minutes"
}

/// Read-only accessors used where `@AppStorage` isn't available (widget, stats).
enum AppSettings {
    /// Minimum minutes in a day for that day to count toward a streak. Default 30.
    static var streakMinMinutes: Int {
        let value = UserDefaults.appGroup.integer(forKey: SettingsKeys.streakMinMinutes)
        return value == 0 ? 30 : value
    }

    /// Minutes in a day at/above which the day is marked "golden". Default 120.
    static var goldMinMinutes: Int {
        let value = UserDefaults.appGroup.integer(forKey: SettingsKeys.goldMinMinutes)
        return value == 0 ? 120 : value
    }

    /// Number of colour steps in the heatmap ramp (4…7). Default 5.
    static var heatmapDivisions: Int {
        let value = UserDefaults.appGroup.integer(forKey: SettingsKeys.heatmapDivisions)
        return value == 0 ? 5 : min(max(value, 4), 7)
    }

    /// Minutes in a day at/above which a day reaches the darkest shade. Default 60.
    static var darkestMinutes: Int {
        let value = UserDefaults.appGroup.integer(forKey: SettingsKeys.darkestMinutes)
        return value == 0 ? 60 : value
    }
}
