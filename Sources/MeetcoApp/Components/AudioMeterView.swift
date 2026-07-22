import SwiftUI

public struct AudioMeterView: View {
    public let label: String
    public let level: Float
    public let systemImage: String

    public init(label: String, level: Float, systemImage: String) {
        self.label = label
        self.level = min(max(level, 0), 1)
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: MeetcoTheme.Spacing.small) {
            Label(label, systemImage: systemImage)
                .font(.meetcoMetadata)
                .foregroundStyle(MeetcoTheme.textSecondary)
                .labelStyle(.iconOnly)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MeetcoTheme.border.opacity(0.6))
                    Capsule()
                        .fill(meterColor)
                        .frame(width: proxy.size.width * CGFloat(level))
                }
            }
            .frame(width: 64, height: 6)

            Text(label)
                .font(.meetcoMetadata)
                .foregroundStyle(MeetcoTheme.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) level, \(levelDescription)")
        .accessibilityValue("\(Int(level * 100)) percent")
    }

    private var meterColor: Color {
        level > 0.9 ? MeetcoTheme.warning : MeetcoTheme.accent
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
