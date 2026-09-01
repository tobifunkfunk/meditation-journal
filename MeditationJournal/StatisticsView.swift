import SwiftUI
import Charts

/// The "Insights" tab. Computed over the merged data set (app logs + Apple
/// Health) exposed by `MindfulnessStore`. Compact cards, time shown in hours,
/// and the brand teal palette.
struct StatisticsView: View {
    @Environment(MindfulnessStore.self) private var store
    @AppStorage(SettingsKeys.streakMinMinutes, store: .appGroup) private var streakMinMinutes = 30
    @AppStorage(SettingsKeys.accentColor, store: .appGroup) private var accentID = AccentOption.teal.id
    @AppStorage(SettingsKeys.goldMinMinutes, store: .appGroup) private var goldMin = 120
    @AppStorage(SettingsKeys.heatmapDivisions, store: .appGroup) private var divisions = 5
    @AppStorage(SettingsKeys.darkestMinutes, store: .appGroup) private var darkestMin = 60
    @State private var selectedYear = Calendar.current.component(.year, from: .now)

    private var entries: [MindfulEntry] { store.entries }
    private var accentColor: Color { AccentOption.option(for: accentID).deepColor }

    /// Days covering the last five years for the heatmap.
    private var heatmapDays: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let start = cal.date(byAdding: .year, value: -5, to: today) ?? today
        return (cal.dateComponents([.day], from: start, to: today).day ?? 1825) + 1
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No data yet",
                        systemImage: "chart.bar",
                        description: Text("Finish a timer — or add mindful minutes in Apple Health — to see your insights.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            highlights
                            monthlyCard
                            yearlyCard
                            heatmapCard
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Insights")
        }
        .task { await store.refresh() }
    }

    // MARK: Highlights

    private var highlights: some View {
        HStack(spacing: 12) {
            StatTile(value: MeditationStats.formattedHours(entries), label: "Total time", symbol: "clock.fill")
            StatTile(value: "\(MeditationStats.currentStreak(entries, minMinutes: streakMinMinutes))", label: "Current streak", symbol: "flame.fill")
            StatTile(value: "\(MeditationStats.longestStreak(entries, minMinutes: streakMinMinutes))", label: "Longest streak", symbol: "trophy.fill")
        }
    }

    // MARK: Monthly

    private var monthlyCard: some View {
        Card {
            HStack {
                Text("By month")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    ForEach(MeditationStats.availableYears(entries), id: \.self) { year in
                        Button {
                            selectedYear = year
                        } label: {
                            if year == selectedYear {
                                Label(String(year), systemImage: "checkmark")
                            } else {
                                Text(verbatim: String(year))
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(verbatim: String(selectedYear))
                        Image(systemName: "chevron.up.chevron.down").font(.caption2)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                }
            }

            Chart(MeditationStats.monthlyMinutes(entries, year: selectedYear)) { month in
                BarMark(
                    x: .value("Month", month.date, unit: .month),
                    y: .value("Hours", hours(month.minutes))
                )
                .foregroundStyle(accentColor)
                .cornerRadius(4)
                .annotation(position: .top) {
                    if month.minutes > 0 {
                        Text("\(Int(hours(month.minutes).rounded()))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartYAxis { hoursAxis }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    // `centered` puts the letter under the middle of the bar,
                    // not at the month boundary (its left edge).
                    AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                }
            }
            .frame(height: 150)
        }
    }

    // MARK: Yearly

    private var yearlyCard: some View {
        Card("Last 5 years") {
            Chart(MeditationStats.yearlyMinutes(entries, years: 5)) { year in
                BarMark(
                    x: .value("Year", String(year.year)),
                    y: .value("Hours", hours(year.minutes))
                )
                .foregroundStyle(accentColor)
                .cornerRadius(4)
                .annotation(position: .top) {
                    if year.minutes > 0 {
                        Text(hoursLabel(year.minutes))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartYAxis { hoursAxis }
            .frame(height: 150)
        }
    }

    // MARK: Heatmap

    private var heatmapCard: some View {
        Card("Last 5 years") {
            // Rebuild when any heatmap-affecting setting changes so colours + legend refresh.
            HeatmapView(weeks: MeditationStats.heatmapWeeks(entries, days: heatmapDays),
                        divisions: divisions,
                        goldLabel: durationLabel(goldMin) + "+")
                .id("\(accentID)-\(goldMin)-\(divisions)-\(darkestMin)")
        }
    }

    // MARK: Formatting

    /// "45 min", "1h 30m", "2 h" — the actual meditation time.
    private func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h)h \(m)m"
    }

    private func hours(_ minutes: Int) -> Double { Double(minutes) / 60.0 }

    private func hoursLabel(_ minutes: Int) -> String {
        let h = Double(minutes) / 60.0
        return h < 10 ? String(format: "%.1fh", h) : "\(Int(h.rounded()))h"
    }

    private var hoursAxis: some AxisContent {
        AxisMarks { value in
            AxisGridLine()
            AxisValueLabel {
                if let h = value.as(Double.self) {
                    // Whole hours show as "2h"; fractional (little data) as "0.3h".
                    Text(h == h.rounded() ? "\(Int(h))h" : String(format: "%.1fh", h))
                }
            }
        }
    }
}

/// GitHub-style contribution grid. Scrolls horizontally over five years, opens
/// at the most recent week, and marks 2h+ days in gold.
private struct HeatmapView: View {
    let weeks: [[DayMinutes?]]
    var divisions: Int = 5
    var goldLabel: String = "2h+"

    private let cell: CGFloat = 14
    private let spacing: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: spacing) {
                        ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                            VStack(spacing: spacing) {
                                ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(day.map { Brand.dayColor(minutes: $0.minutes) } ?? .clear)
                                        .frame(width: cell, height: cell)
                                }
                            }
                            .id(index)
                        }
                    }
                    .padding(.vertical, 1)
                }
                .onAppear { proxy.scrollTo(weeks.count - 1, anchor: .trailing) }
            }

            legend
        }
    }

    private var legend: some View {
        HStack(spacing: 5) {
            Text("Less").font(.caption2).foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 2).fill(Brand.emptyDay).frame(width: 11, height: 11)
            ForEach(1...max(1, divisions), id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Brand.heat(Double(level) / Double(divisions)))
                    .frame(width: 11, height: 11)
            }
            Text("More").font(.caption2).foregroundStyle(.secondary)

            Spacer(minLength: 10)

            RoundedRectangle(cornerRadius: 2).fill(Brand.gold).frame(width: 11, height: 11)
            Text(goldLabel).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    StatisticsView()
        .environment(MindfulnessStore())
        .modelContainer(PersistenceController.shared)
}
