import SwiftUI

/// Top-level tab bar: the timer, insights (charts), and settings.
struct RootView: View {
    @State private var store = MindfulnessStore()
    @AppStorage(SettingsKeys.accentColor, store: .appGroup) private var accentID = AccentOption.teal.id

    var body: some View {
        TabView {
            TimerView()
                .tabItem { Label("Timer", systemImage: "timer") }

            StatisticsView()
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(AccentOption.option(for: accentID).deepColor)
        .environment(store)
        .task {
            // Ask for Health permission once, then merge in any existing data.
            await HealthKitManager.shared.requestAuthorization()
            await store.refresh()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(PersistenceController.shared)
}
