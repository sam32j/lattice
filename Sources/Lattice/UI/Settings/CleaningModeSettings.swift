import SwiftUI

struct CleaningModeSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var cleaning = CleaningModeManager.shared

    var body: some View {
        SettingsCard(symbol: "bubbles.and.sparkles", title: SettingsOrganizationStrings.text(.keyboardCleaningMode, l10n.language)) {
            ShortcutPreferenceRow(role: .cleaningMode, alignment: .center,
                label: SettingsOrganizationStrings.text(.cleaningShortcut, l10n.language)) {
                cleaning.syncWithPreferences()
                settingsFinishAvailabilityChange()
            }
            .padding(.leading, settingsRowTextInset)
        }
    }
}
