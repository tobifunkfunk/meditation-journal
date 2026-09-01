import SwiftUI

/// A selectable accent colour. Stored by `id` in the App Group so the app and
/// widget stay in sync.
struct AccentOption: Identifiable, Hashable {
    let id: String
    let label: String
    let r: Double
    let g: Double
    let b: Double

    /// How much darker the "deep" end of the ramp is than the base swatch.
    /// Shared with `Brand.heat` so the accent == the darkest heatmap square.
    static let deepFactor: Double = 0.80

    var color: Color { Color(red: r, green: g, blue: b) }

    /// The darkest shade of this accent's heatmap ramp. Used as THE app accent,
    /// so the tint matches the darkest heatmap square (one shade, not several).
    var deepColor: Color {
        Color(red: r * Self.deepFactor, green: g * Self.deepFactor, blue: b * Self.deepFactor)
    }

    static let teal   = AccentOption(id: "teal",   label: "Teal",   r: 0.13, g: 0.60, b: 0.53)
    static let blue   = AccentOption(id: "blue",   label: "Blue",   r: 0.16, g: 0.50, b: 0.85)
    static let indigo = AccentOption(id: "indigo", label: "Indigo", r: 0.36, g: 0.34, b: 0.82)
    static let purple = AccentOption(id: "purple", label: "Purple", r: 0.60, g: 0.32, b: 0.74)
    static let rose   = AccentOption(id: "rose",   label: "Rose",   r: 0.85, g: 0.30, b: 0.45)
    static let orange = AccentOption(id: "orange", label: "Orange", r: 0.90, g: 0.53, b: 0.16)

    static let all: [AccentOption] = [teal, blue, indigo, purple, rose, orange]

    static func option(for id: String?) -> AccentOption {
        all.first { $0.id == id } ?? teal
    }

    /// The currently selected accent, read from shared defaults.
    static var current: AccentOption {
        option(for: UserDefaults.appGroup.string(forKey: SettingsKeys.accentColor))
    }
}

/// The app's colour system. The accent is user-selectable; the heatmap "heat"
/// scale is derived from it so everything stays cohesive.
enum Brand {
    /// The app accent is the darkest shade of the heatmap ramp, so we don't end
    /// up with several near-identical shades of the same colour.
    static var primary: Color { AccentOption.current.deepColor }

    /// Fixed gold for "special" days (2h+) — a shiny highlight regardless of accent.
    static let gold = Color(red: 0.90, green: 0.71, blue: 0.22)

    /// A heat shade for `intensity` in 0…1: a pale tint of the accent → the
    /// accent's deep shade (`heat(1.0)` == `Brand.primary`).
    static func heat(_ intensity: Double) -> Color {
        let a = AccentOption.current
        let t = min(max(intensity, 0), 1)
        func channel(_ base: Double) -> Double {
            let pale = base + (1 - base) * 0.80          // near-white tint
            let deep = base * AccentOption.deepFactor    // == deepColor channel
            return pale + (deep - pale) * t
        }
        return Color(red: channel(a.r), green: channel(a.g), blue: channel(a.b))
    }

    static let emptyDay = Color.primary.opacity(0.07)

    /// The heatmap colour for a day given its total minutes.
    /// 0 → empty, then a quantised accent ramp up to `darkestMinutes`, gold beyond
    /// the gold threshold. The ramp has `heatmapDivisions` discrete steps.
    static func dayColor(minutes: Int) -> Color {
        if minutes <= 0 { return emptyDay }
        if minutes >= AppSettings.goldMinMinutes { return gold }
        let divisions = AppSettings.heatmapDivisions
        let fraction = min(Double(minutes) / Double(AppSettings.darkestMinutes), 1.0)
        let level = max(1, min(divisions, Int(ceil(fraction * Double(divisions)))))
        return heat(Double(level) / Double(divisions))
    }
}
