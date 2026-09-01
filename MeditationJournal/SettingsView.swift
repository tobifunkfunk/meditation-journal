import SwiftUI
import WidgetKit

struct SettingsView: View {
    @Environment(MindfulnessStore.self) private var store

    @AppStorage(SettingsKeys.streakMinMinutes, store: .appGroup) private var streakMinMinutes = 30
    @AppStorage(SettingsKeys.accentColor, store: .appGroup) private var accentID = AccentOption.teal.id
    @AppStorage(SettingsKeys.goldMinMinutes, store: .appGroup) private var goldMinMinutes = 120
    @AppStorage(SettingsKeys.heatmapDivisions, store: .appGroup) private var divisions = 5
    @AppStorage(SettingsKeys.darkestMinutes, store: .appGroup) private var darkestMinutes = 60

    private var darkestOptions: [Int] { Array(stride(from: 30, through: 180, by: 10)) }
    // Gold can't be below the darkest threshold.
    private var goldOptions: [Int] { Array(stride(from: darkestMinutes, through: 240, by: 10)) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Daily goal", selection: $streakMinMinutes) {
                        ForEach([5, 10, 15, 20, 30, 45, 60], id: \.self) { minutes in
                            Text("\(minutes) min").tag(minutes)
                        }
                    }
                } header: {
                    Text("Streak")
                } footer: {
                    Text("A day counts toward your streak once you've meditated at least \(streakMinMinutes) minutes that day.")
                }

                Section {
                    Picker("Levels", selection: $divisions) {
                        ForEach(4...7, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    Picker("Darkest at", selection: $darkestMinutes) {
                        ForEach(darkestOptions, id: \.self) { minutes in
                            Text(durationLabel(minutes)).tag(minutes)
                        }
                    }
                    Picker("Golden from", selection: $goldMinMinutes) {
                        ForEach(goldOptions, id: \.self) { minutes in
                            Text(durationLabel(minutes)).tag(minutes)
                        }
                    }
                } header: {
                    Text("Heatmap")
                } footer: {
                    Text("The colour ramp has \(divisions) steps, reaching the darkest shade at \(durationLabel(darkestMinutes)). Days of \(durationLabel(goldMinMinutes)) or more are gold (never below the darkest threshold).")
                }

                Section("Accent color") {
                    accentPicker
                }
            }
            .navigationTitle("Settings")
            // The goal changes streaks (incl. the widget's precomputed max streak).
            .onChange(of: streakMinMinutes) {
                Task { await store.refresh() }
            }
            .onChange(of: accentID) {
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onChange(of: goldMinMinutes) {
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onChange(of: divisions) {
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onChange(of: darkestMinutes) {
                // Keep gold at or above the darkest threshold.
                if goldMinMinutes < darkestMinutes { goldMinMinutes = darkestMinutes }
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    /// "70 min", "90 min", "2 h" …
    private func durationLabel(_ minutes: Int) -> String {
        minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes) min"
    }

    private var accentPicker: some View {
        HStack(spacing: 16) {
            ForEach(AccentOption.all) { option in
                Button {
                    accentID = option.id
                } label: {
                    Circle()
                        .fill(option.deepColor)
                        .frame(width: 30, height: 30)
                        .overlay {
                            if option.id == accentID {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(
                            Circle().stroke(Color.primary.opacity(option.id == accentID ? 0.25 : 0), lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

}

#Preview {
    SettingsView()
        .environment(MindfulnessStore())
}
