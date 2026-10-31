// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation
import SwiftUI

/// A session-scoped view of macOS Now Playing. The read itself lives in the
/// bridge below, out of process; a failed run, a timeout and malformed
/// metadata all arrive here as an empty playback session.
/// Nothing here is required for the radial menu itself to work.
final class RadialNowPlayingService {
    static let shared = RadialNowPlayingService()

    let bridge = MediaRemoteNowPlayingBridge()
    var generation = 0
    var state = RadialNowPlayingState.nothingPlaying
    var pendingPresentationAnchor: CGPoint?
    var panel: NSPanel?
    var eventMonitors: [Any] = []
    var activationObserver: NSObjectProtocol?

    init() {}

    func stop() {
        generation += 1
        bridge.cancel()
        dismissDetails()
        panel = nil
        state = .nothingPlaying
    }

    func refresh(update: @escaping (RadialNowPlayingState) -> Void) {
        guard AppFeature.radialMenu.isAvailable else { return }
        generation += 1
        let requestedGeneration = generation
        state = .loading
        update(.loading)
        bridge.fetch { [weak self] snapshot in
            DispatchQueue.main.async {
                guard let self, self.generation == requestedGeneration else { return }
                let nextState = snapshot.map(RadialNowPlayingState.playing) ?? .nothingPlaying
                self.state = nextState
                update(nextState)
                guard let anchor = self.pendingPresentationAnchor else { return }
                self.pendingPresentationAnchor = nil
                if case let .playing(snapshot) = nextState {
                    self.showCard(snapshot: snapshot, at: anchor)
                }
            }
        }
    }

    func presentDetails(at anchor: CGPoint) {
        guard AppFeature.radialMenu.isAvailable else { return }
        switch state {
        case let .playing(snapshot):
            showCard(snapshot: snapshot, at: anchor)
        case .loading:
            pendingPresentationAnchor = anchor
        case .nothingPlaying:
            break
        }
    }

    func dismissDetails() {
        pendingPresentationAnchor = nil
        removeMonitors()
        panel?.orderOut(nil)
    }

    func showCard(snapshot: RadialNowPlayingSnapshot, at anchor: CGPoint) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.showCard(snapshot: snapshot, at: anchor) }
            return
        }
        dismissDetails()
        let card = RadialNowPlayingCard(snapshot: snapshot) { [weak self] in
            self?.dismissDetails()
            RadialNowPlayingApplication.open(snapshot)
        }
        let host = NSHostingController(rootView: card)
        host.view.layoutSubtreeIfNeeded()
        let size = host.view.fittingSize
        let panel = ensurePanel()
        panel.contentViewController = host

        let visibleFrame = NSScreen.screens.first(where: { $0.frame.contains(anchor) })?.visibleFrame
            ?? NSScreen.pointerVisibleFrame
        let x = min(max(anchor.x - size.width / 2, visibleFrame.minX + 12),
                    visibleFrame.maxX - size.width - 12)
        let y = min(max(anchor.y - size.height / 2, visibleFrame.minY + 12),
                    visibleFrame.maxY - size.height - 12)
        panel.setFrame(NSRect(origin: CGPoint(x: x, y: y), size: size), display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
        installMonitors(for: panel)
    }

    func ensurePanel() -> NSPanel {
        if let panel { return panel }
        let panel = OverlayPanel(contentRect: .zero,
                                 styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered,
                                 defer: false)
        panel.title = "Now Playing"
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        self.panel = panel
        return panel
    }

    func installMonitors(for panel: NSPanel) {
        removeMonitors()
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: clicks, handler: { [weak self, weak panel] event in
            guard let self, let panel else { return event }
            if event.window !== panel { self.dismissDetails() }
            return event
        }) { eventMonitors.append(monitor) }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: clicks, handler: { [weak self] _ in
            DispatchQueue.main.async { self?.dismissDetails() }
        }) { eventMonitors.append(monitor) }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.dismissDetails()
        }
    }

    func removeMonitors() {
        eventMonitors.forEach { NSEvent.removeMonitor($0) }
        eventMonitors = []
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
    }
}
