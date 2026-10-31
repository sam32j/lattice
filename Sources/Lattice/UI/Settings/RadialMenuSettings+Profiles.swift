import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension RadialMenuSettings {
    // MARK: - Profile Rows

    var profileManagementRow: some View {
        HStack(spacing: 8) {
            Picker(text.profilePickerLabel, selection: Binding(
                get: { selectedProfile.id },
                set: { newID in
                    selectedProfileID = newID
                    openSubmenuID = nil
                    dragging = nil
                }
            )) {
                ForEach(profiles) { profile in
                    Text(profile.displayName(text))
                        .tag(profile.id)
                }
            }
            .disabled(!enabled)

            Menu {
                ForEach(RadialMenuProfilePreset.allCases) { preset in
                    Button(preset.title(text)) {
                        addProfile(preset: preset)
                    }
                }
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(text.addProfileButton)
            .disabled(!enabled)

            Button {
                duplicateProfile()
            } label: {
                Image(systemName: "plus.square.on.square")
            }
            .buttonStyle(.borderless)
            .help(text.duplicateProfileButton)
            .disabled(!enabled)

            Button {
                confirmingDeletion = selectedProfile
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(text.deleteProfileButton)
            .disabled(!enabled || profiles.count <= 1)
            .confirmationDialog(
                String(format: text.deleteProfileConfirmFormat, confirmingDeletion?.displayName(text) ?? ""),
                isPresented: Binding(get: { confirmingDeletion != nil },
                                     set: { if !$0 { confirmingDeletion = nil } }),
                titleVisibility: .visible,
                presenting: confirmingDeletion
            ) { profile in
                Button(text.deleteProfileButton, role: .destructive) {
                    deleteProfile(id: profile.id)
                }
                Button(l10n.s.uninstallerCancel, role: .cancel) {}
            } message: { _ in
                Text(text.deleteProfileConfirmMessage)
            }
        }
    }

    @ViewBuilder
    var profileConfigurationRows: some View {
        let profile = selectedProfile
        let pIndex = selectedProfileIndex

        TextField(text.profileNameLabel, text: Binding(
            get: { profile.name },
            set: { newName in
                guard profiles.indices.contains(pIndex) else { return }
                profiles[pIndex].name = newName
                persist()
            }
        ), prompt: Text(text.presetGeneral))
        .disabled(!enabled)

        HStack {
            Text(text.profileColorLabel)
            Spacer()
            RadialMenuColorPicker(
                selection: Binding(
                    get: { profile.color },
                    set: { newColor in
                        guard profiles.indices.contains(pIndex) else { return }
                        profiles[pIndex].color = newColor
                        persist()
                    }
                ),
                strings: text
            )
        }
        .disabled(!enabled)

        ProfileShortcutRow(
            shortcutValue: Binding(
                get: { profile.shortcut },
                set: { newShortcut in
                    guard profiles.indices.contains(pIndex) else { return }
                    profiles[pIndex].shortcut = newShortcut
                    if pIndex == 0 {
                        UserDefaults.standard.set(newShortcut, forKey: DefaultsKey.radialMenuShortcut)
                    }
                    persist()
                }
            ),
            isEnabled: enabled,
            text: text,
            l10n: l10n,
            conflictTitle: { shortcutConflictTitle($0, excluding: profile.id) },
            onChange: {
                persist()
            }
        )

        PermissionGatedPicker(title: text.profileMouseTriggerLabel, selection: Binding(
            get: { profile.mouseButton },
            set: { newTrigger in
                guard RadialProfileActivation.index(requestedID: profile.id, selectedID: selectedProfile.id,
                    enabled: enabled, profiles: profiles) != nil else { return }
                // One wheel owns each button: claiming it here releases the others.
                profiles = RadialMenuSupport.assigning(mouseButton: newTrigger,
                                                       to: profile.id, in: profiles)
                persist()
            }
        ), requiring: { RadialMenuMouseTrigger.sanitized($0) == .off ? [] : [.accessibility] }) {
            Text(text.mouseTriggerOff).tag(RadialMenuMouseTrigger.off.rawValue)
            ForEach(Array(MouseButtonShortcutSupport.buttonRange), id: \.self) { button in
                Text(mouseTriggerName(for: button))
                    .tag(RadialMenuMouseTrigger.button(button).rawValue)
            }
        }
        .disabled(!enabled)

        Text(text.mouseTriggerRequirement)
            .font(.caption)
            .foregroundStyle(.secondary)

        if RadialMenuMouseTrigger.sanitized(profile.mouseButton) != .off {
            if let button = RadialMenuMouseTrigger.sanitized(profile.mouseButton).buttonNumber,
               button == MouseButtonShortcutSupport.backButtonNumber
                || button == MouseButtonShortcutSupport.forwardButtonNumber {
                Text(text.mouseTriggerWarning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            buttonTestRow(for: profile.mouseButton)
        }

        PermissionGatedToggle(text.trackpadTapLabel, isOn: Binding(
            get: { profile.trackpadTap },
            set: { on in
                guard let pIndex = RadialProfileActivation.index(requestedID: profile.id, selectedID: selectedProfile.id,
                    enabled: enabled, profiles: profiles) else { return }
                // One wheel owns the tap: claiming it here releases the others.
                for index in profiles.indices { profiles[index].trackpadTap = on && index == pIndex }
                persist()
            }
        ))
        .disabled(!enabled)

        if profile.trackpadTap, MiddleClickSupport.radialMenuTapFingers(
            radialMenuWantsTap: true,
            middleClickTapFingers: AppFeature.middleClick.isAvailable && middleClickEnabled
                ? middleClickTapFingers : 0) == 0 {
            Text(text.trackpadTapConflict)
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

}
