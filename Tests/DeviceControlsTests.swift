// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum DeviceControlsTests {
    static func run(_ suite: TestSuite) {
        testItemProperties(suite)
        testNavigationState(suite)
        testActiveAppFilteringContract(suite)
    }

    private static func testItemProperties(_ suite: TestSuite) {
        let item = LatticeHubContract.LatticeHubItem.deviceControls
        suite.expect(item.rawValue == "deviceControls", "deviceControls item has matching rawValue")
        suite.expect(item.feature == .mixer, "deviceControls maps to mixer feature")

        let tile = LatticeHubContract.Tile()
        suite.expect(tile.icon(for: item) == "slider.horizontal.3", "deviceControls uses slider.horizontal.3 icon")

        let allItems = LatticeHubContract.LatticeHubItem.allCases
        suite.expect(allItems.contains(.deviceControls), "allCases includes deviceControls")
    }

    private static func testNavigationState(_ suite: TestSuite) {
        let nav = DeviceControlsNavigationState.shared
        nav.resetSubpage()
        nav.showInactiveApps = false

        suite.expect(nav.currentSubpage == .main, "initial subpage is main")
        suite.expect(!nav.showInactiveApps, "inactive apps hidden by default")

        nav.currentSubpage = .appVolumes
        suite.expect(nav.currentSubpage == .appVolumes, "navigates to appVolumes")

        nav.showInactiveApps = true
        suite.expect(nav.showInactiveApps, "reveals inactive apps")

        nav.resetSubpage()
        suite.expect(nav.currentSubpage == .main, "resetSubpage returns to main")
        suite.expect(nav.showInactiveApps, "filter preference is preserved when resetting subpage")
    }

    private static func testActiveAppFilteringContract(_ suite: TestSuite) {
        // Verify active vs inactive calculation using MixerRoutingSupport contract
        // Active: isPlaying || !isUnity(volume) || selectedOutputDeviceUID != nil
        suite.expect(
            MixerRoutingSupport.shouldShowApp(isPlaying: true, volume: 1.0, selectedOutputDeviceUID: nil, hideInactiveApps: true),
            "playing app is active"
        )
        suite.expect(
            MixerRoutingSupport.shouldShowApp(isPlaying: false, volume: 0.8, selectedOutputDeviceUID: nil, hideInactiveApps: true),
            "app with adjusted volume is active"
        )
        suite.expect(
            MixerRoutingSupport.shouldShowApp(isPlaying: false, volume: 1.0, selectedOutputDeviceUID: "device-1", hideInactiveApps: true),
            "app with rerouted output is active"
        )
        suite.expect(
            !MixerRoutingSupport.shouldShowApp(isPlaying: false, volume: 1.0, selectedOutputDeviceUID: nil, hideInactiveApps: true),
            "idle app at unity with default output is inactive"
        )
        suite.expect(
            MixerRoutingSupport.shouldShowApp(isPlaying: false, volume: 1.0, selectedOutputDeviceUID: nil, hideInactiveApps: false),
            "inactive app is shown when hideInactiveApps is false"
        )
    }
}
