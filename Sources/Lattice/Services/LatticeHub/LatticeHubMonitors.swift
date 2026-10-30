// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Carbon.HIToolbox

extension LatticeHubService {
    func handlePanelKey(_ event: NSEvent,
                        flow: QuickToolsSupport.GridFlow = .rows(columns: LatticeHubService.columns)) -> NSEvent? {
        if stayAwakeOptionsPresented { return event }
        if event.keyCode == UInt16(kVK_Escape) {
            if (event.window?.firstResponder as? NSTextView)?.hasMarkedText() == true { return event }
            if activeUtility != nil {
                activeUtility = nil
            } else if editingOptionsItem != nil {
                editingOptionsItem = nil
            } else if isEditing {
                isEditing = false
            } else {
                hide()
            }
            return nil
        }
        guard !isEditing, activeUtility == nil,
              event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return event }
        switch Int(event.keyCode) {
        case kVK_Return, kVK_ANSI_KeypadEnter:
            activateSelection()
            return nil
        case kVK_LeftArrow:
            moveSelection(.left, flow: flow)
            return nil
        case kVK_RightArrow:
            moveSelection(.right, flow: flow)
            return nil
        case kVK_UpArrow:
            moveSelection(.up, flow: flow)
            return nil
        case kVK_DownArrow:
            moveSelection(.down, flow: flow)
            return nil
        default:
            if let index = Self.digitIndex(for: event.keyCode) {
                activate(at: index)
                return nil
            }
            return event
        }
    }

    func installMonitors(for panel: NSPanel) {
        removeMonitors()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak panel] event in
            guard let self, let panel, event.window === panel else { return event }
            return self.handlePanelKey(event)
        }
        let mouseEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseEvents) { [weak self, weak panel] event in
            guard let self, let panel, panel.isVisible, self.dismissesOnOutsideInteraction else { return event }
            if event.window !== panel, !Self.mouseIsInside(panel) {
                self.hide()
            }
            return event
        }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { [weak self, weak panel] event in
            guard let self, let panel, panel.isVisible, self.dismissesOnOutsideInteraction else { return }
            if event.windowNumber != panel.windowNumber, !Self.mouseIsInside(panel),
               !AssistiveKeyboard.ownsCocoaPoint(NSEvent.mouseLocation) {
                self.hide()
            }
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  self.dismissesOnOutsideInteraction,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier,
                  app.bundleIdentifier != AssistiveKeyboard.bundleID
            else { return }
            self.hide()
        }
    }

    func removeMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor); self.keyMonitor = nil }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor); self.localClickMonitor = nil }
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor); self.outsideClickMonitor = nil }
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
    }

    static func mouseIsInside(_ panel: NSPanel) -> Bool {
        panel.frame.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation)
    }

    static func digitIndex(for keyCode: UInt16) -> Int? {
        switch Int(keyCode) {
        case kVK_ANSI_1, kVK_ANSI_Keypad1: return 0
        case kVK_ANSI_2, kVK_ANSI_Keypad2: return 1
        case kVK_ANSI_3, kVK_ANSI_Keypad3: return 2
        case kVK_ANSI_4, kVK_ANSI_Keypad4: return 3
        case kVK_ANSI_5, kVK_ANSI_Keypad5: return 4
        case kVK_ANSI_6, kVK_ANSI_Keypad6: return 5
        case kVK_ANSI_7, kVK_ANSI_Keypad7: return 6
        case kVK_ANSI_8, kVK_ANSI_Keypad8: return 7
        case kVK_ANSI_9, kVK_ANSI_Keypad9: return 8
        default: return nil
        }
    }
}
