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
        let pairs = legacyPairs(defaults.data(forKey: DefaultsKey.radialMenuProfiles))
        if !pairs.isEmpty {
            let middleClickOwned = AppFeature.middleClick.isAvailable(in: defaults)
                && defaults.bool(forKey: DefaultsKey.middleClickEnabled)
                && defaults.integer(forKey: DefaultsKey.middleClickTapFingers) == 4
            let result = migrate(profiles: RadialMenuSupport.sanitizedProfiles(pairs.map(\.profile)),
                                 triggers: pairs.map(\.triggers),
                                 storedShortcut: defaults.string(forKey: DefaultsKey.radialMenuShortcut),
                                 middleClickOwnedFourFingerTap: middleClickOwned)
            // The profiles go last: stopped before them, a rerun still starts
            // from the old profiles and derives the same triggers again.
            defaults.set(result.shortcut, forKey: DefaultsKey.radialMenuShortcut)
            defaults.set(result.mouseButton, forKey: DefaultsKey.radialMenuMouseButton)
            defaults.set(result.trackpadGesture.rawValue, forKey: DefaultsKey.radialMenuTrackpadGesture)
            defaults.set(RadialMenuSupport.encodeProfiles(result.profiles), forKey: DefaultsKey.radialMenuProfiles)
        }
        // Before profiles there was one wheel whose shortcut and mouse button
        // already lived in the menu-wide keys, so there is nothing to move.
        defaults.removeObject(forKey: DefaultsKey.legacyRadialMenuAtPointer)
        defaults.removeObject(forKey: DefaultsKey.legacyRadialMenuActivationMode)
        defaults.set(currentVersion, forKey: DefaultsKey.radialMenuSettingsVersion)
        return true
    }

    /// The stored profiles that decode, each with the triggers of its own
    /// record under the ID it ends up with: a record without an ID keeps its
    /// triggers, and one whose profile fails to decode lends none to a later
    /// profile sharing its ID.
    static func legacyPairs(_ data: Data?) -> [(profile: RadialMenuProfile, triggers: RadialMenuLegacyTriggers)] {
        guard let data, let records = try? JSONDecoder().decode([LegacyRecord].self, from: data) else { return [] }
        return records.compactMap { record in
            guard let profile = record.profile else { return nil }
            var triggers = record.triggers
            triggers.id = profile.id
            return (profile, triggers)
        }
    }

    /// One stored profile, read both as today's profile and as the
    /// triggers it carried.
    private struct LegacyRecord: Decodable {
        let profile: RadialMenuProfile?
        let triggers: RadialMenuLegacyTriggers

        init(from decoder: Decoder) throws {
            profile = try? RadialMenuProfile(from: decoder)
            triggers = (try? RadialMenuLegacyTriggers(from: decoder)) ?? RadialMenuLegacyTriggers(id: nil)
        }
    }
}
