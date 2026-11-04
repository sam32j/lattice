// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation
import Carbon.HIToolbox

enum DeviceControlsTests {
    static func run(_ suite: TestSuite) {
        testItemProperties(suite)
        testNavigationState(suite)
        testActiveAppFilteringContract(suite)
        testKeyboardLightSaturatedBehavior(suite)
        testLauncherNavigationAndWindowBehavior(suite)
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

    private static func testKeyboardLightSaturatedBehavior(_ suite: TestSuite) {
        // Normal condition (isSaturated == false):
        // Display level matches actual level, readout is percentage
        let normalLevel = BrightnessSupport.keyboardLightDisplayLevel(level: 0.5, isSaturated: false)
        suite.expect(normalLevel == 0.5, "normal condition returns exact level")
        let normalReadout = BrightnessSupport.keyboardLightDisplayReadout(level: 0.5, isSaturated: false, onText: "On", offText: "Off")
        suite.expect(normalReadout == "50%", "normal condition displays percentage")

        let normalFloorReadout = BrightnessSupport.keyboardLightDisplayReadout(level: 0.0625, isSaturated: false, onText: "On", offText: "Off")
        suite.expect(normalFloorReadout == "6%", "normal condition displays 6% at step 1")

        let normalZeroReadout = BrightnessSupport.keyboardLightDisplayReadout(level: 0, isSaturated: false, onText: "On", offText: "Off")
        suite.expect(normalZeroReadout == "0%", "normal condition displays 0% when off")

        // Saturated condition (isSaturated == true):
        // Sliderbar is full (1.0) when on (>0), 0 when off (0)
        // Readout is "On" when on (>0), "Off" when off (0)
        let satOnLevel = BrightnessSupport.keyboardLightDisplayLevel(level: 0.0625, isSaturated: true)
        suite.expect(satOnLevel == 1.0, "saturated condition shows full sliderbar when on at 6%")

        let satOnReadout = BrightnessSupport.keyboardLightDisplayReadout(level: 0.0625, isSaturated: true, onText: "On", offText: "Off")
        suite.expect(satOnReadout == "On", "saturated condition shows 'On' instead of 6%")

        let satOffLevel = BrightnessSupport.keyboardLightDisplayLevel(level: 0, isSaturated: true)
        suite.expect(satOffLevel == 0.0, "saturated condition shows 0 sliderbar when off")

        let satOffReadout = BrightnessSupport.keyboardLightDisplayReadout(level: 0, isSaturated: true, onText: "On", offText: "Off")
        suite.expect(satOffReadout == "Off", "saturated condition shows 'Off' when off")

        let satNilLevel = BrightnessSupport.keyboardLightDisplayLevel(level: nil, isSaturated: true)
        suite.expect(satNilLevel == 0.0, "saturated condition handles nil level as 0")

        let satNilReadout = BrightnessSupport.keyboardLightDisplayReadout(level: nil, isSaturated: true, onText: "On", offText: "Off")
        suite.expect(satNilReadout == "Off", "saturated condition handles nil level as Off")
    }

    private static func testLauncherNavigationAndWindowBehavior(_ suite: TestSuite) {
        // Hierarchical escape behavior
        let launcher = LatticeHubContract.Launcher()
        let nav = DeviceControlsNavigationState.shared
        nav.currentSubpage = .appVolumes
        launcher.activeUtility = .deviceControls

        // Escape on nested subpage (App Volumes) returns to parent subpage (.main)
        _ = launcher.handlePanelKey(LatticeHubContract.NSEvent(keyCode: UInt16(kVK_Escape)))
        suite.expect(nav.currentSubpage == .main, "escape on appVolumes returns to main page")
        suite.expect(launcher.activeUtility == .deviceControls, "activeUtility remains deviceControls")

        // Escape on feature page (.main) returns to root launcher (activeUtility == nil)
        _ = launcher.handlePanelKey(LatticeHubContract.NSEvent(keyCode: UInt16(kVK_Escape)))
        suite.expect(launcher.activeUtility == nil, "escape on deviceControls main returns to root launcher")

        // Escape on root launcher closes launcher
        LatticeHubContract.events.removeAll()
        _ = launcher.handlePanelKey(LatticeHubContract.NSEvent(keyCode: UInt16(kVK_Escape)))
        suite.expect(LatticeHubContract.events == ["hide"], "escape on root launcher closes launcher")

        // Cmd+W closes launcher
        LatticeHubContract.events.removeAll()
        _ = launcher.handlePanelKey(LatticeHubContract.NSEvent(keyCode: UInt16(kVK_ANSI_W), modifierFlags: .command))
        suite.expect(LatticeHubContract.events == ["hide"], "Cmd+W closes launcher")
    }
}
