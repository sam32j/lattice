// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct ScratchpadSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var scratchpad = ScratchpadService.shared
    @AppStorage(DefaultsKey.scratchpadShortcutEnabled) private var scratchpadShortcutEnabled = false
    @AppStorage(DefaultsKey.scratchpadRetention) private var scratchpadRetention = ScratchpadRetention.never.rawValue
    @AppStorage(DefaultsKey.scratchpadCloseOnClickOutside) private var scratchpadCloseOnClickOutside = true
    @AppStorage(DefaultsKey.scratchpadBackgroundOpacity) private var scratchpadBackgroundOpacity = 0.0
    @AppStorage(DefaultsKey.scratchpadTextSize) private var scratchpadTextSize = ScratchpadSupport.defaultTextSize

    var body: some View {
        Form {
            Section {
                Text(FeatureStrings.scratchpad(l10n.language).panelCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker(FeatureStrings.scratchpad(l10n.language).retentionTitle,
                       selection: $scratchpadRetention) {
                    Text(FeatureStrings.scratchpad(l10n.language).retentionNever)
                        .tag(ScratchpadRetention.never.rawValue)
                    Text(FeatureStrings.scratchpad(l10n.language).retentionDay)
                        .tag(ScratchpadRetention.day.rawValue)
                    Text(FeatureStrings.scratchpad(l10n.language).retentionWeek)
                        .tag(ScratchpadRetention.week.rawValue)
                    Text(FeatureStrings.scratchpad(l10n.language).retentionMonth)
                        .tag(ScratchpadRetention.month.rawValue)
                }
                Text(FeatureStrings.scratchpad(l10n.language).retentionCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(FeatureStrings.scratchpad(l10n.language).closeOnClickOutside,
                       isOn: $scratchpadCloseOnClickOutside)
                    .onChange(of: scratchpadCloseOnClickOutside) { _, _ in
                        ScratchpadService.shared.outsideClickPreferenceDidChange()
                    }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(FeatureStrings.scratchpad(l10n.language).textSize)
                        Spacer()
                        Text("\(Int(ScratchpadSupport.sanitizedTextSize(scratchpadTextSize)))")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: scratchpadTextSizeBinding,
                           in: ScratchpadSupport.textSizeRange,
                           step: 1)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(FeatureStrings.scratchpad(l10n.language).backgroundOpacity)
                    Slider(value: scratchpadBackgroundOpacityBinding,
                           in: ScratchpadSupport.backgroundOpacityRange,
                           step: 0.05)
                    HStack {
                        Text(FeatureStrings.scratchpad(l10n.language).backgroundTranslucent)
                        Spacer()
                        Text(FeatureStrings.scratchpad(l10n.language).backgroundOpaque)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                ShortcutPreferenceRow(role: .scratchpad) {
                    ScratchpadService.shared.syncWithPreferences()
                }
                if scratchpadShortcutEnabled, scratchpad.shortcutRegistrationFailed {
                    Text(l10n.s.shortcutUnavailable)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text(FeatureStrings.scratchpad(l10n.language).pageTitle)
            }
            .settingsFormSectionAnchor(.scratchpad)
        }
        .formStyle(.grouped)
    }

    private var scratchpadBackgroundOpacityBinding: Binding<Double> {
        Binding(
            get: { ScratchpadSupport.sanitizedBackgroundOpacity(scratchpadBackgroundOpacity) },
            set: { scratchpadBackgroundOpacity = ScratchpadSupport.sanitizedBackgroundOpacity($0) }
        )
    }

    private var scratchpadTextSizeBinding: Binding<Double> {
        Binding(
            get: { ScratchpadSupport.sanitizedTextSize(scratchpadTextSize) },
            set: { scratchpadTextSize = ScratchpadSupport.sanitizedTextSize($0) }
        )
    }
}
