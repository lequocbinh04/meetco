import SwiftUI

/// Scrolling waveform of recent audio levels so the user can see at a glance
/// that a source is actually delivering signal while recording. A flat line
/// means silence; frozen bars mean the capture is paused.
public struct LiveWaveformView: View {
    private static let capacity = 40

    public let label: String
    public let level: Float
    public let systemImage: String
    public let isActive: Bool

    @State private var history: [Float] = Array(repeating: 0, count: capacity)
    private let ticks = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    public init(label: String, level: Float, systemImage: String, isActive: Bool) {
        self.label = label
        self.level = min(max(level, 0), 1)
        self.systemImage = systemImage
        self.isActive = isActive
    }

    public var body: some View {
        HStack(spacing: MeetcoTheme.Spacing.small) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(MeetcoTheme.textSecondary)

            HStack(spacing: 2) {
                ForEach(history.indices, id: \.self) { index in
                    Capsule()
                        .fill(barColor(history[index]))
                        .frame(width: 2.5, height: barHeight(history[index]))
                }
            }
            .frame(height: 24)
            .animation(nil, value: history)
        }
        .onReceive(ticks) { _ in
            guard isActive else { return }
            history.removeFirst()
            history.append(level)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) level, \(levelDescription)")
        .accessibilityValue("\(Int(level * 100)) percent")
    }

    private func barHeight(_ value: Float) -> CGFloat {
        2.5 + CGFloat(min(max(value, 0), 1)) * 21.5
    }

    private func barColor(_ value: Float) -> Color {
        if value > 0.9 { return MeetcoTheme.warning }
        return MeetcoTheme.accent.opacity(value < 0.02 ? 0.45 : 0.95)
    }

    private var levelDescription: String {
        switch level {
        case ..<0.12: "silent"
        case ..<0.4: "low"
        case ..<0.78: "medium"
        default: "high"
        }
    }
}
