import SwiftUI

public enum MeetcoMotion {
    public static func micro(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.10) : .snappy(duration: 0.20, extraBounce: 0.05)
    }

    public static func panel(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .easeOut(duration: 0.26)
    }

    public static func replacement(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 4)),
            removal: .opacity
        )
    }
}

public struct MeetcoRecordingPulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var faded = false
    private let active: Bool

    public init(active: Bool) {
        self.active = active
    }

    public func body(content: Content) -> some View {
        content
            .opacity(active && faded ? 0.45 : 1)
            .onAppear { updatePulse() }
            .onChange(of: active) { _, _ in updatePulse() }
            .onChange(of: reduceMotion) { _, _ in updatePulse() }
    }

    private func updatePulse() {
        faded = false
        guard active, !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            faded = true
        }
    }
}

public extension View {
    func meetcoRecordingPulse(active: Bool) -> some View {
        modifier(MeetcoRecordingPulse(active: active))
    }
}
