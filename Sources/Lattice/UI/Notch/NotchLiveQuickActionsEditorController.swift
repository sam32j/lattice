// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The tools and Quick Access editor live in the real Dynamic Island. This
/// manager draws only the dimmed desktop BEHIND it, never a second island.
@MainActor
final class NotchLiveQuickActionsEditorController {
    static let shared = NotchLiveQuickActionsEditorController()
    private var backdropPanels: [OverlayPanel] = []

    private init() {}

    func show() {
        NotchService.shared.open(.hub, takeFocus: true)
        guard NotchService.shared.expanded, NotchService.shared.selected == .hub else { return }
        LatticeHubService.shared.activeUtility = nil
        LatticeHubService.shared.isEditing = true
        updateLiveBackdrop()
    }

    func updateLiveBackdrop() {
        let active = LatticeHubService.shared.isEditing
            && NotchService.shared.expanded && NotchService.shared.selected == .hub
        guard active else { dismiss(); return }
        guard backdropPanels.isEmpty else { return }
        for screen in NSScreen.screens {
            let backdrop = OverlayPanel(contentRect: screen.frame,
                                        styleMask: [.borderless, .nonactivatingPanel],
                                        backing: .buffered, defer: false)
            backdrop.isFloatingPanel = true
            backdrop.level = NSWindow.Level(rawValue: NotchPanel.normalLevel.rawValue - 1)
            backdrop.isOpaque = false
            backdrop.backgroundColor = .clear
            backdrop.hasShadow = false
            // Real island receives all editing gestures; the dimmer must never
            // steal their clicks, the Quick Access circles or external drags.
            backdrop.ignoresMouseEvents = true
            backdrop.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            let host = NSHostingView(rootView: Color.black.opacity(0.56).ignoresSafeArea())
            host.frame = NSRect(origin: .zero, size: screen.frame.size)
            host.autoresizingMask = [.width, .height]
            backdrop.contentView = host
            backdrop.orderFrontRegardless()
            backdropPanels.append(backdrop)
        }
    }

    func dismiss() {
        backdropPanels.forEach { $0.orderOut(nil) }
        backdropPanels.removeAll()
    }
}
