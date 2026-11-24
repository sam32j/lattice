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
            // Scrolled through its own position, so bringing the selected
            // tab into view never scrolls the page around it.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Self.tabSpacing) {
                    let destination = tabDragDestination
                    ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                        let isDragged = tabDrag?.id == profile.id
                        profileTab(profile, index: index)
                            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                                tabWidths[profile.id] = width
                            }
                            // The dragged tab tracks the pointer; the tabs it
                            // passes slide aside to open its slot.
                            .offset(x: isDragged ? (tabDrag?.translation ?? 0)
                                                 : tabShift(for: index, destination: destination))
                            .animation(isDragged || reduceMotion ? nil : .easeInOut(duration: 0.15),
                                       value: destination)
                            .zIndex(isDragged ? 1 : 0)
                            .gesture(tabReorderGesture(for: profile.id, index: index))
                            .id(profile.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .scrollPosition(id: $tabScrollID, anchor: .center)
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
                withAnimation(.easeOut(duration: 0.2)) { tabScrollID = id }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(text.profilesHeader)
            .help(text.profilesHelp)

            addProfileMenu
            profileActionsMenu
                .padding(.trailing, 10)
        }
    }

    private func profileTab(_ profile: RadialMenuProfile, index: Int) -> some View {
        let selected = profile.id == selectedProfile.id
        let name = profile.displayName(text)
        let submenu = selected ? openSubmenu : nil
        let foreground = selected ? AnyShapeStyle(profile.color.foreground(for: colorScheme))
                                  : AnyShapeStyle(.primary)
        return HStack(spacing: 0) {
            HStack(spacing: 5) {
                // The primary's star is its mark; the others carry their dot.
                if index == 0 {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(selected ? foreground : AnyShapeStyle(profile.color.color(for: colorScheme)))
                        .accessibilityHidden(true)
                } else {
                    RadialProfileDot(color: profile.color, size: selected ? 8 : 10, onOwnFill: selected)
                }
                Text(name)
                    .font(.callout.weight(selected ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 140, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(foreground)
            }
            .padding(.leading, 10)
            .padding(.trailing, submenu == nil ? 10 : 14)
            .frame(height: 28)
            .background(
                RadialAppendingPillSegment(pointed: submenu != nil)
                    .fill(selected ? AnyShapeStyle(profile.color.gradient(for: colorScheme))
                                   : AnyShapeStyle(Color.primary.opacity(0.06)))
            )
            .zIndex(1)
            if let submenu {
                // Inside a submenu the tab grows a segment naming it; the
                // profile's part leads back to the profile's own wheel.
                Text(submenu.displayName(text, stableToggles: true))
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 140, alignment: .leading)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.leading, 16)
                    .padding(.trailing, 12)
                    .frame(height: 28)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                               bottomTrailingRadius: 14, topTrailingRadius: 14,
                                               style: .continuous)
                            .fill(profile.color.color(for: colorScheme).opacity(0.22))
                    )
                    .padding(.leading, -10)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: submenu?.id)
        .overlay {
            // Keyboard focus on a tab other than the selected one. A click
            // selects the tab it focuses, so this never rings a clicked tab.
            if focusedTabID == profile.id, !selected {
                Capsule().strokeBorder(Color.accentColor.opacity(0.8), lineWidth: 2)
            }
        }
        .contentShape(Capsule())
        .onTapGesture { activateTab(profile.id, selected: selected) }
        .help(index == 0 ? text.primaryHelp : name)
        .focusable()
        .focusEffectDisabled()
        .focused($focusedTabID, equals: profile.id)
        .onKeyPress(keys: [.space, .return, .leftArrow, .rightArrow], phases: .down) { press in
            switch press.key {
            case .space, .return:
                activateTab(profile.id, selected: selected)
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
        .accessibilityLabel(submenu.map { "\(name), \($0.displayName(text, stableToggles: true))" } ?? name)
        .accessibilityValue(index == 0 ? text.primaryHelp : "")
        .accessibilityHint(submenu != nil ? text.backButton : "")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { activateTab(profile.id, selected: selected) }
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

    /// Click, Return, Space and the accessibility action alike: the selected
    /// tab leads back out of a submenu, another tab selects its profile.
    private func activateTab(_ id: UUID, selected: Bool) {
        if selected, openSubmenuID != nil { openSubmenuID = nil } else { selectProfile(id) }
    }

    // MARK: Reordering by drag

    static let tabSpacing: CGFloat = 6

    private var orderedTabWidths: [CGFloat] { profiles.map { tabWidths[$0.id] ?? 0 } }

    /// The slot the dragged tab would land in now.
    private var tabDragDestination: Int? {
        guard let tabDrag else { return nil }
        if let landing = tabDrag.landing { return landing }
        return RadialProfileTabs.dragDestination(widths: orderedTabWidths, spacing: Self.tabSpacing,
                                                 from: tabDrag.startIndex, translation: tabDrag.translation)
    }

    private func tabShift(for index: Int, destination: Int?) -> CGFloat {
        guard let tabDrag, let destination else { return 0 }
        return RadialProfileTabs.dragShift(index: index, from: tabDrag.startIndex, destination: destination,
                                           widths: orderedTabWidths, spacing: Self.tabSpacing)
    }

    /// Drawn by SwiftUI rather than handed to the system's drag and drop,
    /// whose floating copy sat over the tab left in the strip. A short move
    /// still counts as a click.
    private func tabReorderGesture(for id: UUID, index: Int) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                guard !tabSettling else { return }
                if tabDrag?.id != id {
                    tabDrag = RadialTabDrag(id: id, startIndex: index, translation: 0, landing: nil)
                }
                tabDrag?.translation = value.translation.width
            }
            .onEnded { _ in
                guard !tabSettling, let drag = tabDrag, drag.id == id,
                      let destination = tabDragDestination else { return }
                tabSettling = true
                // The slot is decided now. Measured while the tab slides into
                // it, a narrower neighbour could hand the slot back for a
                // moment and the opened gap would bounce.
                tabDrag?.landing = destination
                let settle = RadialProfileTabs.dragSettleOffset(from: drag.startIndex, destination: destination,
                                                                widths: orderedTabWidths,
                                                                spacing: Self.tabSpacing)
                // Settle into the slot first, then commit the order with no
                // animation: every tab already sits where the new order puts it.
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { tabDrag?.translation = settle }
                DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.12)) {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        if destination != drag.startIndex {
                            profiles = RadialProfileTabs.moving(id, to: destination, in: profiles)
                        }
                        tabDrag = nil
                        tabSettling = false
                    }
                    if destination != drag.startIndex { persist() }
                }
            }
    }

    private var addProfileMenu: some View {
        Menu {
            Button(text.newBlankProfileButton) { addProfile(preset: .blank) }
            Divider()
            Section(text.presetProfilesHeader) {
                ForEach(RadialMenuProfilePreset.allCases.filter { $0 != .blank }) { preset in
                    Button(preset.title(text)) {
                        addProfile(preset: preset)
                    }
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

    /// The name a blank entry saves as: the tab's own fallback
    /// (`RadialMenuProfile.displayName`), whatever preset the wheel came from.
    private var placeholder: String { text.presetGeneral }

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
                    // Blank is the automatic name, as the preview shows it.
                    save(name.trimmingCharacters(in: .whitespacesAndNewlines), color)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}

/// A tab's leading segment: a capsule, or, with a submenu appended, a
/// capsule whose trailing end comes to a point over the segment after it.
struct RadialAppendingPillSegment: Shape {
    var pointed: Bool

    func path(in rect: CGRect) -> Path {
        guard pointed else { return Capsule().path(in: rect) }
        let radius = rect.height / 2
        let tip: CGFloat = 8
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tip, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - tip, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.midY), radius: radius,
                    startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// A profile tab being dragged in the Settings strip.
struct RadialTabDrag: Equatable {
    let id: UUID
    let startIndex: Int
    var translation: CGFloat
    /// Set on release: the slot it settles into.
    var landing: Int?
}
