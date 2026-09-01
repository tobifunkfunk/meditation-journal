import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline

struct MeditationEntry: TimelineEntry {
    let date: Date
    let todayMinutes: Int
    let goalMinutes: Int
    let last7Hours: Double
    let last30Hours: Double
    let yearHours: Int
    let streak: Int
    let maxStreak: Int
    let weeks: [[DayMinutes?]]   // heatmap columns (most recent last)
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> MeditationEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (MeditationEntry) -> Void) {
        completion(context.isPreview ? .sample : loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MeditationEntry>) -> Void) {
        let entry = loadEntry()
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func loadEntry() -> MeditationEntry {
        let goal = AppSettings.streakMinMinutes

        if let s = WidgetSnapshotStore.load() {
            let entries = s.days.map { MindfulEntry(date: $0.date, minutes: $0.minutes) }
            return makeEntry(entries: entries, yearMinutes: s.yearMinutes,
                             maxStreak: s.longestStreak, goal: goal)
        }

        let context = ModelContext(PersistenceController.shared)
        let sessions = (try? context.fetch(FetchDescriptor<MeditationSession>())) ?? []
        let entries = sessions.map(\.entry)
        return makeEntry(entries: entries,
                         yearMinutes: MeditationStats.minutesThisYear(entries),
                         maxStreak: MeditationStats.longestStreak(entries, minMinutes: goal),
                         goal: goal)
    }

    private func makeEntry(entries: [MindfulEntry], yearMinutes: Int, maxStreak: Int, goal: Int) -> MeditationEntry {
        MeditationEntry(
            date: .now,
            todayMinutes: MeditationStats.minutesToday(entries),
            goalMinutes: goal,
            last7Hours: Double(MeditationStats.minutesInLastDays(entries, days: 7)) / 60.0,
            last30Hours: Double(MeditationStats.minutesInLastDays(entries, days: 30)) / 60.0,
            yearHours: Int((Double(yearMinutes) / 60).rounded()),
            streak: MeditationStats.currentStreak(entries, minMinutes: goal),
            maxStreak: maxStreak,
            weeks: Array(MeditationStats.heatmapWeeks(entries, days: 90).suffix(12))
        )
    }
}

extension MeditationEntry {
    static var sample: MeditationEntry {
        let today = Calendar.current.startOfDay(for: .now)
        let entries = (0..<90).map { offset -> MindfulEntry in
            let day = Calendar.current.date(byAdding: .day, value: -offset, to: today)!
            return MindfulEntry(date: day, minutes: [0, 10, 0, 30, 130, 20, 0, 15][offset % 8])
        }
        return MeditationEntry(date: .now, todayMinutes: 18, goalMinutes: 30,
                               last7Hours: 1.5, last30Hours: 6.2, yearHours: 24,
                               streak: 4, maxStreak: 12,
                               weeks: Array(MeditationStats.heatmapWeeks(entries, days: 90).suffix(12)))
    }
}

// MARK: - Views

struct MeditationWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MeditationEntry

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

private struct SmallWidgetView: View {
    let entry: MeditationEntry
    private var goalReached: Bool { entry.todayMinutes >= entry.goalMinutes }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Meditation", systemImage: "leaf.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Brand.primary)
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(entry.streak)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Image(systemName: "flame.fill").foregroundStyle(.orange)
            }
            Text("day streak").font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text("\(entry.todayMinutes)/\(entry.goalMinutes) min today")
                .font(.caption2.weight(.medium))
                .foregroundStyle(goalReached ? Brand.primary : .secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MediumWidgetView: View {
    let entry: MeditationEntry

    // The heatmap squares. Each left-column line is forced to this same height
    // with `gap` spacing, so line N always sits next to heatmap row N.
    private let cell: CGFloat = 13
    private let gap: CGFloat = 2

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            // Seven equal-height lines matching the heatmap's row rhythm. The
            // 2nd line is intentionally blank. The column fills the space left
            // over by the heatmap, so bigger squares automatically tighten the
            // gap between label and value here.
            VStack(alignment: .leading, spacing: gap) {
                todayRow
                Color.clear.frame(height: cell)          // blank 2nd line
                statRow("Last 7 days", String(format: "%.1f h", entry.last7Hours))
                statRow("Last 30 days", String(format: "%.1f h", entry.last30Hours))
                statRow("This year", "\(entry.yearHours) h")
                statRow("Streak", days(entry.streak))
                statRow("Max streak", days(entry.maxStreak))
            }

            Heatmap(weeks: entry.weeks, cell: cell, spacing: gap)
        }
        // Vertically centered in the widget; left-aligned horizontally.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var todayRow: some View {
        HStack(spacing: 6) {
            Text("Today")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            // A square in today's heatmap colour, matching how it appears on the
            // grid. The thin border keeps an empty (0-min) day visible.
            RoundedRectangle(cornerRadius: 3)
                .fill(Brand.dayColor(minutes: entry.todayMinutes))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
                .frame(width: cell, height: cell)
            // Same colour as today's square (but readable when the day is empty).
            Text("\(entry.todayMinutes) min")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(entry.todayMinutes > 0 ? Brand.dayColor(minutes: entry.todayMinutes) : Color.secondary)
                .lineLimit(1)
        }
        .frame(height: cell)
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .frame(height: cell)
    }

    private func days(_ n: Int) -> String { "\(n) \(n == 1 ? "day" : "days")" }
}

/// Compact contribution grid for the medium widget. 2h+ days show gold.
private struct Heatmap: View {
    let weeks: [[DayMinutes?]]
    var cell: CGFloat = 12
    var spacing: CGFloat = 2

    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                VStack(spacing: spacing) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(day.map { Brand.dayColor(minutes: $0.minutes) } ?? .clear)
                            .frame(width: cell, height: cell)
                    }
                }
            }
        }
    }
}

// MARK: - Configuration

struct MeditationWidget: Widget {
    let kind = "MeditationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MeditationWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Meditation")
        .description("Your streak, minutes, and recent activity.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview("Medium", as: .systemMedium) {
    MeditationWidget()
} timeline: {
    MeditationEntry.sample
}
