import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RadialMenuColorPicker: View {
    @Binding var selection: RadialMenuColor
    let strings: RadialMenuFeatureStrings
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(RadialMenuColor.allCases) { color in
                Button {
                    selection = color
                } label: {
                    ZStack {
                        Circle()
                            .fill(color.color(for: colorScheme))
                            .frame(width: 16, height: 16)
                        if selection == color {
                            Circle()
                                .strokeBorder(Color.white.opacity(colorScheme == .light ? 0.9 : 0.8), lineWidth: 2)
                                .frame(width: 12, height: 12)
                            Circle()
                                .strokeBorder(color.color(for: colorScheme), lineWidth: 1.5)
                                .frame(width: 20, height: 20)
                        }
                    }
                    .frame(width: 22, height: 22)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(color.title(strings))
                .accessibilityLabel(color.title(strings))
            }
        }
    }
}

// MARK: - Profile Shortcut Row
