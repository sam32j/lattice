import AppKit
import SwiftUI

struct SettingsFeatureStatus {
    let color: Color
    let message: String
}

struct SettingsStatusDot: View {
    let status: SettingsFeatureStatus

    var body: some View {
        Circle().fill(status.color)
            .frame(width: 7, height: 7)
            .padding(7)
            .contentShape(Rectangle())
            .overlay { StatusTooltip(message: status.message) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(status.message)
    }
}

private struct StatusTooltip: NSViewRepresentable {
    let message: String
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) { view.toolTip = message }
}
