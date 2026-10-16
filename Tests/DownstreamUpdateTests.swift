// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum DownstreamUpdateTests {
    static func run(_ suite: TestSuite) {
        let dmg = URL(string: "https://github.com/sam32j/vorssaint-utils/releases/download/v3.4.1-d.2/Lattice.dmg")!
        let releases = ["v3.4.1-d.2", "v3.4.1-d.10", "v3.5.0", "v3.5.0-beta.1"].map {
            UpdateServiceSupport.ReleaseCandidate(tagName: $0, isPrerelease: false,
                isDraft: false, dmgURL: dmg, dmgExpectedBytes: 100, body: nil)
        }
        let selected = UpdateServiceSupport.selectUpdate(from: releases,
            currentVersion: "3.4.1-d.1", includeBetas: false)
        suite.expect(selected?.tagName == "v3.4.1-d.10",
            "stable Lattice updates select the highest downstream revision and ignore upstream-only tags")
        suite.expect(UpdateServiceSupport.isNewer("3.4.2-d.1", than: "3.4.1-d.10"),
            "a new upstream patch outranks all downstream revisions of the old patch")
        suite.expect(DownstreamIdentity.requirements(teamID: "") == nil
            && DownstreamIdentity.requirements(teamID: "3D485NHW29") == nil
            && DownstreamIdentity.requirements(teamID: "BAD'INJECT") == nil,
            "unconfigured, upstream and malformed signing identities cannot authorize a Lattice update")
        let trust = DownstreamIdentity.requirements(teamID: "ABC123DE45")
        suite.expect(trust?.app.contains("identifier \"io.github.sam32j.lattice\"") == true
            && trust?.app.contains("ABC123DE45") == true
            && trust?.dmg.contains("anchor apple generic") == true,
            "Lattice updates require the configured team and independent bundle identity")
        suite.expect(!URL(fileURLWithPath: Sudoers.rulePath).lastPathComponent.contains("."),
            "the Lattice sudoers filename is eligible for sudo includedir loading")
        for bundle in ["io.github.sam32j.lattice", "io.github.sam32j.lattice.dev"] {
            suite.expect(CleanerPolicy.isExcludedCacheEntry(bundle)
                && !CleanerPolicy.precheckCacheEntry(bundle)
                && CleanerSupport.isProtectedBundleID(bundle),
                "Lattice protects its active captures and app-owned files from cleanup: \(bundle)")
        }
        suite.expect(ScreenshotSharingSupport.endpoint(bundleIdentifier: "io.github.sam32j.lattice.dev",
            developerOverride: "https://example.invalid") == URL(string: "https://example.invalid"),
            "developer screenshot uploads honor their explicit test endpoint")
    }
}
