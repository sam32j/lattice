// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

extension LatticeHubService {
    // MARK: - Presentation

    func toggle(forceFloating: Bool = false, anchoredBelow anchor: NSRect? = nil) {
        let now = ProcessInfo.processInfo.systemUptime
        if isVisible {
            hide()
            return
        }
        if now - lastDismissedTime < 0.35 {
            return
        }
        if !forceFloating && anchor == nil && shouldRouteToIsland() {
            if NotchService.shared.openQuickPanel(toggle: true) { return }
        }
        show(forceFloating: forceFloating, anchoredBelow: anchor)
    }

    func show(forceFloating: Bool = false, anchoredBelow anchor: NSRect? = nil,
              initialUtility: LatticeHubItem? = nil) {
        if !forceFloating && anchor == nil && initialUtility == nil && shouldRouteToIsland() {
            if NotchService.shared.openQuickPanel() {
                if isVisible { hide() }
                return
            }
        }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != ownPID {
            previousApp = front
        }
        (NSApp.delegate as? AppDelegate)?.closePopover()
        if NotchService.shared.expanded, NotchService.shared.selected == .hub {
            NotchService.shared.collapse()
        }
        // A collapse of an existing Island Hub can reset activeUtility
        // ("return to home" preference). Set the destination AFTER that
        // collapse but BEFORE creating/measuring/showing the floating panel.
        // The HUD therefore never renders the home page as an intermediate.
        if let initialUtility {
            guard initialUtility.isAvailable() else { return }
            opensUtilityDirectly = true
            activeUtility = initialUtility
        } else {
            opensUtilityDirectly = false
        }
        let panel = ensurePanel()
        prepareForPresentation()
        position(panel, anchoredBelow: anchor)
        installMonitors(for: panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.13
            panel.animator().alphaValue = 1
        }
    }

    /// Dedicated Recent Captures shortcut: use the existing floating
    /// Hub utility without showing/animating through its home page.
    /// Re-entering an already visible Hub switches pages immediately.
    func openRecentCaptures() {
        guard LatticeHubItem.recentCaptures.isAvailable() else { return }
        RecentCaptureService.shared.reload()
        if isVisible {
            opensUtilityDirectly = true
            activeUtility = .recentCaptures
            panel?.makeKey()
            return
        }
        show(forceFloating: true, initialUtility: .recentCaptures)
    }

    private func shouldRouteToIsland() -> Bool {
        guard NotchSupport.routesQuickPanel(),
              LauncherShortcutTarget.selected(in: .standard) == .automatic else {
            return false
        }
        return true
    }

    func prepareForPresentation() {
        // The Island owns hubIslandPage for its entire expanded session;
        // presenting the floating Hub must not reset its scroll position.
        refreshAvailability()
        presentationID = UUID()
        isEditing = false
        editingOptionsItem = nil
        isPinned = false
        selectedIndex = nil
        keyboardIndex = nil
        clearTypeahead()
    }

    func refreshAvailability() {
        if let activeUtility, !activeUtility.isAvailable() { self.activeUtility = nil }
        if let editingOptionsItem, !editingOptionsItem.isAvailable() { self.editingOptionsItem = nil }
        clampSelection()
    }

    func restorePreviousAppActivation() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let isLatticeFront = NSWorkspace.shared.frontmostApplication?.processIdentifier == ownPID
        let target = (previousApp != nil && !previousApp!.isTerminated && previousApp!.processIdentifier != ownPID)
            ? previousApp
            : nil
        previousApp = nil
        panel?.resignKey()
        if isLatticeFront, let target {
            ActivationHandoff.yield(to: target)
            target.activate()
        }
    }

    func hide() {
        opensUtilityDirectly = false
        panelResizer.cancel()
        lastDismissedTime = ProcessInfo.processInfo.systemUptime
        stayAwakeOptionsPresented = false
        removeMonitors()
        isEditing = false
        editingOptionsItem = nil
        SystemNavigationState.shared.reset()
        activeUtility = nil
        isPinned = false
        clearTypeahead()
        selectedIndex = nil
        keyboardIndex = nil
        restorePreviousAppActivation()
        panel?.orderOut(nil)
        presentationID = UUID()
    }

    func closeUtility() {
        opensUtilityDirectly = false
        SystemNavigationState.shared.reset()
        if isVisible {
            // Floating HUD drives its own crossfade; an implicit SwiftUI
            // animation here also animates layout and fights the panel resize.
            activeUtility = nil
        } else {
            // The Dynamic Island still uses its usual page transition.
            withAnimation(.easeInOut(duration: 0.22)) {
                activeUtility = nil
            }
        }
    }

    func refocusAfterModal() {
        if NotchService.shared.expanded, NotchService.shared.selected == .hub {
            NotchService.shared.presentationWindow?.makeKey(); return
        }
        guard let panel, panel.isVisible else { return }
        panel.makeKey()
    }

    var dismissesOnOutsideInteraction: Bool {
        !isPinned
    }

}
