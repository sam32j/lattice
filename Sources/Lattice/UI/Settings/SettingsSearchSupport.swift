import Foundation

/// Pure filtering for the Settings sidebar search field, so the matching
/// rules (case, accents, word prefixes) are covered by the unit harness.
enum SettingsSearchSupport {
    enum MatchRank {
        case exactTitle
        case title
        case keyword
    }

    /// Every feature contributes a localized label and exact Settings
    /// destination. Clipboard History uses its section name so it stays
    /// distinguishable from the containing Clipboard page.
    static func featureItems(language: AppLanguage,
                             title: (AppFeature) -> String) -> [SettingsSearchItem] {
        AppFeature.allCases.filter { $0.isHardwareSupported && $0 != .screenOCR && $0 != .colorPicker }.map { feature in
            SettingsSearchItem(id: .feature(feature),
                               destination: feature.settingsDestination,
                               title: feature == .clipboardHistory
                                   ? FeatureStrings.commandBar(language).sourceClipboard
                                   : title(feature),
                               icon: feature.symbolName,
                               feature: feature)
        }
    }

    static func keyboardBrightnessShortcutItem(language: AppLanguage) -> SettingsSearchItem {
        let brightness = FeatureStrings.brightness(language)
        return SettingsSearchItem(
            id: .setting(.keyboardBrightnessShortcuts),
            destination: FeatureSettingsDestination(
                .keyboard, sectionAnchor: .keyboardBrightnessShortcuts),
            title: brightness.keyboardLight,
            icon: "keyboard",
            keywords: [brightness.keyboardBrightnessShortcuts, brightness.keyboardBrightnessDecrease,
                       brightness.keyboardBrightnessIncrease],
            feature: .brightness)
    }

    /// A dedicated page row wins over a generated feature row only when their
    /// IDs, full destinations, and the page's one-to-one feature mapping all
    /// agree. The winning page keeps its stable identity and presentation while
    /// carrying the feature identity needed for unavailable-feature routing.
    static func combinedItems(pageItems: [SettingsSearchItem],
                               featureItems: [SettingsSearchItem]) -> [SettingsSearchItem] {
        let mergedPageItems = pageItems.map { pageItem -> SettingsSearchItem in
            guard let match = featureItems.first(where: {
                shouldMerge(pageItem: pageItem, featureItem: $0)
            }) else { return pageItem }
            var merged = pageItem
            merged.feature = match.feature
            return merged
        }
        let dedupedFeatureItems = featureItems.filter { featureItem in
            !pageItems.contains { pageItem in
                shouldMerge(pageItem: pageItem, featureItem: featureItem)
            }
        }
        return mergedPageItems + dedupedFeatureItems
    }

    static func shouldMerge(pageItem: SettingsSearchItem,
                                    featureItem: SettingsSearchItem) -> Bool {
        guard case .page(let page) = pageItem.id,
              page == pageItem.destination.page,
              case .feature(let feature) = featureItem.id,
              featureItem.feature == feature,
              pageItem.destination == featureItem.destination else { return false }
        // A feature landing on its own section of the page (the green button
        // override on Window Layout) keeps the page alive without owning it.
        return FeatureVisibilitySupport.features(for: page)
            .filter { $0.settingsDestination == FeatureSettingsDestination(page) } == [feature]
    }

    /// Opens each feature's activation owner. Old Features identities resolve
    /// to the named owner, or General when no feature was supplied.
    static func route(for item: SettingsSearchItem,
                       isAvailable: (AppFeature) -> Bool = { $0.isAvailable })
        -> (destination: FeatureSettingsDestination, targetFeature: AppFeature?) {
        if item.destination.page == .features {
            return (item.feature?.settingsDestination ?? FeatureSettingsDestination(.general), nil)
        }
        return (item.destination, nil)
    }

    /// Dedicated pages own their install controls even while the feature is off.
    static func hasSettingsControl(_ feature: AppFeature,
                                           isAvailable: (AppFeature) -> Bool) -> Bool {
        feature.isHardwareSupported && (feature.isManagedOnDedicatedPage
            || feature.isVisibleInSettings(isAvailable: isAvailable))
    }

    /// A page row carrying its page's own feature, like Window Layout, still
    /// leads to that page while another feature there keeps it in the
    /// sidebar, like the green button override with Window Layout removed.
    static func leadsToVisiblePage(_ item: SettingsSearchItem,
                                           isAvailable: (AppFeature) -> Bool) -> Bool {
        guard case .page(let page) = item.id, item.destination.page == page else { return false }
        return FeatureVisibilitySupport.isPageVisible(page, isAvailable: isAvailable)
    }

    static func route(for suggestion: SettingsSearchSuggestion,
                      isAvailable: (AppFeature) -> Bool = { $0.isAvailable })
        -> (destination: FeatureSettingsDestination, targetFeature: AppFeature?) {
        if let feature = suggestion.featureHubTarget {
            return (feature.settingsDestination, nil)
        }
        return route(for: suggestion.item, isAvailable: isAvailable)
    }

    /// Case-, diacritic- and width-insensitive containment: "métr" finds
    /// "Metrics", "moni" finds "Monitor". A blank query matches everything.
    /// Keywords let a page match by what lives inside it ("lid" finds
    /// Energy, "Launcher Grid" finds Quick tools), not just by its name.
    static func matches(query: String, title: String, keywords: [String] = []) -> Bool {
        let foldedQuery = fold(query)
        guard !foldedQuery.isEmpty else { return true }
        return matchRank(foldedQuery: foldedQuery, title: title, keywords: keywords) != nil
    }

