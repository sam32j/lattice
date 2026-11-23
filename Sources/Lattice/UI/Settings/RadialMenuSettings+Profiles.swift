// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

extension RadialMenuSettings {
    // MARK: - Profile tabs (the editor's top bar)

    /// One tab per profile, the first being the primary; "+" adds a profile
    /// from a starter set and "…" holds the selected profile's actions.
    /// Only the tabs scroll; the two buttons stay put.
    var profileTopBar: some View {
        HStack(spacing: 6) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                            profileTab(profile, index: index)
                                .id(profile.id)
                        }
                        endDropZone
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
                .mask(
                    HStack(spacing: 0) {
                        LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 16)
                        Rectangle()
                        LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 16)
                    }
                )
                .onChange(of: selectedProfileID) { _, id in
                    guard let id else { return }
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(text.profilesHeader)

            addProfileMenu
            profileActionsMenu
                .padding(.trailing, 10)
        }
    }

    private func profileTab(_ profile: RadialMenuProfile, index: Int) -> some View {
        let selected = profile.id == selectedProfile.id
        let name = profile.displayName(text)
        return HStack(spacing: 5) {
            if index == 0 {
                Image(systemName: "star.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(selected ? AnyShapeStyle(profile.color.foreground(for: colorScheme))
                                              : AnyShapeStyle(.secondary))
                    .accessibilityHidden(true)
            }
            RadialProfileDot(color: profile.color, size: selected ? 8 : 10, onOwnFill: selected)
            Text(name)
                .font(.callout.weight(selected ? .semibold : .regular))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 140, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(selected ? AnyShapeStyle(profile.color.foreground(for: colorScheme))
                                          : AnyShapeStyle(.primary))
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(
            Capsule().fill(selected ? AnyShapeStyle(profile.color.gradient(for: colorScheme))
                                    : AnyShapeStyle(Color.primary.opacity(0.06)))
        )
        .overlay(alignment: .leading) {
            if tabDropTarget == profile.id {
                Capsule().fill(Color.accentColor).frame(width: 2, height: 22).offset(x: -4)
            }
        }
        .contentShape(Capsule())
        .onTapGesture { selectProfile(profile.id) }
        .help(index == 0 ? text.primaryHelp : name)
        .draggable(profile.id.uuidString)
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
            moveProfile(id, before: profile.id)
            return true
        } isTargeted: { targeted in
            if targeted { tabDropTarget = profile.id } else if tabDropTarget == profile.id { tabDropTarget = nil }
        }
        .focusable()
        .onKeyPress(keys: [.space, .return, .leftArrow, .rightArrow], phases: .down) { press in
            switch press.key {
            case .space, .return:
                selectProfile(profile.id)
            case .leftArrow where press.modifiers.contains(.option):
                moveProfile(profile.id, by: -1)
            case .rightArrow where press.modifiers.contains(.option):
                moveProfile(profile.id, by: 1)
            default:
                return .ignored
            }
            return .handled
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(index == 0 ? text.primaryHelp : "")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { selectProfile(profile.id) }
        .accessibilityActions {
            if index > 0 {
                Button(text.moveLeftButton) { moveProfile(profile.id, by: -1) }
                Button(text.makePrimaryButton) { makePrimary(profile.id) }
            }
            if index < profiles.count - 1 {
                Button(text.moveRightButton) { moveProfile(profile.id, by: 1) }
            }
        }
    }

    /// Dropping past the last tab moves a profile to the end.
    private var endDropZone: some View {
        Color.clear
            .frame(width: 18, height: 28)
            .overlay(alignment: .leading) {
                if tabDropAtEnd {
                    Capsule().fill(Color.accentColor).frame(width: 2, height: 22)
                }
            }
            .dropDestination(for: String.self) { items, _ in
                guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
                moveProfile(id, before: nil)
                return true
            } isTargeted: { tabDropAtEnd = $0 }
            .accessibilityHidden(true)
    }

    private var addProfileMenu: some View {
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
        .menuIndicator(.hidden)
        .fixedSize()
        .help(text.addProfileButton)
        .accessibilityLabel(text.addProfileButton)
    }

    private var profileActionsMenu: some View {
        let profile = selectedProfile
        return Menu {
            Button(text.editProfileButton) { editingProfile = profile }
            Button(text.makePrimaryButton) { makePrimary(profile.id) }
                .disabled(selectedProfileIndex == 0)
            Button(text.duplicateProfileButton) { duplicateProfile() }
            Button(text.resetActionsButton) { confirmingReset = true }
                .disabled(!canResetProfile)
            Divider()
            Button(text.deleteProfileButton, role: .destructive) { confirmingDeletion = profile }
                .disabled(profiles.count <= 1)
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(text.profileMenuButton)
        .accessibilityLabel(text.profileMenuButton)
    }
}

// MARK: - Edit profile sheet

/// Name and color of one profile, with a live preview of its tab.
struct RadialProfileEditSheet: View {
    let profile: RadialMenuProfile
    let text: RadialMenuFeatureStrings
    let cancelTitle: String
    let save: (String, RadialMenuColor) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var name: String
    @State private var color: RadialMenuColor

    init(profile: RadialMenuProfile, text: RadialMenuFeatureStrings, cancelTitle: String,
         save: @escaping (String, RadialMenuColor) -> Void) {
        self.profile = profile
        self.text = text
        self.cancelTitle = cancelTitle
        self.save = save
        _name = State(initialValue: profile.name)
        _color = State(initialValue: profile.color)
    }

    private var placeholder: String {
        profile.preset.flatMap(RadialMenuProfilePreset.init(rawValue:))?.title(text) ?? text.presetGeneral
    }

    private var shownName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? text.presetGeneral : trimmed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(text.editProfileTitle)
                .font(.headline)

            TextField(text.profileNameLabel, text: $name, prompt: Text(placeholder))
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text(text.profileColorLabel)
                RadialMenuColorPicker(selection: $color, strings: text)
            }

            HStack {
                Spacer()
                HStack(spacing: 5) {
                    RadialProfileDot(color: color, size: 8, onOwnFill: true)
                    Text(shownName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 140)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(color.foreground(for: colorScheme))
                }
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(Capsule().fill(color.gradient(for: colorScheme)))
                .accessibilityElement(children: .combine)
                Spacer()
            }

            HStack {
                Spacer()
                Button(cancelTitle) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(text.saveButton) {
                    save(name, color)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
