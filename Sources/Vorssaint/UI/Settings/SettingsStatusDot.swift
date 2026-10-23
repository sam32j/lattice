import AppKit
import SwiftUI

struct SettingsFeatureStatus {
    let color: Color
    let message: String

    var symbolName: String? { color == .red ? "exclamationmark.circle" : nil }
    var symbolColor: Color { .red }
}

struct SettingsStatusDot: View {
    let status: SettingsFeatureStatus

    var body: some View {
        if let symbol = status.symbolName {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(status.symbolColor)
                .frame(width: 21, height: 21)
                .contentShape(Rectangle())
                .overlay { StatusTooltip(message: status.message) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(status.message)
        }
    }
}

struct StatusTooltip: NSViewRepresentable {
    let message: String
    func makeNSView(context: Context) -> HoverHintView { HoverHintView() }
    func updateNSView(_ view: HoverHintView, context: Context) {
        view.message = message
        view.toolTip = nil
    }
}

/// Local hover timing, without changing the system's tooltip preferences.
final class HoverHintView: NSView {
    var message = "" {
        didSet { if message != oldValue { dismissHint() } }
    }
    let hint = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                       backing: .buffered, defer: true)
    private var pending: Timer?
    private var deactivateObserver: NSObjectProtocol?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        hint.isReleasedWhenClosed = false
        hint.level = .popUpMenu
        hint.hasShadow = true
        hint.isOpaque = false
        hint.backgroundColor = .clear
        hint.ignoresMouseEvents = true
        hint.hidesOnDeactivate = true
        hint.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        deactivateObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.dismissHint() }
    }

    deinit {
        pending?.invalidate()
        if let deactivateObserver { NotificationCenter.default.removeObserver(deactivateObserver) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        pending?.invalidate()
        guard let anchorWindow = window else { return }
        let timer = Timer(timeInterval: 1, repeats: false) { [weak self, weak anchorWindow] _ in
            guard let self, let anchorWindow, self.window === anchorWindow,
                  anchorWindow.isVisible, !anchorWindow.isMiniaturized,
                  !self.message.isEmpty, !self.bounds.isEmpty else { return }
            let anchor = anchorWindow.convertToScreen(self.convert(self.bounds, to: nil))
            let screen = anchorWindow.screen?.visibleFrame ?? anchorWindow.frame
            let host = NSHostingView(rootView:
                Text(self.message).font(.callout).padding(10)
                    .frame(width: 280, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8)))
            let size = host.fittingSize
            host.sizingOptions = []
            self.hint.contentView = host
            self.hint.setFrame(Self.hintFrame(size: size, anchor: anchor, visibleFrame: screen), display: false)
            anchorWindow.addChildWindow(self.hint, ordered: .above)
            self.hint.orderFrontRegardless()
        }
        pending = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    override func mouseExited(with event: NSEvent) { dismissHint() }

    static func hintFrame(size: NSSize, anchor: NSRect, visibleFrame: NSRect) -> NSRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)
        let below = anchor.minY - height - 6
        let y = below >= visibleFrame.minY ? below : anchor.maxY + 6
        return NSRect(x: min(max(anchor.midX - width / 2, visibleFrame.minX), visibleFrame.maxX - width),
                      y: min(max(y, visibleFrame.minY), visibleFrame.maxY - height), width: width, height: height)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil { dismissHint() }
        super.viewWillMove(toWindow: newWindow)
    }

    private func dismissHint() {
        pending?.invalidate()
        pending = nil
        hint.parent?.removeChildWindow(hint)
        hint.orderOut(nil)
    }
}
