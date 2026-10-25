// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

struct AppMenuDestinationSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.notchEnabled) private var islandEnabled = false
    @AppStorage(DefaultsKey.notchHidesMenuBarIcon) private var hideMenuIcon = false
    @AppStorage(DefaultsKey.notchAppPanel) private var islandPanel = false
    @AppStorage(AppMenuDestination.disabledKey) private var disabled = false

    private var options: [AppMenuDestination] {
        _ = islandEnabled
        _ = hideMenuIcon
        return AppMenuDestination.available(in: .standard)
    }
    private var label: String { SettingsOwnershipStrings.text(.appMenu, l10n.language) }

    var body: some View {
        SettingsRow(symbol: "line.3.horizontal", title: label, caption: restorationHint) {
            HStack(spacing: 6) {
                if restorationHint != nil {
                    Button(AppMenuRestorationCopy.cancel(l10n.language)) {
                        disabled = true
                        islandPanel = false
                    }
                    .accessibilityIdentifier("app-menu.discard-remembered-target")
                }
                if options.count == 1 {
                    SettingsStatusDot(status: SettingsFeatureStatus(color: .red,
                        message: SettingsOwnershipStrings.text(.noMenuTarget, l10n.language)))
                }
                Picker(label, selection: Binding<AppMenuDestination>(
                    get: {
                        guard !disabled else { return .none }
                        let requested: AppMenuDestination = islandPanel ? .island : .menuBar
                        return options.contains(requested) ? requested : .none
                    },
                    set: {
                        disabled = $0 == .none
                        islandPanel = $0 == .island
                    })) {
                    ForEach(options, id: \.self) { target in
                        Text(title(target)).tag(target)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(options.count == 1)
            }
        }
    }

    private var restorationHint: String? {
        let preferred: AppMenuDestination = disabled ? .none : islandPanel ? .island : .menuBar
        guard preferred != .none, !options.contains(preferred) else { return nil }
        return AppMenuRestorationCopy.hint(preferred, language: l10n.language)
    }
    private func title(_ target: AppMenuDestination) -> String {
        switch target {
        case .none: return SettingsOwnershipStrings.text(.none, l10n.language)
        case .menuBar: return l10n.s.menuBarSection
        case .island: return FeatureStrings.notch(l10n.language).title
        }
    }
}
