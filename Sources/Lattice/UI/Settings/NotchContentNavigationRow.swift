import SwiftUI

enum NotchContentDestination: Equatable {
    case module(NotchModule)
    case companion
}

struct NotchContentNavigationRow: View {
    let symbol: String
    let title: String
    let enabled: Bool
    let language: AppLanguage
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRow(symbol: symbol, title: title) {
                Label(SettingsContentStrings.status(enabled: enabled, language: language),
                      systemImage: enabled ? "checkmark.circle.fill" : "circle")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(enabled ? Color.green : Color.secondary)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(SettingsContentStrings.status(enabled: enabled, language: language))
    }
}
