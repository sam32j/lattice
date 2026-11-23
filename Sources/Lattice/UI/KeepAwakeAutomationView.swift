// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The conditions that start a Stay Awake session by themselves, one tile
/// each. A chosen tile says whether its condition holds right now. The card
/// around them owns the Any/All choice and the apps list.
struct KeepAwakeConditionTiles: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @AppStorage(DefaultsKey.keepAwakeExternalDisplay) private var externalDisplay = false
    @AppStorage(DefaultsKey.keepAwakeConnectedToPower) private var connectedToPower = false
    @AppStorage(DefaultsKey.keepAwakeRunningApps) private var runningApps = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            conditionTile(.externalDisplay, title: strings.externalDisplayToggle, icon: "display",
                          selected: externalDisplay) { externalDisplay.toggle() }
            conditionTile(.power, title: strings.powerToggle, icon: "powerplug.fill",
                          selected: connectedToPower) { connectedToPower.toggle() }
            conditionTile(.runningApps, title: strings.runningAppsToggle, icon: "app.fill",
                          selected: runningApps) { runningApps.toggle() }
        }
    }

    private var strings: KeepAwakeAutomationStrings {
        FeatureStrings.keepAwakeAutomation(l10n.language)
    }

    private var settings: StayAwakeSettingsStrings {
        FeatureStrings.stayAwakeSettings(l10n.language)
    }

    private func conditionTile(_ condition: KeepAwakeAutomationCondition, title: String, icon: String,
                               selected: Bool, toggle: @escaping () -> Void) -> some View {
        let holds = awake.liveAutomationConditions.contains(condition)
        return Button {
            withAnimation(reduceMotion ? nil : .settingsExpansion, toggle)
            awake.automationPreferencesDidChange()
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    Spacer(minLength: 4)
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                // Only a chosen condition is watched, so only it can say.
                Text(holds ? settings.conditionNow : settings.conditionNotNow)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(holds ? AnyShapeStyle(Color.green) : AnyShapeStyle(.tertiary))
                    .opacity(selected ? 1 : 0)
            }
            .padding(9)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.11) : Color.primary.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor.opacity(0.32) : Color.primary.opacity(0.08))
            )
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? (holds ? settings.conditionNow : settings.conditionNotNow) : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
