// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Foundation
import SwiftUI

/// The redesigned radial menu: one release rule for every held trigger.
enum RadialMenuReleaseTests {
    static func runHold(_ suite: TestSuite) {
        suite.expect(RadialMenuSupport.shortcutIsStillHeld(modifiersHeld: false, superKeyHeld: false, keyHeld: true),
                     "a chord whose modifiers come from a remapped key stays held while its key is down")
        suite.expect(!RadialMenuSupport.shortcutIsStillHeld(modifiersHeld: false, superKeyHeld: false, keyHeld: false),
                     "letting go of everything ends the hold")
        suite.expect(RadialMenuSupport.chordKeyUpEndsHold(heldFor: 0.1, usesSuperKey: false,
                                                          modifiersHeld: true, superKeyHeld: false),
                     "a chord whose key is only tapped ends its hold on key-up, even with a modifier lingering")
        suite.expect(!RadialMenuSupport.chordKeyUpEndsHold(heldFor: 0.8, usesSuperKey: false,
                                                           modifiersHeld: true, superKeyHeld: false),
                     "a chord key held past a tap leaves the hold to the modifiers, so they can keep aiming")
        suite.expect(RadialMenuSupport.chordKeyUpEndsHold(heldFor: 0.8, usesSuperKey: false,
                                                          modifiersHeld: false, superKeyHeld: false),
                     "a chord key let go after its modifiers ends the hold")
        suite.expect(!RadialMenuSupport.chordKeyUpEndsHold(heldFor: 0.1, usesSuperKey: true,
                                                           modifiersHeld: false, superKeyHeld: true),
                     "a Super Key chord keeps its own release path, even on a quick key-up")
        let quickToggleNames = FeatureStrings.radialMenu(.enUS)
        suite.expect(RadialMenuQuickToggle.darkMode.stableTitle(quickToggleNames) == "Toggle System Appearance"
                && RadialMenuQuickToggle.hiddenFiles.stableTitle(quickToggleNames) == "Toggle Hidden Files"
                && RadialMenuQuickToggle.desktopIcons.stableTitle(quickToggleNames) == "Toggle Desktop Icons"
                && RadialMenuQuickToggle.lockScreen.stableTitle(quickToggleNames) == nil,
                     "state-dependent quick toggles have stable names in Settings")
        suite.expect(Set(RadialMenuTool.allCases.filter(\.isControl)) == [.micMute, .keepAwake, .cleaningMode],
                     "only the switch-like tools are listed with the quick controls")
        suite.expect(true,
                     "state-dependent quick toggles have stable names in Settings")
    }

    static func run(_ suite: TestSuite) {
        runHold(suite)
        let quick = RadialMenuSupport.quickPressLimit - 0.01
        let held = RadialMenuSupport.quickPressLimit
        suite.expect(RadialMenuSupport.quickPressLimit == 0.30
                && RadialMenuSupport.tabDwell == 0.35
                && RadialMenuSupport.profileNameFlash == 0.8,
               "the quick press, tab dwell and name flash keep their specified lengths")
        for heldFor in [0, quick, held, 4] {
            suite.expect(RadialMenuSupport.releaseAction(heldFor: heldFor, preselection: .slot) == .run,
                         "a release over a slot runs it, however long it was held (\(heldFor) s)")
            suite.expect(RadialMenuSupport.releaseAction(heldFor: heldFor, preselection: .submenu) == .openSubmenu,
                         "a release over a submenu opens it (\(heldFor) s)")
            suite.expect(RadialMenuSupport.releaseAction(heldFor: heldFor, preselection: .profileTab) == .switchProfile,
                         "a release over a profile tab switches to it (\(heldFor) s)")
        }
        suite.expect(RadialMenuSupport.releaseAction(heldFor: 0, preselection: .none) == .stayOpen
                && RadialMenuSupport.releaseAction(heldFor: quick, preselection: .none) == .stayOpen,
               "a quick press with nothing picked leaves the menu open")
        suite.expect(RadialMenuSupport.releaseAction(heldFor: held, preselection: .none) == .close
                && RadialMenuSupport.releaseAction(heldFor: 2, preselection: .none) == .close,
               "a hold of 0.30 s or more released over nothing closes the menu")
    }
}

