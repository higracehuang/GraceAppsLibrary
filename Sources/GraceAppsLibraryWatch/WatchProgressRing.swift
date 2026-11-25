import SwiftUI

/// Reusable circular progress ring for Watch timers, goals, and counters.
public struct WatchProgressRing: View {
    private let progress: Double
    private let colors: [Color]
    private let lineWidth: CGFloat

    public init(
        progress: Double,
        colors: [Color] = [.accentColor],
        lineWidth: CGFloat = 10
    ) {
        self.progress = min(max(progress, 0), 1)
        self.colors = colors.isEmpty ? [.accentColor] : colors
        self.lineWidth = lineWidth
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(.tertiary.opacity(0.3), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: colors.count == 1 ? [colors[0], colors[0]] : colors,
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(), value: progress)
        }
    }
}
