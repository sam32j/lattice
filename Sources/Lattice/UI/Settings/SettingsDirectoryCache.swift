import SwiftUI

/// Directory construction is much more expensive than selecting an existing
/// row. Rebuild only when its language, icon source or availability changes.
final class SettingsDirectoryCache {
    private struct Key: Equatable {
        let language: AppLanguage
        let superKeySource: SuperKeySource
        let featureRevision: Int
    }

    private var navigationKey: Key?
    private(set) var sections: [SettingsSidebarSection] = []
    private(set) var items: [SettingsSidebarItem] = []
    private var searchKey: Key?
    private var searchItems: [SettingsSearchItem] = []

    func navigation(strings: Strings, language: AppLanguage,
                    superKeySource: SuperKeySource, featureRevision: Int,
                    isAvailable: (AppFeature) -> Bool) -> [SettingsSidebarSection] {
        let key = Key(language: language, superKeySource: superKeySource,
                      featureRevision: featureRevision)
        if navigationKey != key {
            sections = SettingsDirectory.sidebarSections(
                strings, language: language, superKeySource: superKeySource,
                isAvailable: isAvailable)
            items = sections.flatMap(\.items)
            navigationKey = key
        }
        return sections
    }

    func search(strings: Strings, language: AppLanguage,
                superKeySource: SuperKeySource, featureRevision: Int) -> [SettingsSearchItem] {
        let key = Key(language: language, superKeySource: superKeySource,
                      featureRevision: featureRevision)
        if searchKey != key {
            searchItems = SettingsDirectory.searchItems(
                strings, language: language, superKeySource: superKeySource)
            searchKey = key
        }
        return searchItems
    }
}
