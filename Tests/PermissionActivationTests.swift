// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

enum PermissionActivationTests {
    static func run(_ suite: TestSuite) {
        coordinator(suite)
        selection(suite)
        var request = PermissionActivationRequest()
        let denied = request.begin()
        suite.expect(!request.resolve(denied, granted: false), "denied access never enables a feature")
        let allowed = request.begin()
        suite.expect(request.resolve(allowed, granted: true), "verified access completes the current enable request")
        suite.expect(!request.resolve(allowed, granted: true), "a completed request cannot enable a feature twice")
        let cancelled = request.begin()
        request.cancel()
        suite.expect(!request.resolve(cancelled, granted: true), "late permission after cancellation cannot enable a feature")
        let stale = request.begin()
        let latest = request.begin()
        suite.expect(!request.resolve(stale, granted: true), "an older permission callback cannot complete a newer request")
        suite.expect(request.resolve(latest, granted: true), "ignoring an obsolete callback preserves the current request")
    }

    private static func selection(_ suite: TestSuite) {
        var savedStep = "standard"
        var granted = false
        var callback: ((SettingsPermissionResult) -> Void)?
        let request = PermissionActivationCoordinator(requirements: [.accessibility], verify: { _ in granted },
            requestAccess: { _, answer in callback = answer },
            applyEnabled: { allowed in if allowed { savedStep = "quarter" } })
        request.setEnabled(true)
        suite.expect(savedStep == "standard", "a permission-requiring picker choice is not persisted optimistically")
        callback?(.denied)
        granted = true
        request.permissionStateChanged()
        suite.expect(savedStep == "standard", "denied key interception cannot stay armed for a later grant")
        request.setEnabled(true)
        suite.expect(savedStep == "quarter", "verified permission commits the requested key-step choice")
    }

    private static func coordinator(_ suite: TestSuite) {
        var granted: Set<SettingsPermission> = []
        var enabled = true // A stale saved/UI state must never count as verification.
        var callbacks: [(SettingsPermissionResult) -> Void] = []
        var requested: [SettingsPermission] = []
        let gate = PermissionActivationCoordinator(requirements: [.accessibility, .screenRecording],
            verify: { granted.contains($0) },
            requestAccess: { permission, callback in requested.append(permission); callbacks.append(callback) },
            applyEnabled: { enabled = $0 })
        gate.setEnabled(true)
        suite.expect(!enabled && requested == [.accessibility], "fresh denied verification overrides cached enabled state")
        callbacks[0](.denied)
        granted = [.accessibility, .screenRecording]
        gate.permissionStateChanged()
        suite.expect(!enabled, "denial without an app activation is terminal even if permission arrives later")

        granted = []
        gate.setEnabled(true)
        granted.insert(.accessibility)
        callbacks[1](.granted)
        suite.expect(!enabled && requested.last == .screenRecording, "required capabilities are requested sequentially")
        granted.insert(.screenRecording)
        callbacks[2](.granted)
        suite.expect(enabled, "all required permissions must pass fresh verification before enabling")

        granted = []
        gate.setEnabled(true)
        callbacks[3](.needsSettings)
        gate.returnedToApplication()
        granted = [.accessibility, .screenRecording]
        gate.permissionStateChanged()
        suite.expect(!enabled, "returning without a grant cancels the Settings round trip")

        granted = []
        gate.setEnabled(true)
        gate.setEnabled(false)
        granted = [.accessibility, .screenRecording]
        callbacks[4](.granted)
        suite.expect(!enabled, "disabling invalidates an outstanding platform callback")
    }
}