    /// Filters and ranks one query in a single stable pass: exact normalized
    /// titles, then title containment, then keyword-only matches.
    static func matchingItems(query: String,
                               items: [SettingsSearchItem]) -> [SettingsSearchItem] {
        let foldedQuery = fold(query)
        guard !foldedQuery.isEmpty else { return items }

        var exactTitleMatches: [SettingsSearchItem] = []
        var titleMatches: [SettingsSearchItem] = []
        var keywordMatches: [SettingsSearchItem] = []
        for item in items {
            switch matchRank(foldedQuery: foldedQuery,
                             title: item.title,
                             keywords: item.keywords) {
            case .exactTitle: exactTitleMatches.append(item)
            case .title: titleMatches.append(item)
            case .keyword: keywordMatches.append(item)
            case nil: break
            }
        }
        return exactTitleMatches + titleMatches + keywordMatches
    }

    /// Groups ranked matches beneath their main Settings pages. Page keywords
    /// become visible setting rows instead of silently producing only a page
    /// result, and generated feature rows retain their anchored destinations.
    static func groupedMatchingItems(query: String,
                                     items: [SettingsSearchItem],
                                     isAvailable: (AppFeature) -> Bool = { $0.isAvailable })
        -> [SettingsSearchGroup] {
        let foldedQuery = fold(query)
        guard !foldedQuery.isEmpty else { return [] }

        let navigableItems = items.compactMap { item -> SettingsSearchItem? in
            if let feature = item.feature, !hasSettingsControl(feature, isAvailable: isAvailable),
               !leadsToVisiblePage(item, isAvailable: isAvailable) {
                // The utility itself remains navigable through its Features
                // row, but settings that do not exist until installation must
                // not make that utility appear as a field-level match. A page
                // that stays visible keeps the keywords of the features that
                // are on; the loop below drops the others.
                var fallbackItem = item
                fallbackItem.keywords = []
                fallbackItem.keywordFeatures = []
                return fallbackItem
            }
            guard FeatureVisibilitySupport.isPageVisible(
                item.destination.page, isAvailable: isAvailable) else { return nil }
            return item
        }

        let pagePairs: [(SettingsPage, SettingsSearchItem)] = navigableItems.compactMap { item in
            guard case .page(let page) = item.id,
                  item.destination.page == page,
                  FeatureVisibilitySupport.isPageVisible(page, isAvailable: isAvailable)
            else { return nil }
            return (page, item)
        }
        let pageItems = Dictionary(uniqueKeysWithValues: pagePairs)
        var builders: [SettingsPage: SearchGroupBuilder] = [:]
        var pageOrder: [SettingsPage] = []

        for item in matchingItems(query: query, items: navigableItems) {
            let page = route(for: item, isAvailable: isAvailable).destination.page
            guard let pageItem = pageItems[page] else { continue }
            if builders[page] == nil {
                builders[page] = SearchGroupBuilder(pageItem: pageItem)
                pageOrder.append(page)
            }
            guard var builder = builders[page] else { continue }

            if case .page(let itemPage) = item.id, itemPage == page {
                if matchRank(foldedQuery: foldedQuery, title: item.title, keywords: []) != nil {
                    builder.parentMatches = true
                }
                for (index, keyword) in item.keywords.enumerated()
                    where fold(keyword).contains(foldedQuery) {
                    let keywordFeature = item.keywordFeatures.indices.contains(index)
                        ? item.keywordFeatures[index] : nil
                    if let keywordFeature, !hasSettingsControl(keywordFeature, isAvailable: isAvailable) { continue }
                    let suggestionItem = keywordFeature.map { feature in
                        SettingsSearchItem(id: .feature(feature),
                                           destination: feature == .audioPriority && page == .audioOutput
                                                ? FeatureSettingsDestination(.audioOutput, sectionAnchor: .audioOutputPriority)
                                                : feature.settingsDestination,
                                           title: keyword,
                                           icon: feature.symbolName,
                                           feature: feature)
                    } ?? pageItem
                    appendSuggestion(
                        SettingsSearchSuggestion(id: .keyword(page, index),
                                                 title: keyword,
                                                 icon: pageItem.icon,
                                                 item: suggestionItem,
                                                 featureHubTarget: page == .features
                                                    ? keywordFeature : nil),
                        to: &builder)
                }
            } else {
                appendSuggestion(
                    SettingsSearchSuggestion(id: .item(page, item.id),
                                             title: item.title,
                                             icon: item.icon,
                                             item: item),
                    to: &builder)
            }
            builders[page] = builder
        }

        return pageOrder.compactMap { page in
            guard let builder = builders[page],
                  builder.parentMatches || !builder.suggestions.isEmpty else { return nil }
            return SettingsSearchGroup(pageItem: builder.pageItem,
                                       parentMatches: builder.parentMatches,
                                       suggestions: builder.suggestions)
        }
    }

    struct SearchGroupBuilder {
        let pageItem: SettingsSearchItem
        var parentMatches = false
        var suggestions: [SettingsSearchSuggestion] = []
    }

    static func appendSuggestion(_ suggestion: SettingsSearchSuggestion,
                                         to builder: inout SearchGroupBuilder) {
        guard !builder.suggestions.contains(where: {
            fold($0.title) == fold(suggestion.title)
        }) else { return }
        builder.suggestions.append(suggestion)
    }

    /// Every former screen-tool page remains discoverable after those settings
    /// move behind the single Screen capture destination.
}
