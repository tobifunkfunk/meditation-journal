import Foundation
import SwiftData

/// One logged meditation sitting. SwiftData stores these on the device
/// (in a shared App Group container so the widget can read them too).
@Model
final class MeditationSession {
    var date: Date
    var durationMinutes: Int
    var note: String

    init(date: Date = .now, durationMinutes: Int = 10, note: String = "") {
        self.date = date
        self.durationMinutes = durationMinutes
        self.note = note
    }
}

extension MeditationSession {
    /// A lightweight value used by the stats layer, which treats app logs and
    /// Apple Health sessions uniformly.
    var entry: MindfulEntry {
        MindfulEntry(date: date, minutes: durationMinutes)
    }
}
