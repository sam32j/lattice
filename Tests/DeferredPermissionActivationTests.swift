// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum DeferredPermissionActivationTests {
    static func run(_ suite: TestSuite) {
        let domain = "io.github.sam32j.lattice.tests.deferred-permission.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }

        let now = Date()

        // 1. Initial state is empty
        suite.expect(DeferredPermissionActivation.pendingFeature(in: defaults, now: now) == nil,
                     "pendingFeature is nil when nothing is recorded")

        // 2. Record screenshot intent
        DeferredPermissionActivation.record(feature: .screenshot, in: defaults, now: now)
        suite.expect(DeferredPermissionActivation.pendingFeature(in: defaults, now: now) == .screenshot,
                     "pendingFeature returns the recorded feature immediately")

        // 3. Within expiration window (10 minutes later)
        let tenMinutesLater = now.addingTimeInterval(10 * 60)
        suite.expect(DeferredPermissionActivation.pendingFeature(in: defaults, now: tenMinutesLater) == .screenshot,
                     "pendingFeature still returns the feature within 15 minutes")

        // 4. Expired intent (16 minutes later)
        let sixteenMinutesLater = now.addingTimeInterval(16 * 60)
        suite.expect(DeferredPermissionActivation.pendingFeature(in: defaults, now: sixteenMinutesLater) == nil,
                     "pendingFeature returns nil when intent is older than 15 minutes")

        // 5. Clear removes pending intent
        DeferredPermissionActivation.record(feature: .screenRecorder, in: defaults, now: now)
        suite.expect(DeferredPermissionActivation.pendingFeature(in: defaults, now: now) == .screenRecorder,
                     "pendingFeature records screenRecorder")
        DeferredPermissionActivation.clear(in: defaults)
        suite.expect(DeferredPermissionActivation.pendingFeature(in: defaults, now: now) == nil,
                     "clear removes the pending intent")

        // 6. evaluateRecovery with granted permission
        DeferredPermissionActivation.record(feature: .screenshot, in: defaults, now: now)
        let grantedResult = DeferredPermissionActivation.evaluateRecovery(in: defaults, now: now) { perm in
            perm == .screenRecording
        }
        suite.expect(grantedResult == .screenshot,
                     "evaluateRecovery returns feature when screen recording is granted")
        suite.expect(DeferredPermissionActivation.pendingFeature(in: defaults, now: now) == nil,
                     "evaluateRecovery clears the pending intent upon evaluation")

        // 7. evaluateRecovery with denied/ungranted permission
        DeferredPermissionActivation.record(feature: .switcher, in: defaults, now: now)
        let deniedResult = DeferredPermissionActivation.evaluateRecovery(in: defaults, now: now) { _ in false }
        suite.expect(deniedResult == nil,
                     "evaluateRecovery returns nil when permission is not granted")
        suite.expect(DeferredPermissionActivation.pendingFeature(in: defaults, now: now) == nil,
                     "evaluateRecovery clears the pending intent even when not granted")

        // 8. evaluateRecovery when expired
        DeferredPermissionActivation.record(feature: .dockPreview, in: defaults, now: now)
        let expiredResult = DeferredPermissionActivation.evaluateRecovery(in: defaults, now: sixteenMinutesLater) { _ in true }
        suite.expect(expiredResult == nil,
                     "evaluateRecovery returns nil when pending intent has expired")
        suite.expect(DeferredPermissionActivation.pendingFeature(in: defaults, now: now) == nil,
                     "expired intent is cleared from defaults")
    }
}
