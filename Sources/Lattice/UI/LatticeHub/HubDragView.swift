// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

struct HubDragView: NSViewRepresentable {
    enum Destination: Equatable {
        case item(HubDragItem)
        case tools
        case hiddenTray
    }
    static let pasteboardType = NSPasteboard.PasteboardType("io.github.sam32j.lattice.hub-item")
    let destination: Destination
    let session: HubDragSession
    let isEnabled: Bool
    var toolItems: [LatticeHubItem] = []
    var toolLayout: HubToolLayout?
    var onClick: () -> Void = {}
    var onToolTap: (LatticeHubItem) -> Void = { _ in }

    func makeNSView(context: Context) -> DragView { DragView(frame: .zero) }
    func updateNSView(_ view: DragView, context: Context) {
        view.configuration = self
        switch destination {
        case .item(let item): view.identifier = NSUserInterfaceItemIdentifier("hub-drag-\(item.identifier)")
        case .hiddenTray: view.identifier = NSUserInterfaceItemIdentifier("hub-hidden-tray")
        case .tools: view.identifier = NSUserInterfaceItemIdentifier("hub-tools-drag-surface")
        }
    }
    static func dismantleNSView(_ view: DragView, coordinator: ()) { view.configuration = nil }

    class DragView: NSView, NSDraggingSource {
        var configuration: HubDragView?
        private var press: NSEvent?
        private var menuItem: HubDragItem?
        private(set) var activeSession: HubDragSession?

        override init(frame: NSRect) {
            super.init(frame: frame)
            registerForDraggedTypes([HubDragView.pasteboardType])
        }
        required init?(coder: NSCoder) { nil }
        override var isFlipped: Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let config = configuration, config.isEnabled else { return nil }
            if case .hiddenTray = config.destination, config.session.active == nil { return nil }
            return super.hitTest(point)
        }

        func source(at point: CGPoint) -> (item: HubDragItem, rect: CGRect)? {
            guard let config = configuration, bounds.contains(point) else { return nil }
            switch config.destination {
            case .hiddenTray: return nil
            case .item(let item): return (item, bounds)
            case .tools:
                guard let layout = config.toolLayout, layout.frames.count == config.toolItems.count,
                      let index = layout.closestIndex(to: point) else { return nil }
                let rect = layout.frames[index]
                guard rect.contains(point) else { return nil }
                return (.tool(config.toolItems[index]), rect)
            }
        }

        override func mouseDown(with event: NSEvent) {
            guard activeSession == nil else { return }
            press = event
        }
        override func mouseUp(with event: NSEvent) {
            defer { press = nil }
            guard press != nil, let config = configuration,
                  let entry = source(at: convert(event.locationInWindow, from: nil)) else { return }
            if case .tools = config.destination, case .tool(let item) = entry.item { config.onToolTap(item) }
            else { config.onClick() }
        }

        /// The staging boundary used by mouseDragged and native adapter tests.
        /// All expensive drawing occurs here, once, before publishing drag state.
        func prepareDrag(at point: CGPoint) -> NSDraggingItem? {
            guard let config = configuration, config.isEnabled, activeSession == nil,
                  let entry = source(at: point) else { return nil }
            let radius: CGFloat
            if case .control = entry.item { radius = max(7, entry.rect.height * 0.28) }
            else { radius = 14 }
            guard let preview = HubTileDragPreview.image(in: self, rect: entry.rect, cornerRadius: radius) else { return nil }
            config.session.begin(entry.item)
            guard config.session.active == entry.item else { return nil }
            activeSession = config.session
            if case .tools = config.destination, case .tool(let item) = entry.item,
               let index = config.toolItems.firstIndex(of: item) { config.session.point(toIndex: index) }
            let pasteboard = NSPasteboardItem()
            pasteboard.setString(entry.item.identifier, forType: HubDragView.pasteboardType)
            let dragging = NSDraggingItem(pasteboardWriter: pasteboard)
            dragging.setDraggingFrame(entry.rect, contents: preview)
            return dragging
        }

        override func mouseDragged(with event: NSEvent) {
            guard let press, hypot(event.locationInWindow.x - press.locationInWindow.x,
                event.locationInWindow.y - press.locationInWindow.y) >= 4 else { return }
            self.press = nil
            guard let dragging = prepareDrag(at: convert(press.locationInWindow, from: nil)) else { NSSound.beep(); return }
            // AppKit derives the image hotspot from the original mouse-down.
            // Keep that event and the source rect paired, even after a delay.
            startNativeDrag(with: dragging, event: press)
        }

        /// The AppKit boundary, separate from staging the tile and its event.
        func startNativeDrag(with item: NSDraggingItem, event: NSEvent) {
            beginDraggingSession(with: [item], event: event, source: self)
        }

        override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { draggingUpdated(sender) }
        override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
            HubNativeDrop.update(in: self, context: HubNativeDragContext(sender))
        }
        override func draggingExited(_ sender: NSDraggingInfo?) { HubNativeDrop.exit(self) }
        override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
            HubNativeDrop.accepts(in: self, context: HubNativeDragContext(sender))
        }
        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            HubNativeDrop.perform(in: self, context: HubNativeDragContext(sender))
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            guard configuration?.isEnabled == true,
                  let entry = source(at: convert(event.locationInWindow, from: nil)) else { return nil }
            menuItem = entry.item
            let menu = NSMenu()
            let item = NSMenuItem(title: FeatureStrings.hubCustomization(L10n.shared.language).hideFromHub,
                                 action: #selector(hideFromMenu), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
            return menu
        }
        @objc private func hideFromMenu() {
            guard let config = configuration, config.isEnabled, let menuItem else { return }
            config.session.begin(menuItem)
            _ = config.session.hideActive()
        }
        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            context == .withinApplication ? .move : []
        }
        func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
        func finishDrag() {
            activeSession?.cancel()
            activeSession = nil
            press = nil
        }
        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) { finishDrag() }
    }
}
