import SwiftUI

extension SettingsView {
    func sidebar(searchResults: SearchResultsSnapshot) -> some View {
        sidebarList(searchResults: searchResults)
            .safeAreaInset(edge: .top, spacing: 0) {
                SidebarSearchField(query: $searchQuery, isFocused: $sidebarSearchFocused)
            }
    }

    var hasSearchQuery: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    func sidebarList(searchResults: SearchResultsSnapshot) -> some View {
        ScrollViewReader { proxy in
            List(selection: sidebarSelection) {
                if hasSearchQuery {
                    searchResultRows(searchResults)
                } else {
                    normalSidebarRows
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .onChange(of: sidebarPick) { _, selectedID in routeSidebarPick(selectedID) }
            .onChange(of: activeSearchIndex) { _, index in
                guard let index, searchResults.items.indices.contains(index) else { return }
                let id = searchResults.items[index].id
                if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    proxy.scrollTo(id)
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id) }
                }
            }
            .onChange(of: hasSearchQuery) { _, searching in
                // The list stays in place across a search so the field keeps
                // focus, which also keeps the results' scroll offset. Centering
                // the chosen tool brings it back into view; near the top, the
                // pages clamp to where a fresh list starts, and a top anchor
                // would leave the list's inset hidden.
                guard !searching else { return }
                DispatchQueue.main.async { scrollSidebarToSelection(proxy) }
            }
            .onChange(of: router.requestID) { _, _ in
                // A click in the sidebar is already visible. Only external
                // routes need to reveal and scroll to their destination.
                let fromSidebar = navigationFromSidebar
                navigationFromSidebar = false
                guard !fromSidebar else { return }
                DispatchQueue.main.async { scrollSidebarToSelection(proxy) }
            }
            .background {
                SearchKeyMonitor(customSearchFocused: sidebarSearchFocused, focusSearch: { sidebarSearchFocused = true }) { keyCode in
                    handleSearchKey(keyCode, searchResults: searchResults.items)
                }
            }
        }
    }

    var selectedSidebarItem: SettingsSidebarItem.ID? {
        let items = sidebarItems
        return SettingsSidebarSupport.selection(for: router.destination, in: items,
                                                preferredID: router.sidebarFeature.map { .feature($0) })
            ?? items.first?.id
    }

    func scrollSidebarToSelection(_ proxy: ScrollViewProxy) {
        guard !hasSearchQuery, let selected = selectedSidebarItem else { return }
        proxy.scrollTo(selected, anchor: .center)
    }

    var detailTitle: String {
        switch router.page {
        case .notchWidget(let module):
            return NotchSettingsStrings.widgetTitle(module, language: l10n.language)
        case .notchCompanion, .notchMascot:
            return FeatureStrings.notchMascot(l10n.language).title
        default:
            return sidebarItems.first { $0.id == selectedSidebarItem }?.title ?? l10n.s.settingsTitle
        }
    }

    @ViewBuilder
    var normalSidebarRows: some View {
        let selectedID = selectedSidebarItem
        ForEach(sidebarSections) { section in
            Section {
                ForEach(section.items) { item in
                    HStack(spacing: 9) {
                        Image(systemName: item.icon)
                            .foregroundStyle(selectedID == item.id
                                ? AnyShapeStyle(.primary) : AnyShapeStyle(.tint))
                            .frame(width: 18)
                        Text(item.title)
                    }
                    .tag(item.id)
                    .id(item.id)
                    .help(item.title)
                }
            } header: {
                Text(section.title)
            }
        }
    }

    @ViewBuilder
    func searchResultRows(_ searchResults: SearchResultsSnapshot) -> some View {
        ForEach(searchResults.groups, id: \.parentSuggestion.id) { group in
            searchPageRow(group, searchResults: searchResults)
            ForEach(group.suggestions) { suggestion in
                searchSuggestionRow(suggestion, searchResults: searchResults)
            }
        }
    }

    func searchPageRow(_ group: SettingsSearchGroup,
                               searchResults: SearchResultsSnapshot) -> some View {
        let suggestion = group.parentSuggestion
        let selectionIndex = searchResults.items.firstIndex { $0.id == suggestion.id }
        let isSelected = selectionIndex == activeSearchIndex
        return Button {
            if let selectionIndex { activeSearchIndex = selectionIndex }
            requestSearchItem(suggestion)
        } label: {
            Label(group.pageItem.title, systemImage: group.pageItem.icon)
                .fontWeight(.semibold)
                .searchResultRowStyle(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .id(suggestion.id)
    }

    func searchSuggestionRow(_ suggestion: SettingsSearchSuggestion,
                                     searchResults: SearchResultsSnapshot) -> some View {
        let selectionIndex = searchResults.items.firstIndex { $0.id == suggestion.id }
        let isSelected = selectionIndex == activeSearchIndex
        return Button {
            if let selectionIndex { activeSearchIndex = selectionIndex }
            requestSearchItem(suggestion)
        } label: {
            Label(suggestion.title, systemImage: suggestion.icon)
                .searchResultRowStyle(isSelected: isSelected)
                .padding(.leading, 18)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .id(suggestion.id)
    }

}

extension View {
    func searchResultRowStyle(isSelected: Bool) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : .clear)
            }
    }
}
