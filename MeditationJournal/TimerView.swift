import SwiftUI
import SwiftData

/// The main tab: a Zenitizer-style meditation timer. Setting the duration on a
/// dial, running a countdown with bells, and logging the finished session.
struct TimerView: View {
    @Environment(\.modelContext) private var context
    @Environment(MindfulnessStore.self) private var store

    @State private var engine = TimerEngine()
    @State private var minutes = 10

    // Persisted bell / behaviour settings (shared via the App Group).
    @AppStorage("timer_prep_seconds", store: .appGroup) private var prepSeconds = 10
    @AppStorage("timer_interval_min", store: .appGroup) private var intervalMinutes = 0
    @AppStorage("timer_start_bell", store: .appGroup) private var startBell = true
    @AppStorage("timer_end_bell", store: .appGroup) private var endBell = true
    // Re-render (recolour the dial/rings) when the accent changes.
    @AppStorage(SettingsKeys.accentColor, store: .appGroup) private var accentID = AccentOption.teal.id

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    Group {
                        if engine.isActive {
                            activeContent
                        } else {
                            setupContent
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    // Fill at least the viewport so the Spacers can spread the
                    // content down the screen instead of bunching at the top.
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationTitle("Timer")
        }
        .tint(AccentOption.option(for: accentID).deepColor)
        .onAppear {
            engine.onLog = logSession
        }
    }

    // MARK: Setup

    private var setupContent: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            CircularDial(minutes: $minutes, maxMinutes: 60)
                .frame(height: 280)
                .padding(.horizontal, 8)

            Button {
                startTimer()
            } label: {
                Label("Start Timer", systemImage: "play.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)

            Spacer(minLength: 0)

            bellSettings
        }
    }

    private var bellSettings: some View {
        VStack(spacing: 10) {
            settingRow(title: "Start Bell", icon: "bell.fill") {
                Menu(startBell ? "On" : "Off") {
                    Button("On") { startBell = true }
                    Button("Off") { startBell = false }
                }
            }
            settingRow(title: "Preparation", icon: "hourglass") {
                Menu(prepLabel) {
                    ForEach([0, 10, 30, 60, 120], id: \.self) { seconds in
                        Button(prepLabel(seconds)) { prepSeconds = seconds }
                    }
                }
            }
            settingRow(title: "Interval Bells", icon: "bell.badge.fill") {
                Menu(intervalMinutes == 0 ? "Off" : "\(intervalMinutes) Min") {
                    Button("Off") { intervalMinutes = 0 }
                    ForEach([1, 2, 3, 5, 10], id: \.self) { m in
                        Button("\(m) Min") { intervalMinutes = m }
                    }
                }
            }
            settingRow(title: "End Bell", icon: "bell.fill") {
                Menu(endBell ? "On" : "Off") {
                    Button("On") { endBell = true }
                    Button("Off") { endBell = false }
                }
            }
        }
    }

    private func settingRow<Trailing: View>(title: String, icon: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 26)
            Text(title)
            Spacer()
            trailing()
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.tint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Active

    private var activeContent: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.06), lineWidth: 18)
                Circle()
                    .trim(from: 0, to: engine.progress)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: engine.progress)

                VStack(spacing: 8) {
                    if engine.phase == .preparing {
                        Text("Get ready")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("\(engine.prepRemaining)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(.tint)
                    } else {
                        Text(timeString(engine.remainingSeconds))
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(.tint)
                            .contentTransition(.numericText())
                    }
                }
            }
            .frame(height: 300)
            .padding(.horizontal, 8)

            Button {
                engine.stop()
            } label: {
                Label("Stop Timer", systemImage: "stop.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .tint(.red)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)

            Spacer(minLength: 0)

            Card("Meditation") {
                Text("Let your breath flow naturally and focus on your experience in the present moment.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Actions & helpers

    private func startTimer() {
        let settings = TimerSettings(
            preparationSeconds: prepSeconds,
            intervalMinutes: intervalMinutes,
            startBell: startBell,
            endBell: endBell
        )
        engine.start(minutes: minutes, settings: settings)
    }

    private func logSession(start: Date, minutes: Int) {
        let session = MeditationSession(date: start, durationMinutes: minutes)
        context.insert(session)
        try? context.save()
        Task {
            await HealthKitManager.shared.saveMindfulSession(start: start, minutes: minutes)
            await store.refresh()
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private var prepLabel: String { prepLabel(prepSeconds) }

    private func prepLabel(_ seconds: Int) -> String {
        if seconds == 0 { return "Off" }
        if seconds < 60 { return "\(seconds) Sec" }
        return "\(seconds / 60) Min"
    }
}

#Preview {
    TimerView()
        .environment(MindfulnessStore())
        .modelContainer(PersistenceController.shared)
}
