import SwiftUI

struct MonitorModuleSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared

    var body: some View {
        SettingsCard(title: SettingsOrganizationStrings.text(.modules, l10n.language)) {
            ForEach(FeatureVisibilitySupport.monitorFeatures, id: \.self) { feature in
                SettingsRow(symbol: feature.symbolName,
                            title: feature.hubTitle(l10n.s, hub: FeatureStrings.hub(l10n.language))) {
                    Toggle(feature.hubTitle(l10n.s, hub: FeatureStrings.hub(l10n.language)),
                           isOn: Binding(get: { feature.isAvailable }, set: { enabled in
                        FeatureRuntime.shared.setAvailable([feature], enabled)
                    }))
                    .labelsHidden()
                    .disabled(!feature.isHardwareSupported && !feature.isAvailable)
                }
            }
        }
    }
}
