// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Settings > Radial menu: profiles, colors, shortcuts, the master switch,
/// opening behavior, placement and list of actions per profile.
struct RadialMenuSettings: View {
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var permissions = Permissions.shared
    @ObservedObject var service = RadialMenuService.shared
    @AppStorage(DefaultsKey.radialMenuEnabled) var enabled = false
    @AppStorage(DefaultsKey.radialMenuAtPointer) var atPointer = true
    @AppStorage(DefaultsKey.radialMenuActivationMode) var activationModeRaw =
        RadialMenuActivationMode.pressOrHold.rawValue
    @AppStorage(DefaultsKey.middleClickEnabled) var middleClickEnabled = false
    @AppStorage(DefaultsKey.middleClickTapFingers) var middleClickTapFingers = 0

    @State var profiles: [RadialMenuProfile] = RadialMenuSupport.decodeProfiles(
        UserDefaults.standard.data(forKey: DefaultsKey.radialMenuProfiles))
    @State var lastSyncedProfilesData: Data?
    @State var selectedProfileID: UUID?
    /// The submenu being edited; empty means the root wheel.
    @State var openSubmenuID: UUID?
    @State var editing: RadialMenuItem?
    @State var dragging: RadialMenuItem?
    @State var showList = false
    @State var confirmingDeletion: RadialMenuProfile?
    @Environment(\.colorScheme) var colorScheme

    var text: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }

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
    /// restored backup can pull it away), so the list never strands empty.
    var level: [RadialMenuItem] {
        guard let openSubmenu else { return currentProfileItems }
        return openSubmenu.children
    }

    var openSubmenu: RadialMenuItem? {
        guard let openSubmenuID else { return nil }
        return currentProfileItems.first { $0.id == openSubmenuID }
    }

    var body: some View {
        Form {
            Section {
                FeatureActivationControl(feature: .radialMenu).toggleStyle(.switch)
                Text(text.hubDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if service.registrationFailed {
                    Text(l10n.s.shortcutInvalid)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Picker(text.activationModeLabel, selection: $activationModeRaw) {
                    Text(text.activationModePressOrHold)
                        .tag(RadialMenuActivationMode.pressOrHold.rawValue)
                    Text(text.activationModePress)
                        .tag(RadialMenuActivationMode.press.rawValue)
                    Text(text.activationModeHold)
                        .tag(RadialMenuActivationMode.hold.rawValue)
                }
                .disabled(!enabled)
                Text(text.activationModeCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker(text.positionLabel, selection: $atPointer) {
                    Text(text.positionPointer).tag(true)
                    Text(text.positionCenter).tag(false)
                }
                .pickerStyle(.segmented)
                Button(text.tryButton) {
                    RadialMenuService.shared.presentPreview(for: selectedProfile)
                }
            } header: {
                Text(text.pageTitle)
            }

            if RadialMenuSupport.needsAccessibility(profiles), !permissions.accessibility {
                Section {
                    PermissionRow(kind: .accessibility)
                    Text(RadialMenuSupport.usesWindowLayout(currentProfileItems)
                         ? FeatureStrings.windowLayout(l10n.language).missingPermission
                         : text.permissionCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                profileManagementRow
                if enabled, !RadialMenuSupport.hasTrigger(selectedProfile) {
                    Text(text.profileNoTrigger)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                profileConfigurationRows.id(selectedProfile.id)
            } header: {
                Text(text.profilesHeader)
            }

            Section {
                RadialMenuVisualCanvas(
                    items: level,
                    profileColor: selectedProfile.color.color(for: colorScheme),
                    text: text,
                    openSubmenu: openSubmenu,
                    onSelect: { item in editing = item },
                    onReorder: { moved, target in swap(moved, with: target) },
                    onRemove: { item in remove(id: item.id) },
                    onOpenSubmenu: { item in openSubmenuID = item.id },
                    onBack: { openSubmenuID = nil; dragging = nil },
                    onAdd: { editing = RadialMenuItem(kind: .app) },
                    onReset: canResetProfile ? { resetToPresetDefaults() } : nil
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                Text(text.canvasHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if level.count < RadialMenuSupport.maxItemsPerWheel {
                    Button {
                        editing = RadialMenuItem(kind: .app)
                    } label: {
                        Label(text.addButton, systemImage: "plus")
                    }
                }

                DisclosureGroup(showList ? text.hideListButton : text.showListButton, isExpanded: $showList) {
                    if let openSubmenu {
                        Button {
                            openSubmenuID = nil
                            dragging = nil
                        } label: {
                            Label("\(text.backButton)  \(openSubmenu.displayName(text))",
                                  systemImage: "chevron.backward")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.accentColor)
                    }
                    if level.isEmpty {
                        Text(text.emptyCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(level) { item in
                        RadialItemRow(item: item,
                                      text: text,
                                      dragging: $dragging,
                                      edit: {
                                          editing = item
                                      },
                                      remove: { remove(id: item.id) },
                                      openChildren: item.kind == .submenu ? { openSubmenuID = item.id } : nil,
                                      moveHandler: { moved, target in move(moved, before: target) })
                    }
                }
            } header: {
                Text(text.actionsHeader)
            } footer: {
                Text(level.count >= RadialMenuSupport.maxItemsPerWheel ? text.limitCaption : text.hubDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
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
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            refreshProfilesFromDefaults()
        }
        .onDrop(of: [UTType.text], delegate: RadialDragCleanupDelegate(dragging: $dragging))
        .sheet(item: $editing) { item in
            let isNew = !level.contains { $0.id == item.id }
            RadialItemEditor(text: text,
                             item: item,
                             isNew: isNew,
                             allowsSubmenu: openSubmenuID == nil,
                             openChildren: item.kind == .submenu ? { openSubmenuID = item.id } : nil,
                             save: { saved in
                                 upsert(saved)
                                 if isNew, saved.kind == .submenu {
                                     openSubmenuID = saved.id
                                 }
                             },
                             delete: isNew ? nil : { remove(id: item.id) })
        }
        .onChange(of: enabled) { _, on in
            RadialMenuService.shared.syncWithPreferences()
            requestAccessibilityIfNeeded(on)
        }
    }

}
