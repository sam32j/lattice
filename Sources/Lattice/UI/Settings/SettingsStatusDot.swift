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
    /// A click shows the hint at once, and a second click hides it.
    var opensOnClick = false
    /// For panels that show while another app is active, such as the HUD.
    var showsInInactiveApp = false
    func makeNSView(context: Context) -> HoverHintView {
        HoverHintView(opensOnClick: opensOnClick, showsInInactiveApp: showsInInactiveApp)
    }
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
    private let opensOnClick: Bool
    private let showsInInactiveApp: Bool

    convenience override init(frame frameRect: NSRect) {
        self.init(frame: frameRect, opensOnClick: false, showsInInactiveApp: false)
    }

    init(frame frameRect: NSRect = .zero, opensOnClick: Bool, showsInInactiveApp: Bool) {
        self.opensOnClick = opensOnClick
        self.showsInInactiveApp = showsInInactiveApp
        super.init(frame: frameRect)
        hint.isReleasedWhenClosed = false
        hint.level = .popUpMenu
        hint.hasShadow = true
        hint.isOpaque = false
        hint.backgroundColor = .clear
        hint.ignoresMouseEvents = true
        hint.hidesOnDeactivate = !showsInInactiveApp
        hint.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        guard !showsInInactiveApp else { return }
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
        // inVisibleRect follows layout automatically. Replacing the area while
        // hovered synthesizes exits and makes the information hint flash closed.
        guard trackingAreas.isEmpty else { return }
        addTrackingArea(NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, showsInInactiveApp ? .activeAlways : .activeInActiveApp, .inVisibleRect],
            owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        pending?.invalidate()
        guard window != nil else { return }
        let timer = Timer(timeInterval: 1, repeats: false) { [weak self] _ in self?.showHint() }
        pending = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    override func mouseDown(with event: NSEvent) {
        guard opensOnClick else { return super.mouseDown(with: event) }
        if hint.isVisible { dismissHint() } else { showHint() }
    }

    private func showHint() {
        pending?.invalidate()
        pending = nil
        guard let anchorWindow = window, anchorWindow.isVisible, !anchorWindow.isMiniaturized,
              !message.isEmpty, !bounds.isEmpty else { return }
        let anchor = anchorWindow.convertToScreen(convert(bounds, to: nil))
        let screen = anchorWindow.screen?.visibleFrame ?? anchorWindow.frame
        let host = NSHostingView(rootView: Bubble(message: message))
        let size = host.fittingSize
        host.sizingOptions = []
        hint.contentView = host
        hint.setFrame(Self.hintFrame(size: size, anchor: anchor, visibleFrame: screen), display: false)
        anchorWindow.addChildWindow(hint, ordered: .above)
        hint.orderFrontRegardless()
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

    /// The hint's bubble: Liquid Glass on macOS 26, the regular material before.
    private struct Bubble: View {
        let message: String
        @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

        var body: some View {
            let text = Text(message).font(.callout).padding(10)
                .frame(width: 280, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
#if compiler(>=6.2)
            if #available(macOS 26.0, *), !reduceTransparency {
                text.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                text.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
#else
            text.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
#endif
        }
    }
}

