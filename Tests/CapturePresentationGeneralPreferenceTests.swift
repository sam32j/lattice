// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum CapturePresentationGeneralPreferenceTests {
    static func run(_ suite: TestSuite) {
        suite.expect(CapturePresentationRouting.destination(
            origin: .external, preference: .automatic, islandAvailable: true,
            latticePreference: .floatingWindow) == .floatingWindow,
            "external automatic follows general floating preference")
        suite.expect(CapturePresentationRouting.destination(
            origin: .external, preference: .automatic, islandAvailable: true,
            latticePreference: .automatic) == .dynamicIsland,
            "external automatic follows general automatic preference")

        suite.expect(CapturePresentationRouting.destination(
            origin: .dynamicIsland, preference: .automatic, islandAvailable: true,
            latticePreference: .floatingWindow) == .dynamicIsland,
            "automatic clicks keep island origin regardless of general preference")
        suite.expect(CapturePresentationRouting.destination(
            origin: .floatingWindow, preference: .automatic, islandAvailable: true,
            latticePreference: .automatic) == .floatingWindow,
            "automatic clicks keep floating origin regardless of general preference")

        suite.expect(CapturePresentationRouting.destination(
            origin: .external, preference: .dynamicIsland, islandAvailable: false,
            latticePreference: .automatic) == .floatingWindow,
            "disabled island always uses floating window")
    }
}
