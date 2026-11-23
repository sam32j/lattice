// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

extension RadialMenuSettings {
    // MARK: - Mutations (every change lands in defaults right away)

    func selectProfile(_ id: UUID) {
        guard id != selectedProfileID else { return }
        selectedProfileID = id
        openSubmenuID = nil
    }

    func addProfile(preset: RadialMenuProfilePreset) {
        let name = preset == .general ? "\(text.presetGeneral) \(profiles.count + 1)" : preset.title(text)
        let newProfile = preset.createProfile(name: name)
        profiles.append(newProfile)
        selectedProfileID = newProfile.id
        openSubmenuID = nil
        persist()
    }

    /// The copy lands right after the original and is selected.
    func duplicateProfile() {
        let original = selectedProfile
        let copy = original.duplicate(named: "\(original.displayName(text)) 2")
        let index = profiles.firstIndex { $0.id == original.id }.map { $0 + 1 } ?? profiles.count
        profiles.insert(copy, at: index)
        selectedProfileID = copy.id
        openSubmenuID = nil
        persist()
    }

    /// Deletes the profile the user confirmed, which the selection may no
    /// longer point at by the time the dialog closes. Deleting the first
    /// tab makes the next one the primary.
    func deleteProfile(id: UUID) {
        guard let result = RadialProfileTabs.deleting(id, in: profiles) else { return }
        profiles = result.profiles
        if selectedProfileID == id || !profiles.contains(where: { $0.id == selectedProfileID }) {
            selectedProfileID = result.selected
        }
        openSubmenuID = nil
        persist()
    }

    func makePrimary(_ id: UUID) {
        let reordered = RadialProfileTabs.makingPrimary(id, in: profiles)
        guard reordered != profiles else { return }
        profiles = reordered
        persist()
    }

    func moveProfile(_ id: UUID, before target: UUID?) {
        let reordered = RadialProfileTabs.moving(id, before: target, in: profiles)
        tabDropTarget = nil
        tabDropAtEnd = false
        guard reordered != profiles else { return }
        profiles = reordered
        persist()
    }

    func moveProfile(_ id: UUID, by step: Int) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + step
        guard profiles.indices.contains(destination) else { return }
        profiles = RadialProfileTabs.moving(id, to: destination, in: profiles)
        persist()
    }

    func saveProfile(id: UUID, name: String, color: RadialMenuColor) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].name = name
        profiles[index].color = color
        persist()
    }

    /// The starter set the selected wheel came from. Wheels created since the
    /// profiles arrived carry it; an older one is matched by its name, which
    /// only answers while that name is still the preset's own in the language
    /// it was created in. Nothing else is a safe guess: falling back to one
    /// particular starter set replaced a renamed wheel's actions with another
    /// wheel's.
    var resolvedPreset: RadialMenuProfilePreset? {
        let current = selectedProfile
        if let stored = current.preset, let preset = RadialMenuProfilePreset(rawValue: stored) {
            return preset
        }
        return RadialMenuProfilePreset.allCases.first { preset in
            preset.title(text).caseInsensitiveCompare(current.name) == .orderedSame
                || preset.id.caseInsensitiveCompare(current.name) == .orderedSame
        }
    }

    /// Restoring the actions is offered only when the set to restore is
    /// known. A submenu is the person's own list, so there is nothing to put
    /// back into it.
    var canResetProfile: Bool { openSubmenuID == nil && resolvedPreset != nil }

    func resetToPresetDefaults() {
        guard profiles.indices.contains(selectedProfileIndex),
              let preset = resolvedPreset else { return }
        profiles[selectedProfileIndex].items = preset.makeItems()
        openSubmenuID = nil
        persist()
    }

    func setLevel(_ new: [RadialMenuItem]) {
        guard profiles.indices.contains(selectedProfileIndex) else { return }
        if let openSubmenuID, let index = profiles[selectedProfileIndex].items.firstIndex(where: { $0.id == openSubmenuID }) {
            profiles[selectedProfileIndex].items[index].children = new
        } else {
            profiles[selectedProfileIndex].items = new
        }
        persist()
    }

    func upsert(_ item: RadialMenuItem) {
        RadialMenuIconStore.invalidate(item.payload)
        var new = level
        if let index = new.firstIndex(where: { $0.id == item.id }) {
            new[index] = item
        } else {
            new.append(item)
        }
        setLevel(new)
    }

    func remove(id: UUID) {
        setLevel(level.filter { $0.id != id })
    }

    /// One slot clockwise (positive) or counter-clockwise, wrapping round
    /// the wheel.
    func move(_ item: RadialMenuItem, by step: Int) {
        var new = level
        guard new.count > 1, let from = new.firstIndex(where: { $0.id == item.id }) else { return }
        let to = ((from + step) % new.count + new.count) % new.count
        new.remove(at: from)
        new.insert(item, at: to)
        setLevel(new)
    }

    func swap(_ first: RadialMenuItem, with second: RadialMenuItem) {
        var new = level
        guard let from = new.firstIndex(where: { $0.id == first.id }),
              let to = new.firstIndex(where: { $0.id == second.id }),
              from != to else { return }
        new.swapAt(from, to)
        setLevel(new)
    }

    func refreshProfilesFromDefaults() {
        let data = UserDefaults.standard.data(forKey: DefaultsKey.radialMenuProfiles)
        guard data != lastSyncedProfilesData else { return }
        lastSyncedProfilesData = data
        let latest = RadialMenuSupport.decodeProfiles(data)
        if latest != profiles {
            profiles = latest
            if selectedProfileID == nil || !profiles.contains(where: { $0.id == selectedProfileID }) {
                selectedProfileID = profiles.first?.id
            }
        }
    }

    func persist() {
        let data = RadialMenuSupport.encodeProfiles(profiles)
        lastSyncedProfilesData = data
        UserDefaults.standard.set(data, forKey: DefaultsKey.radialMenuProfiles)
        RadialMenuService.shared.syncWithPreferences()
    }
}
