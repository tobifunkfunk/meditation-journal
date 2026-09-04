import Foundation

/// A single mindfulness data point, regardless of where it came from (an
/// in-app log or an Apple Health sample).
struct MindfulEntry {
    let date: Date
    let minutes: Int
}

/// Pure statistics helpers shared by the Insights screen, the home summary
/// card, and the widget. No UI or storage here — just math over an array of
/// entries, so it's easy to test and reuse.
enum MeditationStats {

    static func totalMinutes(_ entries: [MindfulEntry]) -> Int {
        entries.reduce(0) { $0 + $1.minutes }
    }

    /// Total time expressed in hours, e.g. "12h" or "12.5h".
    static func formattedHours(_ entries: [MindfulEntry]) -> String {
        let minutes = totalMinutes(entries)
        if minutes % 60 == 0 { return "\(minutes / 60)h" }
        return String(format: "%.1fh", Double(minutes) / 60.0)
    }

    /// The distinct calendar days whose total minutes reach `minMinutes`.
    private static func activeDays(_ entries: [MindfulEntry], minMinutes: Int, _ calendar: Calendar) -> Set<Date> {
        var byDay: [Date: Int] = [:]
        for entry in entries {
            byDay[calendar.startOfDay(for: entry.date), default: 0] += entry.minutes
        }
        let threshold = max(1, minMinutes)
        return Set(byDay.filter { $0.value >= threshold }.keys)
    }

    /// Consecutive days (ending today or yesterday) that reach the daily goal.
    static func currentStreak(_ entries: [MindfulEntry], minMinutes: Int = 1, calendar: Calendar = .current) -> Int {
        let days = activeDays(entries, minMinutes: minMinutes, calendar)
        guard !days.isEmpty else { return 0 }

        var streak = 0
        var day = calendar.startOfDay(for: .now)

        // If today has no session yet, allow the streak to start at yesterday.
        if !days.contains(day) {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = prev
            if !days.contains(day) { return 0 }
        }

        while days.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    /// The longest run of consecutive days reaching the daily goal, over all history.
    static func longestStreak(_ entries: [MindfulEntry], minMinutes: Int = 1, calendar: Calendar = .current) -> Int {
        let days = activeDays(entries, minMinutes: minMinutes, calendar).sorted()
        guard !days.isEmpty else { return 0 }

        var longest = 1
        var run = 1
        for i in 1..<days.count {
            let expected = calendar.date(byAdding: .day, value: 1, to: days[i - 1])
            if let expected, calendar.isDate(expected, inSameDayAs: days[i]) {
                run += 1
                longest = max(longest, run)
            } else {
                run = 1
            }
        }
        return longest
    }

    static func minutesThisWeek(_ entries: [MindfulEntry], calendar: Calendar = .current) -> Int {
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        return entries.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.minutes }
    }

