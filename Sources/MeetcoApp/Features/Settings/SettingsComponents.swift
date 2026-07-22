import SwiftUI

struct SettingsPage<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.large) {
                content
            }
            .padding(.horizontal, MeetcoTheme.Spacing.xxLarge)
            .padding(.vertical, MeetcoTheme.Spacing.xLarge)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(MeetcoTheme.canvas)
    }
}

struct SettingsPanel<Content: View>: View {
    let title: String
    let detail: String
    let systemImage: String
    private let content: Content

    init(
        _ title: String,
        detail: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        MeetcoCard {
            VStack(alignment: .leading, spacing: MeetcoTheme.Spacing.large) {
                HStack(spacing: MeetcoTheme.Spacing.medium) {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MeetcoTheme.accent)
                        .frame(width: 34, height: 34)
                        .background(MeetcoTheme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.meetcoSection)
                        Text(detail)
                            .font(.meetcoMetadata)
                            .foregroundStyle(MeetcoTheme.textSecondary)
                    }
                }
                Divider()
                content
            }
        }
    }
}

struct SettingsLabeledRow<Control: View>: View {
    let title: String
    let detail: String?
    private let control: Control

    init(
        _ title: String,
        detail: String? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        HStack(spacing: MeetcoTheme.Spacing.large) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.meetcoBody)
                if let detail {
                    Text(detail)
                        .font(.meetcoMetadata)
                        .foregroundStyle(MeetcoTheme.textSecondary)
                }
            }
            Spacer(minLength: MeetcoTheme.Spacing.large)
            control
        }
    }
}

struct MeetcoSettingsTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .padding(.horizontal, MeetcoTheme.Spacing.medium)
            .frame(minHeight: 38)
            .background(MeetcoTheme.surfaceMuted.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MeetcoTheme.Radius.control, style: .continuous)
                    .stroke(MeetcoTheme.border)
            }
    }
}
