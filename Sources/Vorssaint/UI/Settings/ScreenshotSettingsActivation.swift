// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

extension ScreenshotSettings {
    var screenshotInstalled: Bool {
        AppFeature.screenshot.isAvailable
    }

    var shortcutsCard: some View {
        SettingsCard(title: strings.pageTitle, headerAccessory: {
            HStack(spacing: 8) {
                PermissionGatedToggle(l10n.s.screenshotEnable, isOn: Binding(
                    get: { screenshotInstalled },
                    set: { enabled in
                        screenshotEnabled = enabled
                        FeatureRuntime.shared.setAvailable([.screenshot], enabled)
                        ScreenshotService.shared.syncWithPreferences()
                        ScreenTextService.shared.syncWithPreferences()
                        ScreenCaptureService.shared.syncWithPreferences()
                    }
                ), requiring: [.screenRecording])
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.regular)
                    .help(l10n.s.screenshotEnable)
                    .accessibilityLabel(l10n.s.screenshotEnable)
            }
        }) {
            VStack(alignment: .leading, spacing: 10) {
                CompactShortcutPreferenceRow(title: strings.pageTitle,
                                             role: .screenshot,
                                             enabledKey: DefaultsKey.screenshotShortcutEnabled) {
                    ScreenCaptureService.shared.syncWithPreferences()
                    ScreenshotService.shared.syncWithPreferences()
                }
                CompactShortcutPreferenceRow(title: strings.fullScreenShortcutTitle,
                                             role: .screenshotFullScreen,
                                             enabledKey: DefaultsKey.screenshotFullScreenShortcutEnabled) {
                    ScreenshotService.shared.syncWithPreferences()
                }
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
                CompactShortcutPreferenceRow(title: strings.uploadLastCapture,
                                             role: .screenshotUpload,
                                             enabledKey: DefaultsKey.screenshotUploadShortcutEnabled) {
                    ScreenshotService.shared.syncWithPreferences()
                }
                .disabled(!sharingEnabled)
                CompactShortcutPreferenceRow(title: FeatureStrings.recentCaptures(l10n.language).title,
                                             role: .recentCaptures,
                                             enabledKey: DefaultsKey.recentCapturesShortcutEnabled) {
                    RecentCaptureService.shared.syncWithPreferences()
                }
            }
            .disabled(!screenshotEnabled)
            .opacity(screenshotEnabled ? 1 : 0.55)
        }
    }
}
