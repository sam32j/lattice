// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Settings version 2 moved the shortcut, the mouse button and the trackpad
/// tap out of each profile into one set for the whole menu, made the
/// shortcut's profile the primary (first) one, and retired the placement and
/// opening-behavior choices. Runs once per install, and again after an older
/// backup is restored, since its profiles still carry their own triggers.
enum RadialMenuTriggerMigration {
    static let currentVersion = 2

    struct Result: Equatable {
        var profiles: [RadialMenuProfile]
        var shortcut: String
        var mouseButton: String
        var trackpadGesture: RadialMenuTrackpadGesture
    }

    /// The pure part: decoded profiles and their old triggers in, the menu's
    /// new triggers and the reordered profiles out.
    ///
    /// - `storedShortcut`: the menu-wide key as it reads now, used only when
    ///   no profile has a shortcut of its own.
    /// - `middleClickOwnedFourFingerTap`: Middle Click was on with its tap at
    ///   four fingers, so the radial tap never fired and is not carried over.
    static func migrate(profiles: [RadialMenuProfile],
                        triggers: [RadialMenuLegacyTriggers],
                        storedShortcut: String?,
                        middleClickOwnedFourFingerTap: Bool) -> Result {
        var byID: [UUID: RadialMenuLegacyTriggers] = [:]
        for trigger in triggers {
            guard let id = trigger.id, byID[id] == nil else { continue }
            byID[id] = trigger
        }
        func old(_ profile: RadialMenuProfile) -> RadialMenuLegacyTriggers {
            byID[profile.id] ?? RadialMenuLegacyTriggers(id: profile.id)
        }

        let owner = profiles.first { old($0).validShortcut != nil }
        let shortcut: String
        if let owner, let ownerShortcut = old(owner).validShortcut {
            shortcut = ownerShortcut.storageValue
        } else if let storedShortcut,
                  let stored = GlobalShortcut(storageValue: storedShortcut.trimmingCharacters(in: .whitespacesAndNewlines)) {
            shortcut = stored.storageValue
        } else {
            shortcut = ""
        }

        let primary = owner
            ?? profiles.first { old($0).button != .off }
            ?? profiles.first { old($0).trackpadTap }
        var ordered = profiles
        if let primary, let index = ordered.firstIndex(where: { $0.id == primary.id }), index > 0 {
            ordered.insert(ordered.remove(at: index), at: 0)
        }

        let primaryButton = primary.map { old($0).button } ?? .off
        let mouseButton = primaryButton != .off
            ? primaryButton
            : (profiles.lazy.map { old($0).button }.first { $0 != .off } ?? .off)

        let hadTap = profiles.contains { old($0).trackpadTap }
        let gesture: RadialMenuTrackpadGesture = hadTap && !middleClickOwnedFourFingerTap ? .tap : .off

        return Result(profiles: ordered, shortcut: shortcut, mouseButton: mouseButton.rawValue,
                      trackpadGesture: gesture)
    }

    /// Applies the migration to stored preferences when they are older than
    /// version 2. Returns whether anything was migrated.
    @discardableResult
    static func run(in defaults: UserDefaults) -> Bool {
        guard defaults.integer(forKey: DefaultsKey.radialMenuSettingsVersion) < currentVersion else { return false }
        if let data = defaults.data(forKey: DefaultsKey.radialMenuProfiles),
           let rawProfiles = try? JSONDecoder().decode([FailableValue<RadialMenuProfile>].self, from: data),
           rawProfiles.contains(where: { $0.value != nil }) {
            let triggers = ((try? JSONDecoder().decode([FailableValue<RadialMenuLegacyTriggers>].self, from: data)) ?? [])
                .compactMap(\.value)
            let profiles = RadialMenuSupport.decodeProfiles(data, defaults: defaults)
            let middleClickOwned = AppFeature.middleClick.isAvailable(in: defaults)
                && defaults.bool(forKey: DefaultsKey.middleClickEnabled)
                && defaults.integer(forKey: DefaultsKey.middleClickTapFingers) == 4
            let result = migrate(profiles: profiles,
                                 triggers: triggers,
                                 storedShortcut: defaults.string(forKey: DefaultsKey.radialMenuShortcut),
                                 middleClickOwnedFourFingerTap: middleClickOwned)
            defaults.set(RadialMenuSupport.encodeProfiles(result.profiles), forKey: DefaultsKey.radialMenuProfiles)
            defaults.set(result.shortcut, forKey: DefaultsKey.radialMenuShortcut)
            defaults.set(result.mouseButton, forKey: DefaultsKey.radialMenuMouseButton)
            defaults.set(result.trackpadGesture.rawValue, forKey: DefaultsKey.radialMenuTrackpadGesture)
        }
        // Before profiles there was one wheel whose shortcut and mouse button
        // already lived in the menu-wide keys, so there is nothing to move.
        defaults.removeObject(forKey: DefaultsKey.legacyRadialMenuAtPointer)
        defaults.removeObject(forKey: DefaultsKey.legacyRadialMenuActivationMode)
        defaults.set(currentVersion, forKey: DefaultsKey.radialMenuSettingsVersion)
        return true
    }

    private struct FailableValue<Value: Decodable>: Decodable {
        let value: Value?
        init(from decoder: Decoder) throws { value = try? Value(from: decoder) }
    }
}
