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
        testAppVolumeBoostSliderMetrics(suite)
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

    private static func testAppVolumeBoostSliderMetrics(_ suite: TestSuite) {
        let totalWidth: CGFloat = 200
        let mainWidth = AppVolumeSliderMetrics.mainBarWidth(totalWidth: totalWidth)
        suite.expect(mainWidth == 200 - 16 - 28 - 4, "mainBarWidth is total - insets - stub - gap")

        // 0 position -> 0%
        suite.expect(AppVolumeSliderMetrics.value(for: 0, totalWidth: totalWidth) == 0.0, "x=0 yields 0 volume")
        suite.expect(AppVolumeSliderMetrics.value(for: AppVolumeSliderMetrics.thumbRadius, totalWidth: totalWidth) == 0.0, "x=thumbRadius yields 0 volume")

        // Main bar middle -> ~50%
        let midVal = AppVolumeSliderMetrics.value(for: AppVolumeSliderMetrics.thumbRadius + (mainWidth - AppVolumeSliderMetrics.snapMargin) / 2, totalWidth: totalWidth)
        suite.expect(abs(midVal - 0.5) < 0.05, "middle of main bar yields approx 0.5")

        // Snapping near end of main bar -> 100%
        let snapVal = AppVolumeSliderMetrics.value(for: AppVolumeSliderMetrics.thumbRadius + mainWidth - 2, totalWidth: totalWidth)
        suite.expect(snapVal == 1.0, "within snap margin snaps to exactly 1.0")

        // End of main bar -> 100%
        let endBarVal = AppVolumeSliderMetrics.value(for: AppVolumeSliderMetrics.thumbRadius + mainWidth, totalWidth: totalWidth)
        suite.expect(endBarVal == 1.0, "end of main bar yields 1.0")

        // Sticky zone (gap) -> exactly 100%
        let gapVal = AppVolumeSliderMetrics.value(for: AppVolumeSliderMetrics.thumbRadius + mainWidth + 2, totalWidth: totalWidth)
        suite.expect(gapVal == 1.0, "sticky zone in gap yields exactly 1.0")

        // Sticky lead in stub -> exactly 100%
        let stickyLeadVal = AppVolumeSliderMetrics.value(for: AppVolumeSliderMetrics.thumbRadius + mainWidth + AppVolumeSliderMetrics.gap + 1, totalWidth: totalWidth)
        suite.expect(stickyLeadVal == 1.0, "sticky lead in stub yields exactly 1.0")

        // Middle of stub -> ~150% (boosted)
        let stubMidX = AppVolumeSliderMetrics.thumbRadius + mainWidth + AppVolumeSliderMetrics.gap + AppVolumeSliderMetrics.stickyLead + (AppVolumeSliderMetrics.stubWidth - AppVolumeSliderMetrics.stickyLead) / 2
        let stubMidVal = AppVolumeSliderMetrics.value(for: stubMidX, totalWidth: totalWidth)
        suite.expect(abs(stubMidVal - 1.5) < 0.05, "midpoint of boost stub yields approx 1.5")

        // End of stub -> 200% (max boost)
        let stubEndVal = AppVolumeSliderMetrics.value(for: totalWidth, totalWidth: totalWidth)
        suite.expect(stubEndVal == 2.0, "end of stub yields 2.0 (200%)")

        // Thumb positions
        let posZero = AppVolumeSliderMetrics.thumbPosition(for: 0.0, totalWidth: totalWidth)
        suite.expect(posZero == AppVolumeSliderMetrics.thumbRadius, "0 volume thumb is at thumbRadius")

        let pos100 = AppVolumeSliderMetrics.thumbPosition(for: 1.0, totalWidth: totalWidth)
        let expectedPos100 = AppVolumeSliderMetrics.thumbRadius + mainWidth
        suite.expect(pos100 == expectedPos100, "100% volume thumb is at end of main bar")

        let pos200 = AppVolumeSliderMetrics.thumbPosition(for: 2.0, totalWidth: totalWidth)
        let expectedPos200 = AppVolumeSliderMetrics.thumbRadius + mainWidth + AppVolumeSliderMetrics.gap + AppVolumeSliderMetrics.stubWidth
        suite.expect(pos200 == expectedPos200, "200% volume thumb is at end of stub")
    }
}
