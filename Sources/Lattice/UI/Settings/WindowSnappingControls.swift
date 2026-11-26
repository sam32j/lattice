import SwiftUI

extension WindowLayoutSettings {
    private var isEdgeSnapReset: Bool {
        edgeSnapDisabledZones.isEmpty && (edgeSnapZoneActions.isEmpty || WindowEdgeSnapLayout(storageValue: edgeSnapZoneActions) == .standard)
    }

    var edgeSnapControls: some View {
        // The follow-up groups sit at different gaps under the switch, so
        // each carries its own and rolls it up with itself.
        VStack(alignment: .leading, spacing: 0) {
            SettingsControlRow(title: text.edgeSnapSection, caption: text.edgeSnapCaption) {
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
                .transition(.settingsReveal)
            }
            if systemTilingEnabled {
                // The same notice shape as secure input and permission rows:
                // an attention icon beside plain text, the detail as a caption,
                // and the fix as a small button underneath.
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                        Text(text.edgeSnapSystemConflict)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if edgeSnapEnabled {
                        Text(text.edgeSnapWaitingForSystem)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.settingsReveal)
                    }
                    Button(text.edgeSnapOpenSystemSettings) {
                        NSWorkspace.shared.open(WindowEdgeSnapSupport.desktopAndDockSettingsURL)
                    }
                    .controlSize(.small)
                }
                .padding(.top, 13)
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
