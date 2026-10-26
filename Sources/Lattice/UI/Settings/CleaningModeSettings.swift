import SwiftUI

struct CleaningModeSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var cleaning = CleaningModeManager.shared

    var body: some View {
        SettingsCard(title: l10n.s.cleaningMenuItem, headerAccessory: {
            Button(SettingsOrganizationStrings.text(.activateCleaning, l10n.language)) {
                cleaning.activate()
            }
            .disabled(cleaning.isActive)
        }) {
            ShortcutPreferenceRow(role: .cleaningMode, alignment: .center,
                label: l10n.language == .enUS ? "Activate cleaning mode with shortcut" : l10n.s.globalHotkeySection) {
                cleaning.syncWithPreferences()
                FeatureRuntime.shared.finishAvailabilityChange()
            }
        }
    }
}
