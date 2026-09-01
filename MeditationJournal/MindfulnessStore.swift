import Foundation
import SwiftData
import WidgetKit
import Observation

/// The single source of truth for statistics across the app. It merges the
/// app's own logged sessions with mindful sessions from Apple Health (from
/// other apps/devices), exposes the combined list, and keeps the widget's
/// cached snapshot up to date.
@MainActor
@Observable
final class MindfulnessStore {
    /// Merged, de-duplicated entries from the local database + Apple Health.
    private(set) var entries: [MindfulEntry] = []
    private(set) var isLoading = false

    /// Re-reads both data sources and refreshes derived state + the widget.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        let context = ModelContext(PersistenceController.shared)
        let sessions = (try? context.fetch(FetchDescriptor<MeditationSession>())) ?? []
        let localEntries = sessions.map(\.entry)

        let healthEntries = await HealthKitManager.shared.readExternalMindfulSessions()

        entries = localEntries + healthEntries

        WidgetSnapshotStore.save(WidgetSnapshotStore.make(from: entries))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
