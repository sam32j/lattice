import SwiftUI

struct CleaningModeSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var cleaning = CleaningModeManager.shared

    var body: some View {
        SettingsCard(title: l10n.s.cleaningMenuItem, headerAccessory: {
            Button {
                cleaning.activate()
            } label: {
                Text(SettingsOrganizationStrings.text(.activateCleaning, l10n.language))
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
            }
            .frame(width: 140)
            .disabled(cleaning.isActive)
        }) {
            ShortcutPreferenceRow(role: .cleaningMode, alignment: .center,
                label: SettingsOrganizationStrings.text(.cleaningShortcut, l10n.language)) {
                cleaning.syncWithPreferences()
                FeatureRuntime.shared.finishAvailabilityChange()
            }
        }
    }
}
