import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension RadialMenuSettings {
    // MARK: - Mutations (every change lands in defaults right away)

    func addProfile(preset: RadialMenuProfilePreset) {
        let name = preset == .general ? "\(text.presetGeneral) \(profiles.count + 1)" : preset.title(text)
        let newProfile = preset.createProfile(name: name)
        profiles.append(newProfile)
        selectedProfileID = newProfile.id
        openSubmenuID = nil
        dragging = nil
        persist()
    }

    func duplicateProfile() {
        let copy = selectedProfile.duplicate(named: "\(selectedProfile.displayName(text)) 2")
        profiles.append(copy)
        selectedProfileID = copy.id
        openSubmenuID = nil
        dragging = nil
        persist()
    }

    /// Deletes the profile the user confirmed, which the selection may no
    /// longer point at by the time the dialog closes.
    func deleteProfile(id: UUID) {
        guard profiles.count > 1, let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles.remove(at: index)
        let nextIndex = min(index, profiles.count - 1)
        selectedProfileID = profiles[nextIndex].id
        openSubmenuID = nil
        dragging = nil
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

    /// Restoring the actions is offered on the wheel itself, and only when the
    /// set to restore is known. A submenu is the person's own list, so there is
    /// nothing to put back into it.
    var canResetProfile: Bool { openSubmenuID == nil && resolvedPreset != nil }

    func resetToPresetDefaults() {
        guard profiles.indices.contains(selectedProfileIndex),
              let preset = resolvedPreset else { return }
        profiles[selectedProfileIndex].items = preset.makeItems()
        openSubmenuID = nil
        dragging = nil
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

    func move(_ moved: RadialMenuItem, before target: RadialMenuItem) {
        var new = level
        guard let from = new.firstIndex(where: { $0.id == moved.id }),
              let to = new.firstIndex(where: { $0.id == target.id }),
              from != to else { return }
        new.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
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

    /// Who already answers to a combination, named the way the other shortcut
    /// rows name it. The other wheels come from this page's own list, and
    /// everything else from the same checks those rows run.
    func shortcutConflictTitle(_ shortcut: GlobalShortcut, excluding profileID: UUID) -> String? {
        RadialMenuSupport.conflictTitle(
            for: shortcut,
            excluding: profileID,
            in: profiles,
            radialText: text,
            strings: l10n.s,
            additionalConflict: { SettingsShortcutConflicts.title(for: $0, language: l10n.language) }
        )
    }

    func requestAccessibilityIfNeeded(_ on: Bool) {
        guard on, RadialMenuSupport.needsAccessibility(profiles), !permissions.accessibility else { return }
        permissions.requestAccessibility()
    }

    func mouseTriggerName(for button: Int64) -> String {
        switch button {
        case MouseButtonShortcutSupport.backButtonNumber: return text.mouseTriggerBack
        case MouseButtonShortcutSupport.forwardButtonNumber: return text.mouseTriggerForward
        default:
            return MouseButtonShortcutSupport.buttonName(
                for: button, strings: FeatureStrings.mouseButtons(l10n.language))
        }
    }

    func buttonTestRow(for triggerRaw: String) -> some View {
        let seen = service.lastMouseButtonSeen
        let expected = RadialMenuMouseTrigger.sanitized(triggerRaw).buttonNumber
        let state: (icon: String, tint: Color, message: String) = {
            if !service.isWatchingMouseButton {
                return ("exclamationmark.circle.fill", .orange, text.buttonTestBlind)
            }
            guard let seen else {
                return ("circle.dashed", .secondary, text.buttonTestWaiting)
            }
            if let expected, Int64(seen) == expected {
                return ("checkmark.circle.fill", .green, text.buttonTestSeen)
            }
            return ("exclamationmark.circle.fill", .orange, text.buttonTestOther)
        }()
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: state.icon)
                    .foregroundStyle(state.tint)
                Text(text.buttonTestLabel)
                Spacer()
                Text(state.message)
                    .foregroundStyle(.secondary)
            }
            Text(text.buttonTestHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear { RadialMenuService.shared.setReportingMouseButtons(true) }
        .onDisappear { RadialMenuService.shared.setReportingMouseButtons(false) }
    }}