enum RadialMenuTriggerMigrationTests {
    static func run(_ suite: TestSuite) {
        let first = RadialMenuProfile(name: "First")
        let second = RadialMenuProfile(name: "Second")
        let third = RadialMenuProfile(name: "Third")
        let profiles = [first, second, third]
        let chord = GlobalShortcut(keyCode: 40, modifiers: [.control, .option]).storageValue
        let other = GlobalShortcut(keyCode: 41, modifiers: [.control, .command]).storageValue

        func migrate(_ triggers: [RadialMenuLegacyTriggers], stored: String? = nil,
                     middleClickOwned: Bool = false) -> RadialMenuTriggerMigration.Result {
            RadialMenuTriggerMigration.migrate(profiles: profiles, triggers: triggers,
                                               storedShortcut: stored,
                                               middleClickOwnedFourFingerTap: middleClickOwned)
        }

        var result = migrate([RadialMenuLegacyTriggers(id: first.id),
                              RadialMenuLegacyTriggers(id: second.id, shortcut: chord, mouseButton: "button:5"),
                              RadialMenuLegacyTriggers(id: third.id, shortcut: other, mouseButton: "back")],
                             stored: other)
        suite.expect(result.shortcut == chord && result.profiles.map(\.id) == [second.id, first.id, third.id],
                     "the first profile with a shortcut owns it and becomes the primary")
        suite.expect(result.mouseButton == "button:5",
                     "the primary keeps its own mouse button")

        result = migrate([RadialMenuLegacyTriggers(id: first.id, mouseButton: "back"),
                          RadialMenuLegacyTriggers(id: second.id, shortcut: chord)])
        suite.expect(result.mouseButton == RadialMenuMouseTrigger.back.rawValue
                && result.profiles.first?.id == second.id,
                     "a primary without a button takes the first profile's button in order")

        result = migrate([RadialMenuLegacyTriggers(id: second.id, mouseButton: "forward"),
                          RadialMenuLegacyTriggers(id: third.id, trackpadTap: true)], stored: other)
        suite.expect(result.shortcut == other && result.profiles.first?.id == second.id
                && result.mouseButton == RadialMenuMouseTrigger.forward.rawValue && result.trackpadGesture == .tap,
                     "with no profile shortcut the stored one is kept and the mouse button's profile leads")

        result = migrate([RadialMenuLegacyTriggers(id: third.id, trackpadTap: true)], stored: "")
        suite.expect(result.shortcut.isEmpty && result.profiles.first?.id == third.id
                && result.mouseButton == "off" && result.trackpadGesture == .tap,
                     "with only the trackpad tap, its profile becomes the primary")

        result = migrate([RadialMenuLegacyTriggers(id: third.id, trackpadTap: true)], middleClickOwned: true)
        suite.expect(result.trackpadGesture == .off,
                     "a radial tap that Middle Click's four-finger tap always beat is not carried over")

        result = migrate([], stored: "garbage")
        suite.expect(result.profiles == profiles && result.shortcut.isEmpty && result.mouseButton == "off"
                && result.trackpadGesture == .off,
                     "profiles without triggers keep their order and an invalid stored shortcut is dropped")

        // Stored preferences, version 1 to 2.
        let domain = "vorss.tests.radial-trigger-migration.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }

        func legacyBlob(_ entries: [(RadialMenuProfile, [String: Any])]) -> Data {
            let objects: [[String: Any]] = entries.map { profile, triggers in
                var object: [String: Any] = ["id": profile.id.uuidString, "name": profile.name,
                                             "color": profile.color.rawValue, "items": []]
                object.merge(triggers) { $1 }
                return object
            }
            return try! JSONSerialization.data(withJSONObject: objects)
        }

        defaults.set(legacyBlob([(first, ["shortcut": "", "mouseButton": "off"]),
                                 (second, ["shortcut": chord, "mouseButton": "button:6", "trackpadTap": true])]),
                     forKey: DefaultsKey.radialMenuProfiles)
        defaults.set(chord, forKey: DefaultsKey.radialMenuShortcut)
        defaults.set(false, forKey: DefaultsKey.legacyRadialMenuAtPointer)
        defaults.set("hold", forKey: DefaultsKey.legacyRadialMenuActivationMode)
        suite.expect(RadialMenuTriggerMigration.run(in: defaults), "version 1 settings migrate")
        let migrated = RadialMenuSupport.decodeProfiles(defaults.data(forKey: DefaultsKey.radialMenuProfiles),
                                                        defaults: defaults)
        let stored = (try? JSONSerialization.jsonObject(
            with: defaults.data(forKey: DefaultsKey.radialMenuProfiles) ?? Data())) as? [[String: Any]] ?? []
        suite.expect(migrated.map(\.id) == [second.id, first.id]
                && defaults.string(forKey: DefaultsKey.radialMenuShortcut) == chord
                && defaults.string(forKey: DefaultsKey.radialMenuMouseButton) == "button:6"
                && defaults.string(forKey: DefaultsKey.radialMenuTrackpadGesture) == "tap"
                && defaults.integer(forKey: DefaultsKey.radialMenuSettingsVersion) == 2,
                     "stored profiles become one menu-wide trigger set with the shortcut's profile first")
        suite.expect(stored.allSatisfy { $0["shortcut"] == nil && $0["mouseButton"] == nil && $0["trackpadTap"] == nil },
                     "the migrated profiles are saved without their old triggers")
        suite.expect(defaults.object(forKey: DefaultsKey.legacyRadialMenuAtPointer) == nil
                && defaults.object(forKey: DefaultsKey.legacyRadialMenuActivationMode) == nil,
                     "the retired placement and opening-behavior keys are removed")

        defaults.set("off", forKey: DefaultsKey.radialMenuTrackpadGesture)
        suite.expect(!RadialMenuTriggerMigration.run(in: defaults)
                && defaults.string(forKey: DefaultsKey.radialMenuTrackpadGesture) == "off",
                     "already migrated settings are left alone")

        // An older backup restored: the restore clears the version (it is a
        // backup key the old file lacks) and writes the old profiles back.
        defaults.removeObject(forKey: DefaultsKey.radialMenuSettingsVersion)
        defaults.set(legacyBlob([(third, ["shortcut": other, "mouseButton": "forward"]),
                                 (first, ["shortcut": "", "trackpadTap": true])]),
                     forKey: DefaultsKey.radialMenuProfiles)
        defaults.set(true, forKey: AppFeature.middleClick.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.middleClickEnabled)
        defaults.set(4, forKey: DefaultsKey.middleClickTapFingers)
        suite.expect(RadialMenuTriggerMigration.run(in: defaults), "a restored older backup migrates again")
        suite.expect(defaults.string(forKey: DefaultsKey.radialMenuShortcut) == other
                && defaults.string(forKey: DefaultsKey.radialMenuMouseButton) == RadialMenuMouseTrigger.forward.rawValue
                && defaults.string(forKey: DefaultsKey.radialMenuTrackpadGesture) == "off"
                && RadialMenuSupport.decodeProfiles(defaults.data(forKey: DefaultsKey.radialMenuProfiles),
                                                    defaults: defaults).first?.id == third.id,
                     "the restored backup's triggers move menu-wide; Middle Click keeps the tap it owned")

        // The single wheel from before profiles already used the menu keys.
        defaults.removePersistentDomain(forName: domain)
        defaults.set(other, forKey: DefaultsKey.radialMenuShortcut)
        defaults.set("back", forKey: DefaultsKey.radialMenuMouseButton)
        defaults.set(RadialMenuSupport.encode([RadialMenuItem(kind: .app, payload: "/Applications/Safari.app")]),
                     forKey: DefaultsKey.radialMenuItems)
        suite.expect(RadialMenuTriggerMigration.run(in: defaults)
                && defaults.data(forKey: DefaultsKey.radialMenuProfiles) == nil
                && defaults.string(forKey: DefaultsKey.radialMenuShortcut) == other
                && defaults.string(forKey: DefaultsKey.radialMenuMouseButton) == "back"
                && RadialMenuSupport.decodeProfiles(nil, defaults: defaults).first?.items.count == 1,
                     "the legacy single wheel keeps its shortcut, button and actions")

        // Empty or unreadable profiles migrate nothing but the version.
        defaults.removePersistentDomain(forName: domain)
        defaults.set(Data("[]".utf8), forKey: DefaultsKey.radialMenuProfiles)
        suite.expect(RadialMenuTriggerMigration.run(in: defaults)
                && defaults.data(forKey: DefaultsKey.radialMenuProfiles) == Data("[]".utf8)
                && defaults.integer(forKey: DefaultsKey.radialMenuSettingsVersion) == 2,
                     "an empty profile list only records the new version")

        // A record without an ID keeps its triggers; one whose profile fails
        // to decode lends none to a later profile with the same ID.
        defaults.removePersistentDomain(forName: domain)
        let shared = UUID().uuidString
        let records: [[String: Any]] = [
            ["id": shared, "name": "Broken", "color": 42, "shortcut": other],
            ["id": shared, "name": "Kept", "color": "blue", "items": [], "shortcut": chord],
            ["name": "No ID", "color": "red", "items": [], "mouseButton": "back"],
        ]
        defaults.set(try! JSONSerialization.data(withJSONObject: records), forKey: DefaultsKey.radialMenuProfiles)
        suite.expect(RadialMenuTriggerMigration.run(in: defaults)
                && defaults.string(forKey: DefaultsKey.radialMenuShortcut) == chord
                && defaults.string(forKey: DefaultsKey.radialMenuMouseButton) == "back"
                && RadialMenuSupport.decodeProfiles(defaults.data(forKey: DefaultsKey.radialMenuProfiles),
                                                    defaults: defaults).map(\.name) == ["Kept", "No ID"],
                     "each profile's triggers come from its own record, with or without an ID")

        suite.expect(SettingsBackupSupport.valueLooksRight(DefaultsKey.radialMenuSettingsVersion, 2)
                && !SettingsBackupSupport.valueLooksRight(DefaultsKey.radialMenuSettingsVersion, "2")
                && !SettingsBackupSupport.valueLooksRight(DefaultsKey.radialMenuSettingsVersion, true),
                     "a backup's settings version is restored only as a whole number")
    }
}

