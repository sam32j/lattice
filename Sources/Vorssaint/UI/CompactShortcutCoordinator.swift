// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

@MainActor
final class CompactShortcutCoordinator: ObservableObject {
    static let shared = CompactShortcutCoordinator()

    @Published var activeRole: GlobalShortcutRole?
    @Published var activeTool: ScreenshotSupport.Tool?
    @Published var activeCustomID: String?
    private var exitObservers: [NSObjectProtocol] = []

    func startRecording(role: GlobalShortcutRole) {
        guard activeRole != role else { return }
        endCaptureIfNeeded()
        activeRole = role
        ShortcutCapture.begin()
        observeExits()
    }

    func startRecording(tool: ScreenshotSupport.Tool) {
        guard activeTool != tool else { return }
        endCaptureIfNeeded()
        activeTool = tool
        ShortcutCapture.begin()
        observeExits()
    }

    func startRecording(customID: String) {
        guard activeCustomID != customID else { return }
        endCaptureIfNeeded()
        activeCustomID = customID
        ShortcutCapture.begin()
        observeExits()
    }

    func stopRecording(role: GlobalShortcutRole? = nil) {
        guard role == nil ? activeRole != nil : activeRole == role else { return }
        stopRecordingAll()
    }

    func stopRecording(tool: ScreenshotSupport.Tool? = nil) {
        guard tool == nil ? activeTool != nil : activeTool == tool else { return }
        stopRecordingAll()
    }

    func stopRecording(customID: String) {
        guard activeCustomID == customID else { return }
        stopRecordingAll()
    }

    func stopRecordingAll() {
        guard hasActiveRecorder else { return }
        activeRole = nil
        activeTool = nil
        activeCustomID = nil
        ShortcutCapture.end()
        removeExits()
    }

    private var hasActiveRecorder: Bool {
        activeRole != nil || activeTool != nil || activeCustomID != nil
    }

    private func endCaptureIfNeeded() {
        if hasActiveRecorder { ShortcutCapture.end() }
        activeRole = nil
        activeTool = nil
        activeCustomID = nil
    }

    private func observeExits() {
        removeExits()
        let center = NotificationCenter.default
        exitObservers.append(center.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.stopRecordingAll() }
            })
        exitObservers.append(center.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.stopRecordingAll() }
            })
    }

    private func removeExits() {
        for observer in exitObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        exitObservers.removeAll()
    }
}
