import SwiftUI

public struct MeetcoCard<Content: View>: View {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    private let padding: CGFloat
    private let content: Content

    public init(
        padding: CGFloat = MeetcoTheme.Spacing.large,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MeetcoTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MeetcoTheme.Radius.card, style: .continuous)
                    .stroke(MeetcoTheme.border, lineWidth: contrast == .increased ? 2 : 1)
            }
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.045),
                radius: 10,
                x: 0,
                y: 3
            )
    }
}
