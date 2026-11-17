import SwiftUI

struct CleaningModeSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var cleaning = CleaningModeManager.shared

    var body: some View {
        SettingsCard(title: l10n.s.cleaningMenuItem) {
            ShortcutPreferenceRow(role: .cleaningMode, alignment: .center,
                label: SettingsOrganizationStrings.text(.cleaningShortcut, l10n.language)) {
                cleaning.syncWithPreferences()
                FeatureRuntime.shared.finishAvailabilityChange()
            }
        }
    }
}
