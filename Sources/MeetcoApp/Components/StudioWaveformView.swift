import SwiftUI

public struct StudioWaveformView: View {
    private let heights: [CGFloat] = [14, 28, 20, 42, 30, 54, 36, 24, 46, 31, 18, 39, 27, 16]
    public let color: Color
    public let spacing: CGFloat

    public init(color: Color = MeetcoTheme.accent, spacing: CGFloat = 5) {
        self.color = color
        self.spacing = spacing
    }

    public var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                Capsule()
                    .fill(color.opacity(index.isMultiple(of: 3) ? 1 : 0.56))
                    .frame(width: 3, height: height)
            }
        }
        .accessibilityHidden(true)
    }
}