enum MiddleClickPrecedenceTests {
    static func run(_ suite: TestSuite) {
        let gestures: [RadialMenuTrackpadGesture] = [.off, .tap, .click]
        for gesture in gestures {
            for stored in [0, 3, 4] {
                for systemOwns in [false, true] {
                    let effective = MiddleClickSupport.effectiveTapFingers(
                        stored: stored, systemOwnsThreeFingerTap: systemOwns, radialGesture: gesture)
                    var expected = stored == 3 && systemOwns ? 0 : stored
                    if expected == 4 && gesture == .tap { expected = 0 }
                    suite.expect(effective == expected,
                                 "tap: stored \(stored), macOS owns three \(systemOwns), radial \(gesture) answers \(expected)")
                }
            }
            for stored in [3, 4] {
                for drag in [false, true] {
                    let effective = MiddleClickSupport.effectiveClickFingers(
                        stored: stored, systemDragEnabled: drag, radialGesture: gesture)
                    var expected = stored == 4 || drag ? 4 : 3
                    if expected == 4 && gesture == .click { expected = drag ? 0 : 3 }
                    suite.expect(effective == expected,
                                 "click: stored \(stored), three-finger drag \(drag), radial \(gesture) answers \(expected)")
                }
            }
        }
        suite.expect(MiddleClickSupport.actionForClick(fingerCount: 4, frameAge: 0.01, settledFor: 0.2,
                                                       sinceLastTransformEnd: nil, systemDragGestureEnabled: false,
                                                       clickFingers: 4, radialGesture: .click) == .passThrough
                && MiddleClickSupport.actionForClick(fingerCount: 3, frameAge: 0.01, settledFor: 0.2,
                                                     sinceLastTransformEnd: nil, systemDragGestureEnabled: false,
                                                     clickFingers: 4, radialGesture: .click) == .transform,
               "with the radial four-finger click, a saved four-finger middle click moves to three")
        suite.expect(MiddleClickSupport.actionForClick(fingerCount: 4, frameAge: 0.01, settledFor: 0.2,
                                                       sinceLastTransformEnd: nil, systemDragGestureEnabled: true,
                                                       clickFingers: 3, radialGesture: .click) == .passThrough
                && MiddleClickSupport.actionForClick(fingerCount: 3, frameAge: 0.01, settledFor: 0.2,
                                                     sinceLastTransformEnd: nil, systemDragGestureEnabled: true,
                                                     clickFingers: 3, radialGesture: .click) == .passThrough,
               "with three-finger drag owning three and the menu owning four, Middle Click has no press")
        suite.expect(MiddleClickSupport.radialClickOpens(fingerCount: 4, frameAge: 0.02, settledFor: 0.05,
                                                         radialGesture: .click)
                && !MiddleClickSupport.radialClickOpens(fingerCount: 4, frameAge: 0.02, settledFor: 0.01,
                                                        radialGesture: .click)
                && !MiddleClickSupport.radialClickOpens(fingerCount: 3, frameAge: 0.02, settledFor: 0.2,
                                                        radialGesture: .click)
                && !MiddleClickSupport.radialClickOpens(fingerCount: 4, frameAge: 0.5, settledFor: 0.2,
                                                        radialGesture: .click)
                && !MiddleClickSupport.radialClickOpens(fingerCount: 4, frameAge: 0.02, settledFor: 0.2,
                                                        radialGesture: .tap),
               "only a settled, fresh four-finger press opens the menu, and only when it uses the click")
        // Swipes and pinches travel or spread past the tap limits, so the
        // four-finger tap never fires from them.
        suite.expect(!MiddleClickSupport.tapShouldFire(duration: 0.2, maxMovement: 0.2, maxSpreadChange: 0.01,
                                                       exceededFingerCount: false, buttonPressedDuring: false,
                                                       positionUnavailable: false, systemOwnsThreeFingerTap: false,
                                                       tapFingers: 4)
                && !MiddleClickSupport.tapShouldFire(duration: 0.2, maxMovement: 0.01, maxSpreadChange: 0.2,
                                                     exceededFingerCount: false, buttonPressedDuring: false,
                                                     positionUnavailable: false, systemOwnsThreeFingerTap: false,
                                                     tapFingers: 4)
                && !MiddleClickSupport.tapShouldFire(duration: 0.8, maxMovement: 0.01, maxSpreadChange: 0.01,
                                                     exceededFingerCount: false, buttonPressedDuring: false,
                                                     positionUnavailable: false, systemOwnsThreeFingerTap: false,
                                                     tapFingers: 4),
               "four-finger swipes, pinches and holds never count as the opening tap")
    }
}

