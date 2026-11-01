// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

struct HubDragView: NSViewRepresentable {
    enum Destination: Equatable {
        case item(HubDragItem)
        case hiddenTray
        case scrollRegion
    }
    static let pasteboardType = NSPasteboard.PasteboardType("io.github.sam32j.lattice.hub-item")
    let destination: Destination
    let session: HubDragSession
    let isEnabled: Bool
    var horizontal = true
    var symbol = "square.grid.2x2"
    var onClick: () -> Void = {}

    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ view: DragView, context: Context) {
        view.configuration = self
        switch destination {
        case .item(let item): view.identifier = NSUserInterfaceItemIdentifier("hub-drag-\(item.identifier)")
        case .hiddenTray: view.identifier = NSUserInterfaceItemIdentifier("hub-hidden-tray")
        case .scrollRegion: view.identifier = NSUserInterfaceItemIdentifier("hub-scroll-region")
        }
    }

    static func dismantleNSView(_ view: DragView, coordinator: ()) {
        view.configuration = nil
    }

    final class DragView: NSView, NSDraggingSource {
        var configuration: HubDragView?
        private var start: CGPoint?
        private var activeSession: HubDragSession?

        override init(frame: NSRect) {
            super.init(frame: frame)
            registerForDraggedTypes([HubDragView.pasteboardType])
        }
        required init?(coder: NSCoder) { nil }
        override var isFlipped: Bool { true }
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let configuration, configuration.isEnabled else { return nil }
            if case .item = configuration.destination { return super.hitTest(point) }
            return configuration.session.active == nil ? nil : super.hitTest(point)
        }

        override func mouseDown(with event: NSEvent) { start = event.locationInWindow }
        override func mouseUp(with event: NSEvent) {
            if start != nil { configuration?.onClick() }
            start = nil
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start, let configuration, configuration.isEnabled,
                  case .item(let item) = configuration.destination,
                  hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y) >= 4 else { return }
            self.start = nil
            configuration.session.begin(item)
            guard configuration.session.active == item else { return }
            activeSession = configuration.session
            let pasteboard = NSPasteboardItem()
            pasteboard.setString(item.identifier, forType: HubDragView.pasteboardType)
            let dragging = NSDraggingItem(pasteboardWriter: pasteboard)
            let point = convert(start, from: nil)
            let icon = NSImage(systemSymbolName: configuration.symbol, accessibilityDescription: nil)
            dragging.setDraggingFrame(CGRect(x: point.x - 20, y: point.y - 20, width: 40, height: 40), contents: icon)
            beginDraggingSession(with: [dragging], event: event, source: self)
        }

        private func accepts(_ sender: NSDraggingInfo) -> Bool {
            guard let configuration, configuration.isEnabled,
                  let source = sender.draggingSource as? DragView,
                  source.activeSession === configuration.session,
                  let active = configuration.session.active,
                  sender.draggingSourceOperationMask.contains(.move),
                  sender.draggingPasteboard.string(forType: HubDragView.pasteboardType) == active.identifier else { return false }
            return true
        }

        private func target(_ sender: NSDraggingInfo) -> HubDropTarget? {
            guard let configuration, case .item(let item) = configuration.destination,
                  configuration.session.canMove(to: item) else { return nil }
            let point = convert(sender.draggingLocation, from: nil)
            guard bounds.contains(point) else { return nil }
            return HubDropTarget(item: item, after: configuration.horizontal ? point.x > bounds.midX : point.y > bounds.midY)
        }

        override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { draggingUpdated(sender) }
        override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
            guard accepts(sender), let configuration, let window else { return [] }
            configuration.session.scrolling.update(anchor: self,
                screenPoint: window.convertPoint(toScreen: sender.draggingLocation))
            switch configuration.destination {
            case .hiddenTray: configuration.session.pointToHiddenTray(true); return .move
            case .scrollRegion: configuration.session.point(to: nil); return .move
            case .item:
                let next = target(sender)
                configuration.session.point(to: next)
                return next == nil ? [] : .move
            }
        }

        override func draggingExited(_ sender: NSDraggingInfo?) {
            guard let configuration else { return }
            if case .hiddenTray = configuration.destination { configuration.session.pointToHiddenTray(false) }
            if case .item(let item) = configuration.destination, configuration.session.target?.item == item {
                configuration.session.point(to: nil)
            }
            configuration.session.scrolling.stop()
        }

        override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
            guard accepts(sender), let configuration else { return false }
            if case .hiddenTray = configuration.destination { return true }
            return target(sender) != nil
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            guard let configuration, configuration.isEnabled,
                  case .item = configuration.destination else { return nil }
            let menu = NSMenu()
            let title = FeatureStrings.hubCustomization(L10n.shared.language).hideFromHub
            let item = NSMenuItem(title: title, action: #selector(hideFromMenu), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
            return menu
        }

        @objc private func hideFromMenu() {
            guard let configuration, configuration.isEnabled,
                  case .item(let item) = configuration.destination else { return }
            configuration.session.begin(item)
            _ = configuration.session.hideActive()
        }

        override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            guard accepts(sender), let configuration else { return false }
            if case .hiddenTray = configuration.destination { return configuration.session.hideActive() }
            guard let target = target(sender) else { return false }
            return configuration.session.commit(to: target)
        }

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            context == .withinApplication ? .move : []
        }
        func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            activeSession?.cancel()
            activeSession = nil
        }
    }
}
