import SwiftUI

extension WindowLayoutSettings {
    private var isEdgeSnapReset: Bool {
        edgeSnapDisabledZones.isEmpty && (edgeSnapZoneActions.isEmpty || WindowEdgeSnapLayout(storageValue: edgeSnapZoneActions) == .standard)
    }

    var snappingControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 13) {
                SettingsRow(symbol: "macwindow.and.cursorarrow", title: text.edgeSnapSection, caption: text.edgeSnapCaption) {
                    PermissionGatedToggle(text.edgeSnapSection, isOn: $edgeSnapEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: edgeSnapEnabled) { _, _ in
                            WindowLayoutService.shared.syncWithPreferences()
                        }
                }
                if edgeSnapEnabled {
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
                    .padding(.leading, settingsRowTextInset)
                }
                if systemTilingEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(text.edgeSnapSystemConflict, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        if edgeSnapEnabled {
                            Text(text.edgeSnapWaitingForSystem)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button(text.edgeSnapOpenSystemSettings) {
                            NSWorkspace.shared.open(WindowEdgeSnapSupport.desktopAndDockSettingsURL)
                        }
                        .controlSize(.small)
                    }
                    .padding(.leading, settingsRowTextInset)
                }
            }

            Divider()
            VStack(alignment: .leading, spacing: 13) {
                Text(text.shortcuts).font(.headline)
                if !service.failedShortcutActions.isEmpty {
                    Text(l10n.s.shortcutUnavailable)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                HStack {
                    Text(WindowDirectionalStrings.localized(l10n.language).title)
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
                    if service.directionalShortcutRegistrationFailed {
                        Text(l10n.s.shortcutUnavailable)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            // The pointer moves without Accessibility, so this sits outside
            // the window shortcuts toggle and works before that grant.
            VStack(alignment: .leading, spacing: 13) {
                ShortcutPreferenceRow(role: .pointerNextDisplay,
                                      label: PointerDisplayStrings.localized(l10n.language).title,
                                      additionalConflict: {
                                          service.shortcutConflictTitle($0)
                                      }) {
                    pointerDisplay.syncWithPreferences()
                }
                if pointerDisplayEnabled, pointerDisplay.shortcutRegistrationFailed {
                    Text(l10n.s.shortcutUnavailable)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            placementSections

            Divider()
            VStack(alignment: .leading, spacing: 13) {
                Text(text.other).font(.headline)
                actionRow(.maximize)
                actionRow(.marginMaximize)
                // Always adjustable: the snapping panel's Maximize Margin
                // button uses it with or without a keyboard shortcut.
                marginSlider
                    .disclosureIndent()
                actionRow(.fullScreen)
                actionRow(.center)
                actionRow(.restore)
            }

            Divider()
            VStack(alignment: .leading, spacing: 13) {
                Text(text.moving).font(.headline)
                actionRow(.previousDisplay)
                actionRow(.nextDisplay)
            }
        }
    }
}