enum RadialProfileTabsTests {
    static func run(_ suite: TestSuite) {
        suite.expect(RadialProfileTabs.visibleTabs(count: 1, current: 0).isEmpty,
                     "a single profile draws no tab arc")
        suite.expect(RadialProfileTabs.visibleTabs(count: 7, current: 3).map(\.index) == Array(0..<7)
                && RadialProfileTabs.visibleTabs(count: 7, current: 3).allSatisfy { !$0.faded },
                     "up to seven profiles all show, none faded")
        let window = RadialProfileTabs.visibleTabs(count: 10, current: 0)
        suite.expect(window.map(\.index) == [7, 8, 9, 0, 1, 2, 3]
                && window.map(\.faded) == [true, false, false, false, false, false, true],
                     "more than seven show the current one and three each side, the outermost two faded")
        suite.expect(RadialProfileTabs.index(from: 2, step: 1, count: 3) == 0
                && RadialProfileTabs.index(from: 0, step: -1, count: 3) == 2
                && RadialProfileTabs.index(from: 1, step: 1, count: 3) == 2,
                     "Tab and Shift-Tab wrap at both ends")
        suite.expect(RadialProfileTabs.canOpen(availableItemCounts: [0, 3])
                && !RadialProfileTabs.canOpen(availableItemCounts: [0, 0])
                && RadialProfileTabs.canOpen(availableItemCounts: [2]),
                     "the menu opens on an empty primary while another profile has actions, never when all are empty")
        suite.expect(RadialProfileTabs.index(from: 0, step: 1, count: 3) == 1,
                     "empty profiles stay in the cycle")

        var scroll = RadialProfileScrollAccumulator()
        suite.expect(scroll.step(deltaX: 0, deltaY: -1, isContinuous: false, isMomentum: false, now: 0) == 1
                && scroll.step(deltaX: 0, deltaY: 1, isContinuous: false, isMomentum: false, now: 0.01) == -1
                && scroll.step(deltaX: 0, deltaY: -1, isContinuous: false, isMomentum: false, now: 0.02) == 1,
                     "every notch of a mouse wheel is one step")
        scroll = RadialProfileScrollAccumulator()
        suite.expect(scroll.step(deltaX: 0, deltaY: -25, isContinuous: true, isMomentum: false, now: 0) == 0
                && scroll.step(deltaX: 0, deltaY: -20, isContinuous: true, isMomentum: false, now: 0.02) == 1,
                     "trackpad scrolling steps once per 40 points")
        suite.expect(scroll.step(deltaX: 0, deltaY: -60, isContinuous: true, isMomentum: false, now: 0.1) == 0
                && scroll.step(deltaX: 0, deltaY: -45, isContinuous: true, isMomentum: false, now: 0.3) == 1,
                     "a step is followed by a 0.25 s pause")
        suite.expect(scroll.step(deltaX: -80, deltaY: 0, isContinuous: true, isMomentum: true, now: 1) == 0
                && scroll.step(deltaX: -45, deltaY: 10, isContinuous: true, isMomentum: false, now: 1) == 1,
                     "momentum is ignored and the larger axis decides")

        let spans = RadialProfileTabs.arcSpans(widths: [80, 22, 22], radius: 175, capHeight: 22, maxSpan: 2 * .pi / 3)
        let middle = spans.map { ($0.lowerBound + $0.upperBound) / 2 }
        suite.expect(spans.count == 3 && zip(spans, spans.dropFirst()).allSatisfy { $0.upperBound < $1.lowerBound }
                && abs((spans[0].lowerBound - 11.0 / 175) + (spans[2].upperBound + 11.0 / 175)) < 0.0001,
                     "curved tabs run left to right without overlapping, centred over twelve o'clock")
        let squeezed = RadialProfileTabs.arcSpans(widths: [150] + Array(repeating: 35, count: 6), radius: 175,
                                                  capHeight: 22, maxSpan: 2 * .pi / 3)
        suite.expect((squeezed.last!.upperBound + 11.0 / 175) - (squeezed.first!.lowerBound - 11.0 / 175)
                <= 2 * .pi / 3 + 0.001,
                     "a long run of tabs is squeezed to stay within the arc's span")
        let keyed = Dictionary(uniqueKeysWithValues: spans.enumerated().map { ($0.offset, $0.element) })
        func point(_ angle: Double, _ radius: CGFloat = 175) -> (CGFloat, CGFloat) {
            (radius * CGFloat(sin(angle)), radius * CGFloat(cos(angle)))
        }
        let onFirst = point(middle[0]), onLast = point(middle[2])
        suite.expect(RadialProfileTabs.tabIndex(dx: onFirst.0, dyUp: onFirst.1, spans: keyed, radius: 175, capHeight: 22) == 0
                && RadialProfileTabs.tabIndex(dx: onLast.0, dyUp: onLast.1, spans: keyed, radius: 175, capHeight: 22) == 2,
                     "the pointer on a curved tab finds that tab")
        let inside = point(middle[0], 120), far = point(.pi)
        suite.expect(RadialProfileTabs.tabIndex(dx: inside.0, dyUp: inside.1, spans: keyed, radius: 175, capHeight: 22) == nil
                && RadialProfileTabs.tabIndex(dx: far.0, dyUp: far.1, spans: keyed, radius: 175, capHeight: 22) == nil,
                     "the wheel itself and the far side of the rim are not tabs")
        // Two tabs 4 points apart: both reach into the gap, and the nearer one
        // owns each side of it, whatever order the dictionary iterates in.
        let close: [Int: ClosedRange<Double>] = [0: -0.2...(-0.0114), 1: 0.0114...0.2]
        let leftOfMiddle = point(-0.005), rightOfMiddle = point(0.005), middleOfGap = point(0)
        suite.expect(RadialProfileTabs.tabIndex(dx: leftOfMiddle.0, dyUp: leftOfMiddle.1, spans: close,
                                                radius: 175, capHeight: 22) == 0
                && RadialProfileTabs.tabIndex(dx: rightOfMiddle.0, dyUp: rightOfMiddle.1, spans: close,
                                              radius: 175, capHeight: 22) == 1
                && RadialProfileTabs.tabIndex(dx: middleOfGap.0, dyUp: middleOfGap.1, spans: close,
                                              radius: 175, capHeight: 22) == 0,
                     "a point in a gap belongs to the nearer tab, the earlier one on a tie")

        let a = RadialMenuProfile(name: "A"), b = RadialMenuProfile(name: "B"), c = RadialMenuProfile(name: "C")
        let list = [a, b, c]
        suite.expect(RadialProfileTabs.makingPrimary(c.id, in: list).map(\.id) == [c.id, a.id, b.id]
                && RadialProfileTabs.moving(c.id, before: a.id, in: list).first?.id == c.id
                && RadialProfileTabs.moving(a.id, before: nil, in: list).map(\.id) == [b.id, c.id, a.id]
                && RadialProfileTabs.moving(b.id, to: 0, in: list).first?.id == b.id,
                     "reordering keeps the first tab as the primary")
        let deleted = RadialProfileTabs.deleting(a.id, in: list)
        suite.expect(deleted?.profiles.map(\.id) == [b.id, c.id] && deleted?.selected == b.id
                && RadialProfileTabs.nextPrimary(afterDeleting: a.id, in: list)?.id == b.id
                && RadialProfileTabs.nextPrimary(afterDeleting: b.id, in: list) == nil
                && RadialProfileTabs.deleting(a.id, in: [a]) == nil,
                     "deleting the primary makes the next profile first; the last one is never deleted")
    }
}

