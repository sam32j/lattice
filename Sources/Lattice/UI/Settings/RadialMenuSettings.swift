// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Settings > Radial Menu: a header with the feature's switch, then cards.
/// "Open the menu" holds the one shortcut, trackpad gesture and mouse button
/// that open it; the editor holds the profiles (tabs) and the wheel of the
/// selected one, where every action is added, edited, moved and removed.
struct RadialMenuSettings: View {
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var permissions = Permissions.shared
    @ObservedObject var service = RadialMenuService.shared
    @ObservedObject var middleClick = MiddleClickService.shared
    @ObservedObject var runtime = FeatureRuntime.shared
    @AppStorage(DefaultsKey.radialMenuEnabled) var enabled = false
    @AppStorage(DefaultsKey.radialMenuShortcut) var shortcutRaw = GlobalShortcut.radialMenuDefault.storageValue
    @AppStorage(DefaultsKey.radialMenuMouseButton) var mouseButtonRaw = RadialMenuMouseTrigger.off.rawValue
    @AppStorage(DefaultsKey.radialMenuTrackpadGesture) var trackpadGestureRaw = RadialMenuTrackpadGesture.off.rawValue
    @AppStorage(DefaultsKey.middleClickEnabled) var middleClickEnabled = false
    @AppStorage(DefaultsKey.middleClickTapFingers) var middleClickTapFingers = 0
    @AppStorage(DefaultsKey.middleClickClickFingers) var middleClickClickFingers = 3

    @State var profiles: [RadialMenuProfile] = RadialMenuSupport.decodeProfiles(
        UserDefaults.standard.data(forKey: DefaultsKey.radialMenuProfiles))
    @State var lastSyncedProfilesData: Data?
    @State var selectedProfileID: UUID?
    /// The submenu being edited; nil means the root wheel.
    @State var openSubmenuID: UUID?

