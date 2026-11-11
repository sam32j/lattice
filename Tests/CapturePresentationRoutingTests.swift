// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum CapturePresentationRoutingTests {
    static func run(_ suite: TestSuite) {
        suite.expect(CapturePresentationRouting.destination(
            origin: .dynamicIsland, preference: .automatic, islandAvailable: true) == .dynamicIsland,
            "dynamic island origin inherits dynamic island in automatic mode")
        suite.expect(CapturePresentationRouting.destination(
            origin: .floatingWindow, preference: .automatic, islandAvailable: true) == .floatingWindow,
            "floating window origin inherits floating window in automatic mode")
        suite.expect(CapturePresentationRouting.destination(
            origin: .external, preference: .automatic, islandAvailable: true) == .dynamicIsland,
            "external origin with automatic lattice preference routes to dynamic island")

        suite.expect(CapturePresentationRouting.destination(
            origin: .floatingWindow, preference: .dynamicIsland, islandAvailable: true) == .dynamicIsland,
            "explicit island preference overrides floating entry point")
        suite.expect(CapturePresentationRouting.destination(
            origin: .dynamicIsland, preference: .floatingWindow, islandAvailable: true) == .floatingWindow,
            "explicit floating preference overrides island entry point")

        for choice in CapturePresentationRouting.Preference.allCases {
            suite.expect(CapturePresentationRouting.destination(
                origin: .external, preference: choice, islandAvailable: false) == .floatingWindow,
                "island unavailable always opens floating for \(choice)")
        }
    }
}