/// Every radial and Middle Click string is translated in every shipped
/// language, with the same placeholders as English.
enum RadialMenuStringsTests {
    static func placeholders(_ format: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: "%(?:\\d+\\$)?[@dDuUxXoOfeEgGcCsSpaAF]")
        let range = NSRange(format.startIndex..., in: format)
        return pattern.matches(in: format, range: range).map { (format as NSString).substring(with: $0.range) }.sorted()
    }

    static func fields(_ value: Any) -> [(String, String)] {
        Mirror(reflecting: value).children.compactMap { child in
            guard let label = child.label, let text = child.value as? String else { return nil }
            return (label, text)
        }
    }

    static func run(_ suite: TestSuite) {
        let english = Dictionary(uniqueKeysWithValues: fields(FeatureStrings.radialMenu(.enUS)))
        let englishMiddle = Dictionary(uniqueKeysWithValues: fields(InputSettingsStrings.middleClick(.enUS)))
        for language in AppLanguage.allCases {
            for (label, text) in fields(FeatureStrings.radialMenu(language)) {
                suite.expect(!text.trimmingCharacters(in: .whitespaces).isEmpty,
                             "radial \(label) is filled in for \(language)")
                suite.expect(placeholders(text) == placeholders(english[label] ?? ""),
                             "radial \(label) keeps the English placeholders in \(language)")
            }
            for (label, text) in fields(InputSettingsStrings.middleClick(language)) {
                suite.expect(!text.trimmingCharacters(in: .whitespaces).isEmpty,
                             "middle click \(label) is filled in for \(language)")
                // Only some languages have a "few apps" form; it follows the many form.
                let reference = englishMiddle[label] ?? englishMiddle[label == "fewApps" ? "manyApps" : label] ?? ""
                suite.expect(placeholders(text) == placeholders(reference),
                             "middle click \(label) keeps the English placeholders in \(language)")
            }
        }
        let radialLabels = Set(english.keys)
        suite.expect(radialLabels.isDisjoint(with: ["positionLabel", "tryButton", "showListButton",
                                                    "activationModeLabel", "profileShortcutLabel",
                                                    "mouseTriggerRequirement", "trackpadTapLabel", "canvasHint",
                                                    "fetchFaviconButton", "fetchFaviconSuccess"]),
                     "the retired radial strings are gone")
    }
}

/// Profile gradients keep their text readable in both appearances.
enum RadialMenuGradientTests {
    static func run(_ suite: TestSuite) {
        for scheme in [ColorScheme.light, .dark] {
            for color in RadialMenuColor.allCases {
                let stops = color.gradientStops(for: scheme)
                let text: RadialRGB = color.usesDarkText(for: scheme) ? .black : .white
                suite.expect(stops.bottom.contrast(with: text) >= 4.5,
                             "\(color) tab text clears 4.5:1 on its darker stop in \(scheme)")
                suite.expect(stops.top.luminance > stops.bottom.luminance,
                             "\(color) gradient runs from a lighter to a darker stop in \(scheme)")
            }
        }
        let graphite = RadialMenuColor.graphite.gradientStops(for: .light)
        suite.expect(graphite.top.red == graphite.top.green && graphite.top.green == graphite.top.blue,
                     "graphite keeps a neutral gradient")
    }
}
