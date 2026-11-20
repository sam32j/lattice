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
    /// Parallel to `keywords`: the Boolean preference that must be on for
    /// the row to be on screen. `nil` rows are shown whenever the page is.
    var keywordRequirements: [String?] = []
    /// Parallel to `keywords`: a section that overrides the keyword
    /// feature's usual destination. `nil` keeps the feature's destination.
    var keywordAnchors: [SettingsSectionAnchor?] = []
    /// The hub feature this result represents, when it corresponds to exactly
    /// one `AppFeature` — including a dedicated page result such as Homebrew,
    /// whose `id` stays `.page(...)` for identity stability. `nil` for a
    /// purely generic page (Features itself, General, ...).
    var feature: AppFeature?
    /// Search aliases that match the containing page, but do not produce separate child suggestion rows.
    var aliases: [String] = []

    /// Whether the keyword at `index` names a row currently on screen.
    func keywordIsShown(at index: Int, isSettingOn: (String) -> Bool) -> Bool {
        guard keywordRequirements.indices.contains(index),
              let requirement = keywordRequirements[index] else { return true }
        return isSettingOn(requirement)
    }

    func shownKeywords(isSettingOn: (String) -> Bool) -> [String] {
        keywords.indices.filter { keywordIsShown(at: $0, isSettingOn: isSettingOn) }.map { keywords[$0] }
    }
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

    /// The page the group opens. A feature with its own sidebar row (see
    /// `SettingsSearchSupport.standaloneSearchGroupFeatures`) heads a group of
    /// its own on that same page, so views key rows by `pageItem.id`.
    var id: SettingsPage { pageItem.destination.page }

    var parentSuggestion: SettingsSearchSuggestion {
        let suggestionID: SettingsSearchSuggestion.ID
        if case .page(let page) = pageItem.id {
            suggestionID = .page(page)
        } else {
            suggestionID = .item(pageItem.destination.page, pageItem.id)
        }
        return SettingsSearchSuggestion(id: suggestionID, title: pageItem.title,
                                        icon: pageItem.icon, item: pageItem)
    }
}
