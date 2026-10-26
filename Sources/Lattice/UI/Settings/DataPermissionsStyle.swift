// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

enum DataSettingsTone { case neutral, granted, missing, destructive }
enum DataSettingsActionTone { case quiet, primary, outline, destructive }

/// Match the existing Settings colors and native controls in both appearances.
struct DataPermissionsPalette {
    let scheme: ColorScheme
    init(_ scheme: ColorScheme) { self.scheme = scheme }
    var page: Color { Color(nsColor: .textBackgroundColor) }
    var title: Color { .primary }
    var secondary: Color { .secondary }
    var divider: Color { Color.secondary.opacity(0.18) }
    var info: Color { .secondary }
    func foreground(_ tone: DataSettingsTone) -> Color {
        switch tone {
        case .neutral: return .secondary
        case .granted: return PanelMetricColor.green(for: scheme)
        case .missing: return PanelMetricColor.orange(for: scheme)
        case .destructive: return .red
        }
    }
    func tile(_ tone: DataSettingsTone) -> Color { foreground(tone).opacity(0.14) }
}

struct DataSettingsActionButton: View {
    let title: String
    var tone: DataSettingsActionTone = .quiet
    var accessibleName: String? = nil
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Group {
            if tone == .primary {
                control.buttonStyle(.borderedProminent)
            } else {
                control.buttonStyle(.bordered)
                    .foregroundStyle(tone == .destructive ? Color.red : Color.primary)
            }
        }
        .controlSize(.regular)
        .accessibilityLabel(accessibleName ?? title)
        .accessibilityIdentifier("data-permissions.action")
    }

    private var control: some View {
        Button(role: role, action: action) {
            Text(title).font(.body).lineLimit(1).minimumScaleFactor(0.8)
                .frame(width: 88)
        }
    }
}
