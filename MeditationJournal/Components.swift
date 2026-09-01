import SwiftUI

/// A compact metric tile used across the Insights screen.
struct StatTile: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(.tint)
            Text(value)
                .font(.title2.weight(.bold))
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// A titled rounded container for charts and grouped content.
struct Card<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18))
    }
}
