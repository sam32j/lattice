// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import XCTest

final class CapturePresentationRoutingTests: XCTestCase {
    func testAutomaticInheritsSourceSurface() {
        XCTAssertEqual(CapturePresentationRouting.destination(
            origin: .dynamicIsland, preference: .automatic, islandAvailable: true), .dynamicIsland)
        XCTAssertEqual(CapturePresentationRouting.destination(
            origin: .floatingWindow, preference: .automatic, islandAvailable: true), .floatingWindow)
        XCTAssertEqual(CapturePresentationRouting.destination(
            origin: .external, preference: .automatic, islandAvailable: true), .dynamicIsland)
    }

    func testExplicitPreferenceOverridesEntryPoint() {
        XCTAssertEqual(CapturePresentationRouting.destination(
            origin: .floatingWindow, preference: .dynamicIsland, islandAvailable: true), .dynamicIsland)
        XCTAssertEqual(CapturePresentationRouting.destination(
            origin: .dynamicIsland, preference: .floatingWindow, islandAvailable: true), .floatingWindow)
    }

    func testIslandDisabledAlwaysOpensFloating() {
        for choice in CapturePresentationRouting.Preference.allCases {
            XCTAssertEqual(CapturePresentationRouting.destination(
                origin: .external, preference: choice, islandAvailable: false), .floatingWindow)
        }
    }
}
