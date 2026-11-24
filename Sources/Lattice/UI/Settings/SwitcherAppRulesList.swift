// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// "Hide in switcher": apps that never appear in the switcher, in the same
/// app-list sheet as the other exclusion lists. Whether an app with no windows
/// is listed is the global "Hide apps without windows" choice; this list only
/// removes apps outright. It keeps the per-app rule storage, so apps saved as
/// "Never show" by earlier builds carry over.
struct SwitcherAppRulesList: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var hiddenApps: [String] = Self.savedHiddenApps

    private var text: SwitcherAppRulesStrings {
        FeatureStrings.switcherAppRules(l10n.language)
    }

    var body: some View {
        AppBundleList(title: text.listTitle,
                      caption: text.caption,
                      action: .exclude,
                      removeLabel: text.removeButton,
                      bundleIDs: hiddenApps,
                      reachesEveryApp: true,
                      acceptsExecutables: false,
                      usesSheet: true,
                      sheetTitle: text.listTitle,
                      onAdd: { save(hiddenApps + [$0]) },
                      onRemove: { bundleID in save(hiddenApps.filter { $0 != bundleID }) })
    }

    private static var savedHiddenApps: [String] {
        SwitcherAppRule.rules(storedValue: UserDefaults.standard.dictionary(forKey: DefaultsKey.switcherAppRules))
            .filter { $0.value == .hidden }
            .keys
            .sorted()
    }

    private func save(_ bundleIDs: [String]) {
        let unique = Array(Set(bundleIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })).sorted()
        let rules = Dictionary(uniqueKeysWithValues: unique.map { ($0, SwitcherAppRule.hidden) })
        UserDefaults.standard.set(SwitcherAppRule.storedValue(rules), forKey: DefaultsKey.switcherAppRules)
        hiddenApps = unique
    }
}
