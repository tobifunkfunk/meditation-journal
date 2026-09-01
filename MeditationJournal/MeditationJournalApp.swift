import SwiftUI

@main
struct MeditationJournalApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        // Shared App Group container so the widget sees the same data.
        .modelContainer(PersistenceController.shared)
    }
}
