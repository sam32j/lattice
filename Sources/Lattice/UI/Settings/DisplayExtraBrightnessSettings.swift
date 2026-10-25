import SwiftUI

/// Display-owned preferences do not observe or construct the overlay service.
struct DisplayExtraBrightnessSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.extraBrightnessEnabled) private var enabled = false
    @AppStorage(DefaultsKey.extraBrightnessLevel) private var level = 100

    var body: some View {
        if AppFeature.extraBrightness.isPresentInControls() {
            VStack(alignment: .leading, spacing: 10) {
                SettingsRow(symbol: "sun.max.fill", title: l10n.s.extraBrightnessName,
                            caption: l10n.s.extraBrightnessCaption) {
                    Toggle(l10n.s.extraBrightnessName, isOn: $enabled)
                        .labelsHidden()
                        .onChange(of: enabled) { _, _ in FeatureRuntime.shared.sync([.extraBrightness]) }
                }
                HStack(spacing: 12) {
                        Text(l10n.s.extraBrightnessLevelLabel)
                        Slider(value: Binding(get: { Double(level) }, set: {
                            level = Int($0)
                            ExtraBrightnessService.shared.levelDidChange()
                        }), in: 10...100, step: 5)
                        Text("\(level)%")
                            .monospacedDigit().foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                }
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.5)
            }
            .settingsSectionAnchor(.extraBrightness, cornerRadius: 12)
        }
    }
}
