import Foundation

/// A compact, pre-computed rollup the app writes to the shared App Group after
/// each refresh. The widget renders this instead of querying Apple Health
/// itself, so the widget stays consistent with the app without needing Health
/// access of its own.
struct StatsSnapshot: Codable {
    let totalMinutes: Int
    let totalSessions: Int
    /// Minutes accumulated since Jan 1 (the `days` array may not reach that far back).
    let yearMinutes: Int
    /// All-time longest streak, precomputed here because `days` is a short window.
    let longestStreak: Int
    /// Per-day minutes, oldest first, covering enough history for the widget.
    let days: [SnapshotDay]
}

struct SnapshotDay: Codable {
    let date: Date
    let minutes: Int
}

enum WidgetSnapshotStore {
    private static let key = "stats_snapshot_v1"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: AppGroup.identifier) }

    static func save(_ snapshot: StatsSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    static func load() -> StatsSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(StatsSnapshot.self, from: data)
    }

    /// Rebuilds a snapshot from merged entries.
    static func make(from entries: [MindfulEntry]) -> StatsSnapshot {
        let days = MeditationStats.dailyMinutes(entries, days: 140)
            .map { SnapshotDay(date: $0.date, minutes: $0.minutes) }
        return StatsSnapshot(
            totalMinutes: MeditationStats.totalMinutes(entries),
            totalSessions: entries.count,
            yearMinutes: MeditationStats.minutesThisYear(entries),
            longestStreak: MeditationStats.longestStreak(entries, minMinutes: AppSettings.streakMinMinutes),
            days: days
        )
    }
}
