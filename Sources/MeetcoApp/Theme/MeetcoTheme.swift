import AppKit
import SwiftUI

public enum MeetcoTheme {
    public enum Spacing {
        public static let xSmall: CGFloat = 4
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 16
        public static let xLarge: CGFloat = 24
        public static let xxLarge: CGFloat = 32
    }

    public enum Radius {
        public static let control: CGFloat = 9
        public static let card: CGFloat = 14
        public static let hero: CGFloat = 20
        public static let sheet: CGFloat = 22
    }

    public static let canvas = adaptive(light: 0xF5F6F8, dark: 0x0D1015)
    public static let surface = adaptive(light: 0xFFFFFF, dark: 0x151A21)
    public static let surfaceMuted = adaptive(light: 0xEDEFF3, dark: 0x1D232C)
    public static let elevated = adaptive(light: 0xFFFFFF, dark: 0x1E252F)
    public static let textPrimary = adaptive(light: 0x111827, dark: 0xF2F4F8)
    public static let textSecondary = adaptive(light: 0x64707F, dark: 0x9AA4B2)
    public static let border = adaptive(light: 0xE4E7EC, dark: 0x2A323E)
    public static let accent = adaptive(light: 0x5E5CE6, dark: 0x8482FF)
    public static let accentDeep = adaptive(light: 0x4744C9, dark: 0x6C6AF2)
    public static let accentSoft = adaptive(light: 0xECEBFD, dark: 0x272A4E)
    public static let recording = adaptive(light: 0xE5484D, dark: 0xFF6369)
    public static let recordingDeep = adaptive(light: 0xC93A3F, dark: 0xE5484D)
    public static let success = adaptive(light: 0x188055, dark: 0x55C7A0)
    public static let warning = adaptive(light: 0xB26B14, dark: 0xE9AC59)
    public static let error = adaptive(light: 0xD92D20, dark: 0xFF7D86)

    public static let ink = adaptive(light: 0x14181F, dark: 0x0A0D12)
    public static let inkElevated = adaptive(light: 0x232B38, dark: 0x171D26)
    public static let inkText = adaptive(light: 0xF7F8FA, dark: 0xF7F8FA)
    public static let inkTextSecondary = adaptive(light: 0x9AA5B5, dark: 0x9AA5B5)
    public static let inkBorder = adaptive(light: 0x2E3846, dark: 0x232B36)

    /// Primary brand gradient used for filled accent controls and highlights.
    public static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Gradient for the destructive/recording call to action.
    public static var recordingGradient: LinearGradient {
        LinearGradient(
            colors: [recording, recordingDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Deep studio backdrop for hero surfaces, with a faint accent cast.
    public static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                adaptive(light: 0x1B2130, dark: 0x131926),
                adaptive(light: 0x111520, dark: 0x0B0E16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return nsColor(hex: isDark ? dark : light)
        })
    }

    private static func nsColor(hex: UInt32) -> NSColor {
        NSColor(
            calibratedRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

public extension Font {
    static let meetcoHero = Font.system(size: 32, weight: .bold)
    static let meetcoDisplay = Font.system(size: 27, weight: .bold)
    static let meetcoTitle = Font.system(size: 20, weight: .semibold)
    static let meetcoSection = Font.system(size: 15, weight: .semibold)
    static let meetcoBody = Font.system(size: 15)
    static let meetcoMetadata = Font.system(size: 12, weight: .medium)
    static let meetcoTimer = Font.system(size: 14, weight: .semibold, design: .monospaced)
}
