import SwiftUI

extension WindowLayoutSettings {
    private var isEdgeSnapReset: Bool {
        edgeSnapDisabledZones.isEmpty && (edgeSnapZoneActions.isEmpty || WindowEdgeSnapLayout(storageValue: edgeSnapZoneActions) == .standard)
    }

    /// macOS tiling takes the same edges, so Lattice's snapping waits for it
    /// to be turned off in Desktop & Dock.
    private var systemTilingStatus: SettingsFeatureStatus {
        SettingsFeatureStatus(color: .red, message: text.edgeSnapSystemConflict)
    }

    var edgeSnapControls: some View {
        // The follow-up groups sit at different gaps under the switch, so
        // each carries its own and rolls it up with itself.
        VStack(alignment: .leading, spacing: 0) {
            SettingsControlRow(title: text.edgeSnapSection, caption: text.edgeSnapCaption) {
                // A conflict reads the way Super Key's and the Spaces
                // switch's do: a red status icon beside the switch, the
                // explanation in its hint.
                if systemTilingEnabled {
                    SettingsStatusDot(status: systemTilingStatus)
                }
                PermissionGatedToggle(text.edgeSnapSection, isOn: $edgeSnapEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: edgeSnapEnabled) { _, _ in
                        WindowLayoutService.shared.syncWithPreferences()
                    }
            }
            if edgeSnapEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    // Reset sits under the switch: its top level with the
                    // zone picker's, its right edge with the switch's, at
                    // the regular size of the page's other buttons.
                    HStack(alignment: .top, spacing: 12) {
                        WindowEdgeSnapZonePicker(disabledZonesStorage: $edgeSnapDisabledZones,
                                                 zoneActionsStorage: $edgeSnapZoneActions,
                                                 text: text,
                                                 resetTitle: l10n.s.shortcutReset)
                            .onChange(of: edgeSnapDisabledZones) { _, _ in
                                WindowLayoutService.shared.syncWithPreferences()
                            }
                        Spacer(minLength: 0)
                        Button(l10n.s.shortcutReset) {
                            edgeSnapDisabledZones = ""
                            edgeSnapZoneActions = ""
                            WindowLayoutService.shared.syncWithPreferences()
                        }
                        .disabled(isEdgeSnapReset)
                    }
                    Text(WindowLayoutFeatureStrings.edgeSnapCustomizeHint(l10n.language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let restore = WindowEdgeSnapRestoreStrings.localized(l10n.language)
                    SettingsControlRow(title: restore.title, caption: restore.caption) {
                        Toggle(restore.title, isOn: $edgeSnapRestoreOnDrag)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    .padding(.top, 9)
                }
                .padding(.top, 17)
                // Nothing here takes effect while macOS holds the edges, so
                // the follow-ups grey out, as Super Key's options do.
                .disabled(systemTilingEnabled)
                .transition(.settingsReveal)
            }
        }
    }
}

struct WindowLayoutShortcutsSettings: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var permissions = Permissions.shared
    @ObservedObject var service = WindowLayoutService.shared
    @ObservedObject var pointerDisplay = PointerDisplayService.shared
    @AppStorage(DefaultsKey.pointerDisplayEnabled) var pointerDisplayEnabled = false
    @AppStorage(DefaultsKey.windowDirectionalEnabled) var directionalEnabled = false
    @AppStorage(DefaultsKey.windowDirectionalShortcut) var directionalShortcutRaw = GlobalShortcut.windowDirectionalDefault.storageValue
    @AppStorage(DefaultsKey.windowLayoutHoldToCycleDisplayEnabled) var holdToCycleDisplayEnabled = false
    @AppStorage(DefaultsKey.windowLayoutHoldDelay) var holdDelay = "default"
    @State var directionalError: String?
    @State var conflictAlert: ShortcutConflictAlert?

    var text: WindowLayoutFeatureStrings {
        FeatureStrings.windowLayout(l10n.language)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 16) {
                        if !service.failedShortcutActions.isEmpty {
                            Text(l10n.s.shortcutUnavailable)
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .transition(.settingsReveal)
                        }

                        placementSections

                        Divider()
                        VStack(alignment: .leading, spacing: 13) {
                            Text(text.other).font(.headline)
                            actionRow(.maximize)
                            actionRow(.fullScreen)
                            actionRow(.center)
                            actionRow(.restore)
                            HStack {
                                Label(WindowDirectionalStrings.localized(l10n.language).title, systemImage: "circle.circle")
                                Spacer()
                                CompactShortcutBindingRecorder(
                                    recordingID: "window-layout-directional",
                                    shortcut: directionalDisplayShortcut,
                                    isEnabled: permissions.accessibility,
                                    width: 140,
                                    emptyTitle: directionalEnabled ? directionalTrigger.displayString : l10n.s.shortcutNone,
                                    canClear: directionalEnabled,
                                    canReset: true,
                                    captureModifiers: { saveDirectionalTrigger(.modifiers($0)) },
                                    errorText: $directionalError,
                                    onClear: {
                                        directionalEnabled = false
                                        service.syncWithPreferences()
                                    },
                                    onReset: { saveDirectionalShortcut(.windowDirectionalDefault) },
                                    onCapture: saveDirectionalShortcut)
                            }
                            if service.directionalShortcutRegistrationFailed {
                                Text(l10n.s.shortcutUnavailable)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .transition(.settingsReveal)
                            }
                        }

                        Divider()
                        VStack(alignment: .leading, spacing: 13) {
                            Text(text.moving).font(.headline)

                            VStack(alignment: .leading, spacing: 13) {
                                Toggle(isOn: $holdToCycleDisplayEnabled.animation(reduceMotion ? nil : .settingsExpansion)) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "inset.filled.rectangle.and.pointer.arrow")
                                            .frame(width: 18)
                                        Text(text.holdToCycleDisplay)
                                    }
                                }

                                if holdToCycleDisplayEnabled {
                                    HStack {
                                        Text(text.holdDelay)
                                        Spacer()
                                        Picker(text.holdDelay, selection: $holdDelay) {
                                            Text(text.holdDelayDefault).tag("default")
                                            Text(text.holdDelayLonger).tag("longer")
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.menu)
                                    }
                                    .padding(.leading, 18 + 8)
                                    .transition(.settingsReveal)
                                }
                            }
                            .settingsExpansionAnimation(value: holdToCycleDisplayEnabled)

                            ShortcutPreferenceRow(role: .pointerNextDisplay,
                                                  label: PointerDisplayStrings.localized(l10n.language).title,
                                                  symbolName: "pointer.arrow.motionlines",
                                                  symbolColor: nil,
                                                  additionalConflict: {
                                                      service.shortcutConflictTitle($0)
                                                  }) {
                                pointerDisplay.syncWithPreferences()
                            }
                            if pointerDisplayEnabled, pointerDisplay.shortcutRegistrationFailed {
                                Text(l10n.s.shortcutUnavailable)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                                    .transition(.settingsReveal)
                            }

                            actionRow(.previousDisplay)
                            actionRow(.nextDisplay)
                        }
                        .settingsExpansionAnimation(value: holdToCycleDisplayEnabled)
                    }
                    .toggleStyle(TrailingSwitchToggleStyle())
                }

                if !permissions.accessibility {
                    SettingsCard(title: l10n.s.permissionRequired) { PermissionRow(kind: .accessibility) }
                        .transition(.settingsReveal)
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .toggleStyle(.switch)
        .shortcutConflictAlert($conflictAlert)
        .settingsExpansionAnimation(value: [permissions.accessibility, holdToCycleDisplayEnabled])
    }
}

