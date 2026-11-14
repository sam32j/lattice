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
    }
}
