import SwiftUI

/// A draggable circular duration picker. The knob sweeps clockwise from the top;
/// a full circle equals `maxMinutes`.
struct CircularDial: View {
    @Binding var minutes: Int
    var maxMinutes: Int = 60

    private let lineWidth: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = side / 2 - lineWidth / 2
            let fraction = Double(minutes) / Double(maxMinutes)

            ZStack {
                // Inset both rings by half the stroke so their centerline sits at
                // `radius` — the same circle the knob travels on.
                Circle()
                    .stroke(Color.primary.opacity(0.06), lineWidth: lineWidth)
                    .padding(lineWidth / 2)

                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(.tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(lineWidth / 2)

                Circle()
                    .fill(.background)
                    .overlay(Circle().stroke(.tint, lineWidth: 3))
                    .frame(width: lineWidth + 10, height: lineWidth + 10)
                    .position(knob(fraction: fraction, center: center, radius: radius))

                VStack(spacing: -2) {
                    Text("\(minutes)")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundStyle(.tint)
                        .contentTransition(.numericText())
                    Text("Min")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        update(location: value.location, center: center)
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func knob(fraction: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = fraction * 2 * Double.pi      // clockwise from top
        let r = Double(radius)
        return CGPoint(
            x: Double(center.x) + r * sin(angle),
            y: Double(center.y) - r * cos(angle)
        )
    }

    private func update(location: CGPoint, center: CGPoint) {
        let dx = Double(location.x - center.x)
        let dy = Double(location.y - center.y)
        var degrees = atan2(dx, -dy) * 180 / Double.pi  // 0 at top, clockwise
        if degrees < 0 { degrees += 360 }
        let newValue = Int((degrees / 360 * Double(maxMinutes)).rounded())
        minutes = min(max(newValue, 1), maxMinutes)
    }
}
