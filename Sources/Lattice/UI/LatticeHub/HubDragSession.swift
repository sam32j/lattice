// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

enum HubDragItem: Equatable {
    case tool(LatticeHubItem)
    case control(HubControlAction)

    var identifier: String {
        switch self {
        case .tool(let item): return "tool:\(item.rawValue)"
        case .control(let action): return "control:\(action.rawValue)"
        }
    }
}

struct HubDropTarget: Equatable {
    let item: HubDragItem
    let after: Bool
}

/// One local drag owns transient feedback. Preferences are written only by
/// commit; hovering never mutates the order or moves the destination tiles.
final class HubDragSession: ObservableObject {
    @Published private(set) var active: HubDragItem?
    @Published private(set) var target: HubDropTarget?
    @Published private(set) var targetsHiddenTray = false
    let scrolling = HubDragScrolling()
    private let launcher: LatticeHubService

    init(launcher: LatticeHubService = .shared) { self.launcher = launcher }

    func begin(_ item: HubDragItem) {
        cancel()
        guard launcher.isEditing, isVisible(item) else { return }
        active = item
    }

    func canMove(to item: HubDragItem) -> Bool {
        guard launcher.isEditing, let active, active != item, isVisible(active), isVisible(item) else { return false }
        // Quick controls keep their established two-row grouping. They can be
        // dragged into the hidden tray; workflow tools can also be reordered.
        if case .tool = active, case .tool = item { return true }
        return false
    }

    func point(to next: HubDropTarget?) {
        if target != next {
            if next != nil, NotchSupport.usesHapticFeedback() {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            target = next
        }
        if targetsHiddenTray { targetsHiddenTray = false }
    }

    func pointToHiddenTray(_ targeted: Bool) {
        if targetsHiddenTray != targeted { targetsHiddenTray = targeted }
        if targeted, target != nil { target = nil }
    }

    @discardableResult func commit(to destination: HubDropTarget) -> Bool {
        guard canMove(to: destination.item), case .tool(let source) = active,
              case .tool(let target) = destination.item else { return false }
        launcher.moveTool(source, relativeTo: target, after: destination.after)
        cancel()
        return true
    }

    @discardableResult func hideActive() -> Bool {
        guard launcher.isEditing, let active, isVisible(active) else { return false }
        switch active {
        case .tool(let item): launcher.setHidden(item, true)
        case .control(let action): launcher.setControlHidden(action, true)
        }
        cancel()
        return true
    }

    func cancel() {
        scrolling.stop()
        if active != nil { active = nil }
        if target != nil { target = nil }
        if targetsHiddenTray { targetsHiddenTray = false }
    }

    private func isVisible(_ item: HubDragItem) -> Bool {
        switch item {
        case .tool(let item): return launcher.visibleItems.contains(item)
        case .control(let action): return launcher.visibleControls.contains(action)
        }
    }
}
