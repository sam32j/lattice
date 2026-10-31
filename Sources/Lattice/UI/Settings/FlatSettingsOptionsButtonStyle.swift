import SwiftUI

/// A full click target without a toolbar, hover, or pressed-state backdrop.
struct FlatSettingsOptionsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        OptionsButton(configuration: configuration)
    }

    private struct OptionsButton: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                .opacity(isEnabled ? (configuration.isPressed ? 0.65 : 1) : 0.45)
        }
    }
}
