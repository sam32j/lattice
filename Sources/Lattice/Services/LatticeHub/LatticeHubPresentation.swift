// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

extension LatticeHubService {
    // MARK: - Presentation

    func toggle() {
        if isVisible {
            hide()
            return
        }
        if shouldRouteToIsland() {
            if NotchService.shared.openQuickPanel(toggle: true) { return }
        }
        show()
    }

    func show(anchoredBelow anchor: NSRect? = nil) {
        if anchor == nil && shouldRouteToIsland() {
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

    private func shouldRouteToIsland() -> Bool {
        guard LauncherShortcutTarget.selected(in: .standard) == .automatic,
              NotchSupport.routesQuickPanel() else {
            return false
        }
        return NSMouseInRect(NSEvent.mouseLocation, NotchService.shared.geometry.screen, false)
    }

    func prepareForPresentation() {
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
        if let currentFront = NSWorkspace.shared.frontmostApplication,
           currentFront.processIdentifier != ownPID {
            previousApp = nil
            return
        }
        guard let source = previousApp, !source.isTerminated else {
            previousApp = nil
            return
        }
        previousApp = nil
        ActivationHandoff.yield(to: source)
        if !source.activate(from: NSRunningApplication.current, options: []) {
            source.activate(options: [])
        }
        DispatchQueue.main.async {
            if !source.isTerminated {
                source.activate(options: [])
            }
        }
    }

    func hide() {
        stayAwakeOptionsPresented = false
        if NotchService.shared.expanded, NotchService.shared.selected == .hub { NotchService.shared.collapse() }
        removeMonitors()
        isEditing = false
        editingOptionsItem = nil
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
        activeUtility = nil
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
