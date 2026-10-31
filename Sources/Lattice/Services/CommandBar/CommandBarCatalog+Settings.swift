import Foundation

extension CommandBarCatalog {
    // MARK: - Settings pages

    /// Pages an action row already opens; listing them again would put two
    /// rows in the list that lead to the same place.
    private static let pagesCoveredByActions: Set<SettingsPage> = [
        .general, .cleaner, .uninstaller, .appUpdates,
    ]

    static func settingsEntries(_ s: Strings,
                                        language: AppLanguage,
                                        bar: CommandBarFeatureStrings) -> [CommandBarEntry] {
        SettingsDirectory.searchItems(s, language: language).compactMap { item in
            let id: String
            switch item.id {
            case .page(let page):
                guard !(pagesCoveredByActions.contains(page)
                        && (page == .general || FeatureVisibilitySupport.features(for: page).contains(where: \.isAvailable))),
                      FeatureVisibilitySupport.isPageVisible(page, isAvailable: { $0.isAvailable })
                else { return nil }
                id = "settings.\(page)"
            case .feature(let feature):
                guard feature.isVisibleInSettings(isAvailable: { $0.isAvailable }),
                      FeatureVisibilitySupport.isPageVisible(
                        item.destination.page, isAvailable: { $0.isAvailable })
                else { return nil }
                id = "settings.feature.\(feature.rawValue)"
            case .setting(let anchor):
                guard item.feature.map({ $0.isVisibleInSettings(isAvailable: { $0.isAvailable }) }) ?? true,
                      FeatureVisibilitySupport.isPageVisible(
                        item.destination.page, isAvailable: { $0.isAvailable })
                else { return nil }
                id = "settings.setting.\(anchor.rawValue)"
            }
            return CommandBarEntry(
                id: id,
                title: item.title,
                subtitle: s.settingsTitle,
                keywords: item.keywords.joined(separator: " "),
                icon: .symbol(item.icon),
                run: { _ in
                    let routed = SettingsSearchSupport.route(for: item)
                    openSettings(at: routed.destination, targetFeature: routed.targetFeature,
                                 sidebarFeature: item.feature)
                })
        }
    }

}
