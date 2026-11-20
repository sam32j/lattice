// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
/// Screenshot Settings page.
struct ScreenshotSettings: View {
    @ObservedObject var l10n = L10n.shared
    @ObservedObject private var service = ScreenshotService.shared
    @AppStorage(DefaultsKey.screenshotEnabled) var screenshotEnabled = true
    @AppStorage(DefaultsKey.screenshotFreeze) private var freeze = true
    @AppStorage(DefaultsKey.screenshotIncludePointer) private var includePointer = false
    @AppStorage(DefaultsKey.screenshotShowLastRegion) private var showLastRegion = true
    @AppStorage(DefaultsKey.screenshotPlayShutterSound) private var playShutterSound = true
    @AppStorage(DefaultsKey.screenshotLoupeStartsOn) private var loupeStartsOn = false
    @AppStorage(DefaultsKey.screenshotLoupeRememberZoom) private var rememberLoupeZoom = false
    @AppStorage(DefaultsKey.screenshotLoupeDefaultZoom) private var loupeDefaultZoom = 1.0
    @AppStorage(DefaultsKey.screenshotDownscale) private var downscale = false
    @AppStorage(DefaultsKey.screenshotSaveAutomatically) private var saveAutomatically = false
    @AppStorage(DefaultsKey.screenshotOpenEditorAfterCapture) private var openEditorAfterCapture = false
    @AppStorage(DefaultsKey.screenshotToolShortcutsEnabled) private var toolShortcutsEnabled = true
    @AppStorage(DefaultsKey.screenshotCopyToClipboard) private var copyToClipboard = false
    @AppStorage(DefaultsKey.screenshotAddToShelf) private var addToShelf = false
    @AppStorage(DefaultsKey.shelfEnabled) private var shelfEnabled = false
    @AppStorage(AppFeature.shelf.availabilityKey) private var shelfAvailable = false
    @State private var toolsExpanded = false

    var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    private var workflow: CaptureWorkflowStrings { .localized(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    captureBehaviorCard
                        .settingsSectionAnchor(.screenshot, cornerRadius: 16)
                    zoomCard
                    afterCaptureCard
                    destinationCard
                    keyboardShortcutsCard
                    toolsCard
                }
                .disabled(!screenshotInstalled)
                .opacity(screenshotInstalled ? 1 : 0.55)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .settingsExpansionAnimation(value: [rememberLoupeZoom, toolsExpanded])
    }


    // MARK: - Capture behavior

    private var captureBehaviorCard: some View {
        SettingsCard(title: strings.captureBehaviorSection) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsToggleRow(title: workflow.shutter,
                                  isOn: $playShutterSound)

                SettingsToggleRow(title: strings.hidePointerToggle,
                                  isOn: Binding(get: { !includePointer },
                                                set: { includePointer = !$0 }))

                SettingsToggleRow(title: strings.lastRegionToggle,
                                  isOn: $showLastRegion)

                SettingsToggleRow(title: strings.freezeToggle,
                                  isOn: $freeze)
            }
        }
    }

    // MARK: - Zoom

    private var zoomCard: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 2) {
                Text(strings.zoomSection).font(.headline)
                Text(strings.zoomHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 14) {
                    SettingsToggleRow(title: strings.loupeStartsOnToggle,
                                      isOn: $loupeStartsOn)
                    SettingsToggleRow(title: strings.zoomReset,
                                      isOn: Binding(get: { !rememberLoupeZoom },
                                                    set: { rememberLoupeZoom = !$0 }))
                    if !rememberLoupeZoom {
                        SettingsControlRow(title: strings.loupeDefaultZoomLabel) {
                            Picker(strings.loupeDefaultZoomLabel, selection: $loupeDefaultZoom) {
                                ForEach(ScreenshotSupport.captureLoupeDefaultZooms.indices, id: \.self) { index in
                                    Text([strings.zoomLow, strings.zoomMedium, strings.zoomHigh,
                                          strings.zoomMaximum][index])
                                        .tag(ScreenshotSupport.captureLoupeDefaultZooms[index])
                                }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
    }

    // MARK: - After capture

    private var afterCaptureCard: some View {
        SettingsCard(title: strings.afterCaptureSection) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsToggleRow(title: strings.afterCaptureCopy,
                                  isOn: $copyToClipboard)
                SettingsToggleRow(title: strings.afterCaptureSave,
                                  isOn: $saveAutomatically)
                SettingsToggleRow(title: strings.afterCaptureShelf,
                                  isOn: addToShelfBinding)
                    .disabled(!shelfIsOn)
                SettingsToggleRow(title: strings.afterCaptureEditor,
                                  isOn: $openEditorAfterCapture)
            }
        }
    }

    // MARK: - Export & Format

    private var destinationCard: some View {
        SettingsCard(title: CaptureOptionsStrings.text(.screenshotExportFormat, l10n.language)) {
            SettingsToggleRow(title: strings.downscaleToggle,
                              isOn: $downscale)
        }
    }

    // MARK: - Keyboard shortcuts

    private var keyboardShortcutsCard: some View {
        SettingsCard(title: CaptureOptionsStrings.text(.keyboardShortcuts, l10n.language)) {
            VStack(alignment: .leading, spacing: 10) {
                CompactShortcutPreferenceRow(title: strings.editLastCapture,
                                             role: .screenshotLastCapture,
                                             enabledKey: DefaultsKey.screenshotLastCaptureShortcutEnabled) {
                    ScreenshotService.shared.syncWithPreferences()
                }
                CompactShortcutPreferenceRow(title: strings.editClipboardImage,
                                             role: .screenshotClipboard,
                                             enabledKey: DefaultsKey.screenshotClipboardShortcutEnabled) {
                    ScreenshotService.shared.syncWithPreferences()
                }
            }
        }
    }

    // MARK: - Tools

    private var toolsCard: some View {
        SettingsCard {
            DisclosureGroup(strings.toolShortcutsTitle, isExpanded: $toolsExpanded) {
                ScreenshotToolOrderControls(shortcutsEnabled: $toolShortcutsEnabled,
                                            showsTitle: false)
                    .padding(.top, 10)
            }
        }
    }

    // MARK: - Bindings & Helpers

    private var shelfIsOn: Bool {
        shelfEnabled && shelfAvailable
    }

    private var addToShelfBinding: Binding<Bool> {
        Binding {
            addToShelf && shelfIsOn
        } set: { isOn in
            addToShelf = isOn
        }
    }
}
