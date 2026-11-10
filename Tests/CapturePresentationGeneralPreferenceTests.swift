// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import XCTest

final class CapturePresentationGeneralPreferenceTests: XCTestCase {
    func testExternalAutomaticFollowsGeneralFloatingPreference() {
        XCTAssertEqual(CapturePresentationRouting.destination(
            origin: .external, preference: .automatic, islandAvailable: true,
            latticePreference: .floatingWindow), .floatingWindow)
        XCTAssertEqual(CapturePresentationRouting.destination(
            origin: .external, preference: .automatic, islandAvailable: true,
            latticePreference: .automatic), .dynamicIsland)
    }

    func testAutomaticClicksKeepTheirOriginRegardlessOfGeneralPreference() {
        XCTAssertEqual(CapturePresentationRouting.destination(
            origin: .dynamicIsland, preference: .automatic, islandAvailable: true,
            latticePreference: .floatingWindow), .dynamicIsland)
        XCTAssertEqual(CapturePresentationRouting.destination(
            origin: .floatingWindow, preference: .automatic, islandAvailable: true,
            latticePreference: .automatic), .floatingWindow)
    }

    func testDisabledIslandAlwaysUsesFloatingWindow() {
        XCTAssertEqual(CapturePresentationRouting.destination(
            origin: .external, preference: .dynamicIsland, islandAvailable: false,
            latticePreference: .automatic), .floatingWindow)
    }
}
