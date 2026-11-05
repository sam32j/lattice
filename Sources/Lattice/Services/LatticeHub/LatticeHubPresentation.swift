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
        let target = (previousApp != nil && !previousApp!.isTerminated && previousApp!.processIdentifier != ownPID)
            ? previousApp
            : NSWorkspace.shared.runningApplications.first(where: {
                $0.activationPolicy == .regular &&
                $0.processIdentifier != ownPID &&
                !$0.isTerminated &&
                !$0.isHidden
            })
        previousApp = nil
        panel?.resignKey()
        if (NSApp.delegate as? AppDelegate)?.settingsWindow?.isKeyWindow == true {
            (NSApp.delegate as? AppDelegate)?.settingsWindow?.resignKey()
        }
        if let target {
            NSApp.yieldActivation(to: target)
            target.activate()
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
