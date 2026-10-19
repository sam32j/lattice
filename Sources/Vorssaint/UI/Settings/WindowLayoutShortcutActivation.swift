import SwiftUI

/// A legacy paused group needs an explicit way to resume its saved bindings.
/// Never enable those bindings merely because Settings was opened.
struct WindowLayoutShortcutActivation: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.windowLayoutShortcutsEnabled) private var enabled = true

    var body: some View {
        if !enabled {
            HStack {
                Label(FeatureStrings.shortcuts(l10n.language).inactive, systemImage: "pause.circle")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(String(format: FeatureStrings.commandBar(l10n.language).turnOnFormat,
                              FeatureStrings.windowLayout(l10n.language).shortcuts)) {
                    enabled = true
                    WindowLayoutService.shared.syncWithPreferences()
                }
                .disabled(!permissions.accessibility)
            }
        }
    }
}
