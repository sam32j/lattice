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

/// One local drag owns transient feedback. Preferences are written only by
/// commit; hovering changes the visual insertion preview without saving it.
final class HubDragSession: ObservableObject {
    @Published private(set) var active: HubDragItem?
    @Published private(set) var targetsHiddenTray = false
    @Published private(set) var targetIndex: Int?
    let scrolling = HubDragScrolling()
    private let launcher: LatticeHubService
    private let now: () -> TimeInterval
    private let performHaptic: () -> Void
    private var feedbackIndex: Int?
    private var feedbackTime: TimeInterval?
    private var hideFeedbackTime: TimeInterval?

    init(launcher: LatticeHubService = .shared,
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         performHaptic: @escaping () -> Void = {
             guard NotchSupport.usesHapticFeedback() else { return }
             NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
         }) {
        self.launcher = launcher
        self.now = now
        self.performHaptic = performHaptic
    }

    func begin(_ item: HubDragItem) {
        cancel()
        guard launcher.isEditing, isVisible(item) else { return }
        active = item
    }

    func pointToHiddenTray(_ targeted: Bool) {
        if targeted, !targetsHiddenTray, active != nil {
            let time = now()
            if hideFeedbackTime.map({ time - $0 >= 0.12 }) ?? true {
                hideFeedbackTime = time
                feedbackTime = time
                performHaptic()
            }
        }
        if targetsHiddenTray != targeted { targetsHiddenTray = targeted }
        if targeted, targetIndex != nil { targetIndex = nil }
    }

    func point(toIndex index: Int?) {
        guard case .tool = active else { return }
        if targetIndex != index {
            if targetIndex != nil, let index { provideFeedback(for: index) }
            targetIndex = index
        }
        if index != nil, targetsHiddenTray { targetsHiddenTray = false }
    }

    @discardableResult func commit(toIndex index: Int) -> Bool {
        guard launcher.isEditing, case .tool(let item) = active,
              launcher.visibleItems.contains(item), launcher.visibleItems.indices.contains(index) else { return false }
        launcher.moveTool(item, toIndex: index)
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
        feedbackIndex = nil
        feedbackTime = nil
        hideFeedbackTime = nil
        if active != nil { active = nil }
        if targetsHiddenTray { targetsHiddenTray = false }
        if targetIndex != nil { targetIndex = nil }
    }

    private func provideFeedback(for next: Int) {
        guard feedbackIndex != next else { return }
        feedbackIndex = next
        let time = now()
        // Target jitter and crossing several tiles in one motion should feel
        // like one alignment. Visual feedback still updates on every slot.
        guard feedbackTime.map({ time - $0 >= 0.12 }) ?? true else { return }
        feedbackTime = time
        performHaptic()
    }

    private func isVisible(_ item: HubDragItem) -> Bool {
        switch item {
        case .tool(let item): return launcher.visibleItems.contains(item)
        case .control(let action): return launcher.visibleControls.contains(action)
        }
    }
}