    init(openSubmenuID: UUID? = nil) {
        _openSubmenuID = State(initialValue: openSubmenuID)
    }
    @State var editing: RadialMenuItem?
    @State var editingProfile: RadialMenuProfile?
    @State var confirmingDeletion: RadialMenuProfile?
    @State var confirmingReset = false
    @State var conflictAlert: ShortcutConflictAlert?
    @State var invalidShortcutMessage: String?
    @State var pendingTakeover: RadialMenuTrackpadGesture?
    @State var gestureCoordinator: PermissionActivationCoordinator?
    @FocusState var focusedTabID: UUID?
    /// A tab being dragged: which, from what slot, and how far the pointer
    /// has moved. The order stays put until the tab is let go.
    @State var tabDrag: RadialTabDrag?
    /// A released tab is settling into its slot; a new drag waits for it.
    @State var tabSettling = false
    /// Each tab's measured width, for slots of differing size.
    @State var tabWidths: [UUID: CGFloat] = [:]
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State var tabScrollID: UUID?
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.settingsPermissionAccess) var permissionAccess

    var text: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }

    var featureOn: Bool { runtime.isAvailable(.radialMenu) }

    var selectedProfileIndex: Int {
        if let selectedProfileID, let idx = profiles.firstIndex(where: { $0.id == selectedProfileID }) {
            return idx
        }
        return 0
    }

    var selectedProfile: RadialMenuProfile {
        if profiles.indices.contains(selectedProfileIndex) {
            return profiles[selectedProfileIndex]
        }
        return profiles.first ?? RadialMenuProfilePreset.general.createProfile()
    }

    var currentProfileItems: [RadialMenuItem] {
        selectedProfile.items
    }

    /// Falls back to the root when the drilled submenu no longer exists (a
    /// restored backup can pull it away), so the editor never strands empty.
    var level: [RadialMenuItem] {
        guard let openSubmenu else { return currentProfileItems }
        return openSubmenu.children
    }

    var openSubmenu: RadialMenuItem? {
        guard let openSubmenuID else { return nil }
        return currentProfileItems.first { $0.id == openSubmenuID }
    }

    var mouseButton: RadialMenuMouseTrigger { RadialMenuMouseTrigger.sanitized(mouseButtonRaw) }
    var trackpadGesture: RadialMenuTrackpadGesture { RadialMenuTrackpadGesture.sanitized(trackpadGestureRaw) }

    var showsPermissionCard: Bool {
        RadialMenuSupport.needsAccessibility(profiles, mouseButton: mouseButton, trackpadGesture: trackpadGesture)
            && !permissions.accessibility
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                openCard
                if featureOn {
                    if showsPermissionCard { permissionCard }
                    editorCard
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(22)
            .frame(maxWidth: .infinity)
        }
        .settingsExpansionAnimation(value: [showsPermissionCard, featureOn])
        .onAppear {
            let data = UserDefaults.standard.data(forKey: DefaultsKey.radialMenuProfiles)
            lastSyncedProfilesData = data
            let latest = RadialMenuSupport.decodeProfiles(data)
            if latest != profiles {
                profiles = latest
            }
            if selectedProfileID == nil || !profiles.contains(where: { $0.id == selectedProfileID }) {
                selectedProfileID = profiles.first?.id
            }
            middleClick.refreshDragGestureConflict()
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            refreshProfilesFromDefaults()
        }
        .sheet(item: $editing) { item in
            let isNew = !level.contains { $0.id == item.id }
            RadialItemEditor(text: text,
                             item: item,
                             isNew: isNew,
                             allowsSubmenu: openSubmenuID == nil,
                             profileColor: selectedProfile.color,
                             save: { saved in
                                 upsert(saved)
                                 if isNew, saved.kind == .submenu {
                                     openSubmenuID = saved.id
                                 }
                             },
                             delete: isNew ? nil : { remove(id: item.id) })
        }
        .sheet(item: $editingProfile) { profile in
            RadialProfileEditSheet(profile: profile, text: text, cancelTitle: l10n.s.uninstallerCancel) { name, color in
                saveProfile(id: profile.id, name: name, color: color)
            }
        }
        .confirmationDialog(
            String(format: text.deleteProfileConfirmFormat, confirmingDeletion?.displayName(text) ?? ""),
            isPresented: Binding(get: { confirmingDeletion != nil },
                                 set: { if !$0 { confirmingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: confirmingDeletion
        ) { profile in
            Button(text.deleteProfileConfirmButton, role: .destructive) {
                deleteProfile(id: profile.id)
            }
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
        } message: { profile in
            if let next = RadialProfileTabs.nextPrimary(afterDeleting: profile.id, in: profiles) {
                Text(String(format: text.deletePrimaryConfirmMessageFormat, next.displayName(text)))
            } else {
                Text(text.deleteProfileConfirmMessage)
            }
        }
        .confirmationDialog(text.resetActionsConfirm, isPresented: $confirmingReset, titleVisibility: .visible) {
            Button(text.resetActionsConfirm, role: .destructive) { resetToPresetDefaults() }
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
        } message: {
            Text(text.resetActionsConfirmMessage)
        }
        .alert(pendingTakeover == .click ? text.takeoverClickTitle : text.takeoverTapTitle,
               isPresented: Binding(get: { pendingTakeover != nil },
                                    set: { if !$0 { pendingTakeover = nil } }),
               presenting: pendingTakeover) { gesture in
            Button(text.takeoverConfirm) { applyTrackpadGesture(gesture) }
                .keyboardShortcut(.defaultAction)
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
        } message: { _ in
            Text(text.takeoverMessage)
        }
        .permissionActivationLifetime($gestureCoordinator)
    }

    // MARK: - Permission

    private var permissionCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 6) {
                PermissionRow(kind: .accessibility)
                Text(text.permissionCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .help(text.permissionCaption)
            }
        }
    }

    // MARK: - Editor

    private var editorCard: some View {
        VStack(spacing: 0) {
            profileTopBar
                .frame(height: 44)
            RadialMenuVisualCanvas(
                items: level,
                profileColor: selectedProfile.color,
                text: text,
                isSubmenu: openSubmenu != nil,
                onEdit: { item in editing = item },
                onSwap: { moved, target in swap(moved, with: target) },
                onMove: { item, step in move(item, by: step) },
                onRemove: { item in remove(id: item.id) },
                onOpenSubmenu: { item in openSubmenuID = item.id },
                onBack: { openSubmenuID = nil },
                onAdd: { editing = RadialMenuItem(kind: .app) }
            )
            .id("\(selectedProfile.id).\(openSubmenuID?.uuidString ?? "root")")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 360)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(text.editorLabel)
    }
}
