// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Settings > Mouse > Mouse button shortcuts: the switch, one row per mapped
/// button with its recorded combination, and a capture flow that asks for a
/// real press instead of making the user guess button numbers. The Spaces and
/// Mission Control drag (issue #1012) lives at the bottom of the same card,
/// because it hands a button a job the same way and borrows the same capture.
struct MouseButtonShortcutsSection: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var permissions = Permissions.shared
    @ObservedObject var service = MouseButtonShortcutService.shared
    @AppStorage(DefaultsKey.mouseButtonShortcutsEnabled) var enabled = false
    @AppStorage(DefaultsKey.mouseSpacesGestureEnabled) var spacesEnabled = false
    @AppStorage(DefaultsKey.mouseSpacesGestureButton) var spacesButton = 0
    @AppStorage(DefaultsKey.mouseSpacesGestureFollowsDrag) var spacesFollowsDrag = false

    @State var mappings = MouseButtonShortcutSupport.decode(
        UserDefaults.standard.dictionary(forKey: DefaultsKey.mouseButtonShortcuts) as? [String: String])
    /// A button that was just captured and is waiting for its first key
    /// combination. Nothing persists until the combination lands, so backing
    /// out leaves no half-made row behind.
    @State var pendingButton: Int64?
    @State var capturing = false
    @State var captureFeedback: String?
    @State var recordingButton: Int64?
    /// The recorder's complaint and the row it belongs to; it stays visible
    /// until that row records again, the same way the shortcut rows behave.
    @State var recordError: String?
    @State var recordErrorButton: Int64?
    @State var spacesCapturing = false
    @State var spacesFeedback: String?

    var text: MouseButtonFeatureStrings { FeatureStrings.mouseButtons(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsRow(symbol: "computermouse.fill", title: text.enableLabel, caption: text.enableCaption) {
                PermissionGatedToggle(text.enableLabel, isOn: $enabled)
                    .labelsHidden()
                    .onChange(of: enabled) { _, on in
                        if !on { stopCapture() }
                        MouseButtonShortcutService.shared.syncWithPreferences()
                        if on, !permissions.accessibility {
                            permissions.requestAccessibility()
                        }
                    }
            }
            if enabled {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(MouseButtonShortcutSupport.sortedButtons(mappings), id: \.self) { button in
                        mappingRow(button, shortcut: mappings[button])
                    }
                    if let pendingButton {
                        mappingRow(pendingButton, shortcut: nil)
                    }
                    captureRow.frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.leading, settingsRowTextInset)
            }
            Divider()
            SettingsRow(symbol: "rectangle.3.group", title: text.spacesEnableLabel,
                        caption: text.spacesEnableCaption) {
                if !spacesCommandsAreReachable {
                    SettingsStatusDot(status: SettingsFeatureStatus(color: .red,
                                                                  message: text.spacesShortcutsOffNote))
                }
                PermissionGatedToggle(text.spacesEnableLabel, isOn: $spacesEnabled)
                    .labelsHidden()
                    .disabled(!spacesCommandsAreReachable)
                    .onChange(of: spacesEnabled) { _, on in
                        if !on {
                            stopSpacesCapture()
                            // The row is gone while this switch is off, so a kept
                            // binding could only act invisibly: it would refuse
                            // the button to shortcut capture, then come back dead
                            // under a shortcut recorded meanwhile.
                            spacesButton = 0
                        }
                        MouseButtonShortcutService.shared.syncWithPreferences()
                        if on, !permissions.accessibility {
                            permissions.requestAccessibility()
                        }
                    }
            }
            if spacesEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    spacesRow.frame(maxWidth: .infinity, alignment: .trailing)
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(text.spacesFollowsDragLabel)
                            Text(text.spacesFollowsDragCaption)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                        Toggle(text.spacesFollowsDragLabel, isOn: $spacesFollowsDrag)
                            .labelsHidden()
                    }
                }
                .padding(.leading, settingsRowTextInset)
            }
        }
        .settingsSectionAnchor(.mouseButtonShortcuts, cornerRadius: 16)
        .onDisappear {
            stopCapture()
            stopSpacesCapture()
        }
    }

}
