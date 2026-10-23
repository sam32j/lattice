// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

extension ScreenRecorderSettings {
    var screenRecorderInstalled: Bool {
        AppFeature.screenRecorder.isAvailable
    }

    var shortcutsCard: some View {
        SettingsCard(title: strings.pageTitle, headerAccessory: {
            HStack(spacing: 8) {
                PermissionGatedToggle(l10n.s.screenRecorderEnable, isOn: Binding(
                    get: { screenRecorderInstalled },
                    set: { enabled in
                        screenRecorderEnabled = enabled
                        FeatureRuntime.shared.setAvailable([.screenRecorder], enabled)
                        ScreenCaptureService.shared.syncWithPreferences()
                        ScreenRecorderService.shared.syncWithPreferences()
                    }
                ), requiring: [.screenRecording])
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.regular)
                    .help(l10n.s.screenRecorderEnable)
                    .accessibilityLabel(l10n.s.screenRecorderEnable)
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                CompactShortcutPreferenceRow(title: strings.pageTitle,
                                             role: .screenRecorder,
                                             enabledKey: DefaultsKey.recorderShortcutEnabled) {
                    ScreenCaptureService.shared.syncWithPreferences()
                    ScreenRecorderService.shared.syncWithPreferences()
                }
                CompactShortcutPreferenceRow(title: FeatureStrings.recentCaptures(l10n.language).title,
                                             role: .recentCaptures,
                                             enabledKey: DefaultsKey.recentCapturesShortcutEnabled) {
                    RecentCaptureService.shared.syncWithPreferences()
                }
            }
            .disabled(!screenRecorderEnabled)
            .opacity(screenRecorderEnabled ? 1 : 0.55)
        }
    }
}
