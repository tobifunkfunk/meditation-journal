import Foundation
import SwiftData

enum AppGroup {
    /// Must match the App Group in both target entitlements files.
    static let identifier = "group.com.tobiasfunk.MeditationJournal"
}

/// The single SwiftData container used by both the app and the widget.
///
/// It stores the database inside the shared App Group container so the widget
/// (a separate process) reads exactly the same data the app writes. If the App
/// Group isn't available for some reason, it falls back to a normal on-device
/// store so the app still runs.
enum PersistenceController {
    static let shared: ModelContainer = {
        let schema = Schema([MeditationSession.self])

        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) != nil {
            let config = ModelConfiguration(schema: schema, groupContainer: .identifier(AppGroup.identifier))
            if let container = try? ModelContainer(for: schema, configurations: config) {
                return container
            }
        }

        // Fallback: default location (App Group not configured / unsigned build).
        return try! ModelContainer(for: schema)
    }()
}
