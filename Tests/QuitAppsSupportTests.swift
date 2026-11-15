// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Targeting rules for the Command Bar's Quit All Apps actions.
enum QuitAppsSupportTests {
    static func run(_ suite: TestSuite) {
        func app(_ pid: Int32, _ bundleID: String?, policy: Int = QuitAppsSupport.regularActivationPolicy,
                 terminated: Bool = false) -> QuitAppsCandidate {
            QuitAppsCandidate(pid: pid, name: bundleID ?? "", bundleIdentifier: bundleID,
                              activationPolicyRawValue: policy, isTerminated: terminated)
        }
        let running = [
            app(1, "com.apple.Safari"), app(2, "com.apple.mail"), app(3, "com.apple.finder"),
            app(4, "com.apple.mobilephone"), app(5, DownstreamIdentity.bundleID),
            app(6, DownstreamIdentity.bundleID + ".dev"), app(7, "com.example.agent", policy: 1),
            app(8, nil), app(9, "com.example.gone", terminated: true),
        ]
        suite.expect(QuitAppsSupport.batchQuitTargets(running, keepingPID: nil).map(\.pid) == [1, 2],
                     "quit all asks only regular apps, keeping Finder, Phone and Lattice")
        suite.expect(QuitAppsSupport.batchQuitTargets(running, keepingPID: 1).map(\.pid) == [2],
                     "quit others also keeps the front app")
        suite.expect(QuitAppsSupport.batchQuitTargets(running, exceptions: [], keepingPID: nil).map(\.pid) == [1, 2, 3, 4],
                     "Lattice never quits itself even without kept apps")

        // Kill Process's Keep Running list.
        let defaults = UserDefaults(suiteName: "io.github.sam32j.lattice.tests.quit-apps")!
        defaults.removePersistentDomain(forName: "io.github.sam32j.lattice.tests.quit-apps")
        defer { defaults.removePersistentDomain(forName: "io.github.sam32j.lattice.tests.quit-apps") }
        QuitAppsSupport.setKeepRunning(true, bundleIdentifier: "com.apple.mail", in: defaults)
        QuitAppsSupport.setKeepRunning(true, bundleIdentifier: "com.apple.finder", in: defaults)
        let kept = QuitAppsSupport.keepRunning(in: defaults)
        suite.expect(kept == ["com.apple.mail"],
                     "Keep Running stores chosen apps but never the always-kept pair")
        suite.expect(QuitAppsSupport.batchQuitTargets(
            running, exceptions: QuitAppsSupport.batchExceptions(keepRunning: kept), keepingPID: nil).map(\.pid) == [1],
                     "Quit All spares apps on the Keep Running list")
        QuitAppsSupport.setKeepRunning(false, bundleIdentifier: "com.apple.mail", in: defaults)
        suite.expect(QuitAppsSupport.keepRunning(in: defaults).isEmpty,
                     "an app can be taken off the Keep Running list")
        suite.expect(QuitAppsSupport.isAlwaysKept("com.apple.mobilephone")
                     && QuitAppsSupport.isAlwaysKept(DownstreamIdentity.bundleID)
                     && !QuitAppsSupport.isAlwaysKept("com.apple.Safari"),
                     "Finder, Phone and Lattice are always kept; other apps are not")
    }
}
