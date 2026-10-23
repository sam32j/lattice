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

struct StatusTooltip: NSViewRepresentable {
    let message: String
    func makeNSView(context: Context) -> HoverHintView { HoverHintView() }
    func updateNSView(_ view: HoverHintView, context: Context) {
        view.message = message
        if !view.hint.isShown { view.toolTip = message }
    }
}

/// Local hover timing, without changing the system's tooltip preferences.
final class HoverHintView: NSView {
    var message = ""
    let hint = NSPopover()
    private var pending: Timer?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        pending?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: false) { [weak self] _ in
            guard let self, self.window != nil, !self.message.isEmpty else { return }
            self.toolTip = nil
            self.hint.behavior = .transient
            self.hint.animates = false
            self.hint.contentViewController = NSHostingController(rootView:
                Text(self.message).font(.callout).padding(10)
                    .frame(width: 280, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true))
            self.hint.show(relativeTo: self.bounds, of: self, preferredEdge: .maxY)
        }
        pending = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    override func mouseExited(with event: NSEvent) { dismissHint() }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { dismissHint() }
        super.viewWillMove(toWindow: newWindow)
    }

    private func dismissHint() {
        pending?.invalidate()
        pending = nil
        hint.close()
        toolTip = message
    }
}
