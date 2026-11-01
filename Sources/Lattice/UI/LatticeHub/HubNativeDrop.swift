// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit

/// The system boundary is a value so the real native drop adapter can also be
/// exercised without synthesizing an operating-system mouse-button state.
struct HubNativeDragContext {
    let source: HubDragView.DragView?
    let identifier: String?
    let operations: NSDragOperation
    let location: CGPoint

    init(source: HubDragView.DragView?, identifier: String?, operations: NSDragOperation, location: CGPoint) {
        self.source = source; self.identifier = identifier; self.operations = operations; self.location = location
    }

    init(_ sender: NSDraggingInfo) {
        self.init(source: sender.draggingSource as? HubDragView.DragView,
            identifier: sender.draggingPasteboard.string(forType: HubDragView.pasteboardType),
            operations: sender.draggingSourceOperationMask, location: sender.draggingLocation)
    }
}

enum HubNativeDrop {
    private enum Target { case hidden, slot(Int) }

    private static func target(in view: HubDragView.DragView, context: HubNativeDragContext) -> Target? {
        guard let config = view.configuration, config.isEnabled,
              context.source?.activeSession === config.session,
              let active = config.session.active, context.operations.contains(.move),
              context.identifier == active.identifier else { return nil }
        let point = view.convert(context.location, from: nil)
        guard view.bounds.contains(point), view.visibleRect.contains(point) else { return nil }
        switch config.destination {
        case .hiddenTray: return .hidden
        case .tools:
            guard case .tool(let source) = active, config.toolItems.contains(source),
                  let layout = config.toolLayout, layout.frames.count == config.toolItems.count,
                  let index = layout.closestIndex(to: point, keeping: config.session.targetIndex) else { return nil }
            return .slot(index)
        case .item: return nil // Quick controls can be hidden, but cannot be reordered.
        }
    }

    static func update(in view: HubDragView.DragView, context: HubNativeDragContext) -> NSDragOperation {
        guard let target = target(in: view, context: context), let config = view.configuration else { return [] }
        switch target {
        case .hidden: config.session.pointToHiddenTray(true)
        case .slot(let index): config.session.point(toIndex: index)
        }
        if view.enclosingScrollView != nil, let window = view.window {
            let identifier = context.identifier
            let operations = context.operations
            config.session.scrolling.update(anchor: view, screenPoint: window.convertPoint(toScreen: context.location)) {
                [weak view, weak source = context.source] point in
                guard let view, let source else { return }
                _ = update(in: view, context: HubNativeDragContext(source: source,
                    identifier: identifier, operations: operations, location: point))
            }
        } else { config.session.scrolling.stop() }
        return .move
    }

    static func accepts(in view: HubDragView.DragView, context: HubNativeDragContext) -> Bool {
        target(in: view, context: context) != nil
    }

    static func perform(in view: HubDragView.DragView, context: HubNativeDragContext) -> Bool {
        guard let target = target(in: view, context: context), let session = view.configuration?.session else { return false }
        switch target {
        case .hidden: return session.hideActive()
        case .slot(let index): return session.commit(toIndex: index)
        }
    }

    static func exit(_ view: HubDragView.DragView) {
        guard let config = view.configuration else { return }
        switch config.destination {
        case .hiddenTray:
            if config.session.targetsHiddenTray { config.session.pointToHiddenTray(false) }
        case .tools:
            if !config.session.targetsHiddenTray { config.session.point(toIndex: nil) }
        case .item: break
        }
        config.session.scrolling.stop(ifAnchoredTo: view)
    }
}