    static func minutesToday(_ entries: [MindfulEntry], calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: .now)
        return entries.filter { calendar.startOfDay(for: $0.date) == today }.reduce(0) { $0 + $1.minutes }
    }

    /// Total minutes over the last `days` days, including today.
    static func minutesInLastDays(_ entries: [MindfulEntry], days: Int, calendar: Calendar = .current) -> Int {
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: .now)) ?? .distantPast
        return entries.filter { $0.date >= start }.reduce(0) { $0 + $1.minutes }
    }

    static func minutesThisYear(_ entries: [MindfulEntry], calendar: Calendar = .current) -> Int {
        let year = calendar.component(.year, from: .now)
        return entries.filter { calendar.component(.year, from: $0.date) == year }.reduce(0) { $0 + $1.minutes }
    }

    static func minutesThisMonth(_ entries: [MindfulEntry], calendar: Calendar = .current) -> Int {
        periodTotals(entries, in: .month, calendar: calendar).minutes
    }

    /// Minutes in the current calendar period, plus how many of its days have
    /// elapsed (today counts), so averages don't look artificially low early on.
    private static func periodTotals(_ entries: [MindfulEntry], in component: Calendar.Component,
                                     calendar: Calendar) -> (minutes: Int, days: Int) {
        guard let start = calendar.dateInterval(of: component, for: .now)?.start else { return (0, 1) }
        let minutes = entries.filter { $0.date >= start }.reduce(0) { $0 + $1.minutes }
        let today = calendar.startOfDay(for: .now)
        let elapsed = (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: today).day ?? 0) + 1
        return (minutes, max(1, elapsed))
    }

    /// Average minutes per elapsed day in the current week / month / year.
    /// Pass `.weekOfYear`, `.month` or `.year`.
    static func dailyAverage(_ entries: [MindfulEntry], in component: Calendar.Component,
                             calendar: Calendar = .current) -> Int {
        let totals = periodTotals(entries, in: component, calendar: calendar)
        return Int((Double(totals.minutes) / Double(totals.days)).rounded())
    }

    /// Minutes per day for the last `days` days, oldest first. Empty days = 0.
    static func dailyMinutes(_ entries: [MindfulEntry], days: Int = 7, calendar: Calendar = .current) -> [DayMinutes] {
        let today = calendar.startOfDay(for: .now)
        var buckets: [Date: Int] = [:]
        for entry in entries {
            buckets[calendar.startOfDay(for: entry.date), default: 0] += entry.minutes
        }
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayMinutes(date: day, minutes: buckets[day] ?? 0)
        }
    }

    /// Minutes per month (Jan…Dec) for a given year.
    static func monthlyMinutes(_ entries: [MindfulEntry], year: Int, calendar: Calendar = .current) -> [MonthMinutes] {
        var buckets: [Int: Int] = [:]
        for entry in entries {
            let comps = calendar.dateComponents([.year, .month], from: entry.date)
            if comps.year == year, let month = comps.month {
                buckets[month, default: 0] += entry.minutes
            }
        }
        return (1...12).compactMap { month in
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return nil }
            return MonthMinutes(month: month, date: date, minutes: buckets[month] ?? 0)
        }
    }

    /// Minutes per year for the last `years` years, ending with the current year.
    static func yearlyMinutes(_ entries: [MindfulEntry], years: Int = 5, calendar: Calendar = .current) -> [YearMinutes] {
        let currentYear = calendar.component(.year, from: .now)
        var buckets: [Int: Int] = [:]
        for entry in entries {
            buckets[calendar.component(.year, from: entry.date), default: 0] += entry.minutes
        }
        return ((currentYear - years + 1)...currentYear).map { year in
            YearMinutes(year: year, minutes: buckets[year] ?? 0)
        }
    }

    /// Years that have any data, plus the current year, newest first — for the picker.
    static func availableYears(_ entries: [MindfulEntry], calendar: Calendar = .current) -> [Int] {
        var years = Set(entries.map { calendar.component(.year, from: $0.date) })
        years.insert(calendar.component(.year, from: .now))
        return years.sorted(by: >)
    }

    /// The last `days` days laid out as weeks (columns) of 7 weekday cells, for
    /// a GitHub-style heatmap. `nil` cells are padding before/after the range.
    static func heatmapWeeks(_ entries: [MindfulEntry], days: Int = 100, calendar: Calendar = .current) -> [[DayMinutes?]] {
        let daily = dailyMinutes(entries, days: days, calendar: calendar)
        guard let first = daily.first?.date else { return [] }

        // Pad the front so the first column starts on the calendar's first weekday.
        let leadingPad = (calendar.component(.weekday, from: first) - calendar.firstWeekday + 7) % 7
        var cells: [DayMinutes?] = Array(repeating: nil, count: leadingPad) + daily.map { Optional($0) }
        while cells.count % 7 != 0 { cells.append(nil) }

        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }
}

struct DayMinutes: Identifiable {
    var id: Date { date }
    let date: Date
    let minutes: Int
}

struct MonthMinutes: Identifiable {
    var id: Int { month }
    let month: Int
    let date: Date
    let minutes: Int
}

struct YearMinutes: Identifiable {
    var id: Int { year }
    let year: Int
    let minutes: Int
}
