// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// One destination-aware Settings search result. Its identity is structural,
/// never derived from localized text or result ordering.
struct SettingsSearchItem: Identifiable {
    enum ID: Hashable {
        case page(SettingsPage)
        case feature(AppFeature)
        case setting(SettingsSectionAnchor)
    }

    let id: ID
    let destination: FeatureSettingsDestination
    let title: String
    let icon: String
    var keywords: [String] = []
    /// Optional feature owner for each keyword. This is parallel to
    /// `keywords`; absent entries are page-level settings.
    var keywordFeatures: [AppFeature?] = []
    /// The hub feature this result represents, when it corresponds to exactly
    /// one `AppFeature` — including a dedicated page result such as Homebrew,
    /// whose `id` stays `.page(...)` for identity stability. `nil` for a
    /// purely generic page (Features itself, General, ...).
    var feature: AppFeature?
}

/// One selectable row inside a grouped Settings search result. A page-level
/// keyword routes to its containing page, while a feature-owned keyword keeps
/// the same exact section destination and unavailable-feature fallback as the
/// feature row itself.
struct SettingsSearchSuggestion: Identifiable {
    enum ID: Hashable {
        case page(SettingsPage)
        case item(SettingsPage, SettingsSearchItem.ID)
        case keyword(SettingsPage, Int)
    }

    let id: ID
    let title: String
    let icon: String
    let item: SettingsSearchItem
    /// Features-page keyword rows use this to reveal the exact utility rather
    /// than opening the hub at an unrelated scroll position.
    var featureHubTarget: AppFeature? = nil
}

/// macOS Settings-style search group: the main page is shown once, followed
/// by every matching utility or setting that lives inside it.
struct SettingsSearchGroup: Identifiable {
    let pageItem: SettingsSearchItem
    let parentMatches: Bool
    let suggestions: [SettingsSearchSuggestion]

    var id: SettingsPage { pageItem.destination.page }

    var parentSuggestion: SettingsSearchSuggestion {
        SettingsSearchSuggestion(id: .page(id), title: pageItem.title,
                                 icon: pageItem.icon, item: pageItem)
    }
}
