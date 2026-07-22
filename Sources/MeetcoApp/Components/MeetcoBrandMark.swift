import AppKit
import SwiftUI

public struct MeetcoBrandMark: View {
    public let size: CGFloat

    public init(size: CGFloat = 44) {
        self.size = size
    }

    public var body: some View {
        Group {
            if let image = Self.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaleEffect(1.18)
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(MeetcoTheme.inkElevated)
            StudioWaveformView(color: MeetcoTheme.accent, spacing: 2)
                .scaleEffect(0.42)
            Circle()
                .fill(MeetcoTheme.recording)
                .frame(width: max(4, size * 0.1), height: max(4, size * 0.1))
                .offset(y: size * 0.29)
        }
    }

    private static let image: NSImage? = {
        guard let url = Bundle.main.url(forResource: "MeetcoAppIcon", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
    }()
}
