import SwiftUI

/// Let the operating system supply the slider, including its Liquid Glass
/// appearance. Boost range/tint and keyboard editing stay native.
struct MixerVolumeSlider: View {
    @Binding var value: Double
    let normalTint: Color
    let boostTint: Color
    let isBoosting: Bool
    let accentRevision: Int
    let maximum: Double
    let accessibilityLabel: String

    var body: some View {
        SettingsValueSlider(title: accessibilityLabel, value: $value, range: 0...maximum,
            readout: "\(Int((value * 100).rounded()))%", usesSystemAppearance: true)
            .tint(isBoosting ? boostTint : normalTint)
            .id(accentRevision)
    }
}
