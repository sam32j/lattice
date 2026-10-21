// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// A nonactivating tool palette avoids SwiftUI popover focus transfers while
/// still allowing the number field, and only that field, to own keyboard input.
struct ScreenshotFontSizePalette: NSViewRepresentable {
    let presenter: Presenter
    @Binding var value: Int
    let title: String
    let onEditingChanged: (Bool) -> Void

    func makeNSView(context: Context) -> Anchor {
        let view = Anchor(); presenter.anchor = view; return view
    }
    func updateNSView(_ view: Anchor, context: Context) {
        presenter.anchor = view
        presenter.refresh(value: $value, title: title, onEditingChanged: onEditingChanged)
    }
    static func dismantleNSView(_ view: Anchor, coordinator: ()) {
        view.presenter?.close(restoreFocus: false)
    }
    final class Anchor: NSView {
        weak var presenter: Presenter?
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    final class Presenter: ObservableObject {
        weak var anchor: Anchor? { didSet { anchor?.presenter = self } }
        private weak var owner: NSWindow?
        private weak var text: NSTextView?
        private var panel: Panel?
        private var host: NSHostingView<Content>?
        private var monitor: Any?
        private var observers: [NSObjectProtocol] = []
        private var finishEditing: (() -> Void)?

        func toggle(value: Binding<Int>, title: String, onEditingChanged: @escaping (Bool) -> Void) {
            if panel != nil { close(); return }
            guard let anchor, let owner = anchor.window else { return }
            self.owner = owner
            text = (owner.firstResponder as? NSTextView).flatMap { $0.isFieldEditor ? nil : $0 }
            let rect = owner.convertToScreen(anchor.convert(anchor.bounds, to: nil))
            var frame = CGRect(x: rect.maxX + 8, y: rect.midY - 39, width: 228, height: 78)
            if let screen = owner.screen {
                let limits = screen.visibleFrame.insetBy(dx: 8, dy: 8)
                if frame.maxX > limits.maxX { frame.origin.x = rect.minX - frame.width - 8 }
                frame.origin.x = max(limits.minX, min(frame.minX, limits.maxX - frame.width))
                frame.origin.y = max(limits.minY, min(frame.minY, limits.maxY - frame.height))
            }
            let panel = Panel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                              backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.hidesOnDeactivate = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.level = owner.level
            panel.appearance = owner.effectiveAppearance
            panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
            self.panel = panel
            let background = NSVisualEffectView(frame: CGRect(origin: .zero, size: frame.size))
            background.material = .popover
            background.state = .active
            background.wantsLayer = true
            background.layer?.cornerRadius = 10
            background.layer?.masksToBounds = true
            panel.contentView = background
            let host = NSHostingView(rootView: content(value, title, onEditingChanged))
            host.frame = background.bounds
            host.autoresizingMask = [.width, .height]
            background.addSubview(host)
            self.host = host
            finishEditing = { onEditingChanged(false) }
            owner.addChildWindow(panel, ordered: .above)
            panel.orderFront(nil)
            installDismissal()
        }

        func refresh(value: Binding<Int>, title: String, onEditingChanged: @escaping (Bool) -> Void) {
            host?.rootView = content(value, title, onEditingChanged)
            if panel != nil { finishEditing = { onEditingChanged(false) } }
        }

        private func content(_ value: Binding<Int>, _ title: String, _ changed: @escaping (Bool) -> Void) -> Content {
            Content(value: value, title: title, numberChanged: changed, sliderChanged: { [weak self] active in
                if active { self?.restoreAnnotationFocus() }
                changed(active)
            })
        }

        private func restoreAnnotationFocus() {
            guard let text, text.isEditable, !text.isHidden else { return }
            owner?.makeKey()
            owner?.makeFirstResponder(text)
            text.updateInsertionPointStateAndRestartTimer(true)
        }

        private func installDismissal() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
                guard let self, let panel = self.panel else { return event }
                if event.type == .keyDown {
                    if event.keyCode == 53, event.window === panel || event.window === self.owner {
                        self.close(); return nil
                    }
                } else if event.window !== panel {
                    if let anchor = self.anchor, event.window === anchor.window,
                       anchor.bounds.contains(anchor.convert(event.locationInWindow, from: nil)) { return event }
                    self.close(restoreFocus: false)
                }
                return event
            }
            for name in [NSApplication.didResignActiveNotification, NSWindow.willCloseNotification] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: name == NSWindow.willCloseNotification ? owner : NSApp,
                    queue: .main) { [weak self] _ in self?.close(restoreFocus: false) })
            }
        }

        func close(restoreFocus: Bool = true) {
            guard let panel else { return }
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
            for observer in observers { NotificationCenter.default.removeObserver(observer) }
            observers.removeAll()
            panel.makeFirstResponder(nil)
            finishEditing?(); finishEditing = nil
            owner?.removeChildWindow(panel)
            panel.orderOut(nil)
            panel.contentView = nil
            panel.close()
            self.panel = nil
            host = nil
            if restoreFocus { restoreAnnotationFocus() }
            text = nil
            owner = nil
        }
        deinit { close(restoreFocus: false) }
    }

    final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }
    private struct Content: View {
        @Binding var value: Int
        let title: String
        let numberChanged: (Bool) -> Void
        let sliderChanged: (Bool) -> Void
        var body: some View {
            VStack(spacing: 10) {
                HStack {
                    Text(title).font(.system(size: 12, weight: .medium))
                    Spacer()
                    ScreenshotFontSizeField(value: $value, title: title, onEditingChanged: numberChanged)
                        .frame(width: 32, height: 20)
                        .overlay(alignment: .bottom) { Rectangle().fill(.secondary.opacity(0.4)).frame(height: 1) }
                    Text("pt").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                ScreenshotFontSizeSlider(value: $value, title: title, onEditingChanged: sliderChanged).frame(height: 20)
            }
            .padding(14)
        }
    }
}
