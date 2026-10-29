// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

final class NotchLiveEditorPanel: OverlayPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class NotchLiveQuickActionsEditorController: ObservableObject {
    static let shared = NotchLiveQuickActionsEditorController()

    private var panel: NotchLiveEditorPanel?
    private var backdropPanels: [OverlayPanel] = []
    private var keyMonitor: Any?

    private init() {}

    func show() {
        if panel != nil { dismiss() }

        NotchService.shared.collapse()

        let targetScreen = NSScreen.screens.first(where: { $0.frame == NotchService.shared.geometry.screen })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen = targetScreen else { return }

        for otherScreen in NSScreen.screens where otherScreen != screen {
            let backdrop = OverlayPanel(
                contentRect: otherScreen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            backdrop.isFloatingPanel = true
            backdrop.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
            backdrop.backgroundColor = .clear
            backdrop.isOpaque = false
            backdrop.hasShadow = false
            backdrop.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

            let host = NSHostingView(rootView: Color.black.opacity(0.6).ignoresSafeArea())
            host.frame = NSRect(origin: .zero, size: otherScreen.frame.size)
            host.autoresizingMask = [.width, .height]
            backdrop.contentView = host
            backdrop.orderFrontRegardless()
            backdropPanels.append(backdrop)
        }

        let mainPanel = NotchLiveEditorPanel(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        mainPanel.isFloatingPanel = true
        mainPanel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
        mainPanel.backgroundColor = .clear
        mainPanel.isOpaque = false
        mainPanel.hasShadow = false
        mainPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let editorView = NotchLiveQuickActionsEditorView(
            screenSize: screen.frame.size,
            onDone: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: editorView)
        hostingView.frame = NSRect(origin: .zero, size: screen.frame.size)
        hostingView.autoresizingMask = [.width, .height]
        mainPanel.contentView = hostingView

        self.panel = mainPanel

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.dismiss()
                return nil
            }
            return event
        }

        mainPanel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil

        backdropPanels.forEach { $0.orderOut(nil) }
        backdropPanels.removeAll()

        NotchService.shared.syncWithPreferences()
    }
}
