// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Settings window with named tools in the sidebar. The detail keeps each
/// tool's existing settings and section anchor.
struct SettingsView: View {
    @ObservedObject var l10n = L10n.shared
    @ObservedObject var router = SettingsRouter.shared
    @ObservedObject var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.superKeySource) var superKeySourceRaw =
        SuperKeySource.capsLock.rawValue
    @State var searchQuery = ""
    @State var activeSearchIndex: Int?
    @State var directoryCache = SettingsDirectoryCache()
    @State var navigationFromSidebar = false
    @State var detailIsScrolled = false
    /// The row just picked in the sidebar, until the router has taken it.
    @State var sidebarPick: SettingsSidebarItem.ID?
    @FocusState var sidebarSearchFocused: Bool

    struct SearchResultsSnapshot: Equatable {
        let query: String
        let groups: [SettingsSearchGroup]

        var isBlank: Bool {
            query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var items: [SettingsSearchSuggestion] {
            groups.flatMap { group in
                (group.parentMatches ? [group.parentSuggestion] : []) + group.suggestions
            }
        }

        var ids: [SettingsSearchSuggestion.ID] { items.map(\.id) }

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.query == rhs.query && lhs.ids == rhs.ids
        }
    }

    var sidebarSections: [SettingsSidebarSection] {
        directoryCache.navigation(
            strings: l10n.s, language: l10n.language,
            superKeySource: SuperKeySource.sanitized(superKeySourceRaw),
            featureRevision: features.revision,
            isAvailable: { features.isAvailable($0) })
    }

    var sidebarItems: [SettingsSidebarItem] {
        _ = sidebarSections
        return directoryCache.items
    }

    var sidebarSelection: Binding<SettingsSidebarItem.ID?> {
        Binding(
            get: {
                sidebarPick ?? SettingsSidebarSupport.selection(
                    for: router.destination, in: sidebarItems,
                    preferredID: router.sidebarFeature.map { .feature($0) })
            },
            // The list sets its selection during a view update, where the
            // router must not publish, so the pick is routed once it ends.
            set: { selectedID in
                guard let selectedID,
                      sidebarItems.contains(where: { $0.id == selectedID }) else { return }
                sidebarPick = selectedID
            }
        )
    }

    func routeSidebarPick(_ selectedID: SettingsSidebarItem.ID?) {
        guard let selectedID else { return }
        sidebarPick = nil
        guard let item = sidebarItems.first(where: { $0.id == selectedID }) else { return }
        let feature: AppFeature?
        if case .feature(let selectedFeature) = selectedID {
            feature = selectedFeature
        } else {
            feature = nil
        }
        navigationFromSidebar = true
        router.request(item.destination, sidebarFeature: feature)
    }

    var body: some View {
        let searchResults: SearchResultsSnapshot = {
            guard hasSearchQuery else { return SearchResultsSnapshot(query: searchQuery, groups: []) }
            return SearchResultsSnapshot(
                query: searchQuery,
                groups: SettingsSearchSupport.groupedMatchingItems(
                    query: searchQuery,
                    items: directoryCache.search(
                        strings: l10n.s, language: l10n.language,
                        superKeySource: SuperKeySource.sanitized(superKeySourceRaw),
                        featureRevision: features.revision),
                    isAvailable: { features.isAvailable($0) }))
        }()

        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar(searchResults: searchResults)
                .navigationSplitViewColumnWidth(min: SettingsSidebarConfiguration.width, ideal: SettingsSidebarConfiguration.width, max: SettingsSidebarConfiguration.width)
                .background { Color(nsColor: SettingsSidebarConfiguration.backgroundColor).ignoresSafeArea(.container, edges: .top) }
        } detail: {
            // List-heavy pages must receive a viewport, not an unconstrained
            // ideal height that can push their header outside the window.
            SettingsDetailViewport {
                scrollEdgeDetail
                    .settingsSectionFocus(for: router.page)
            }
            .toolbar { settingsNavigationToolbar }
            .toolbarBackground(detailIsScrolled ? .visible : .hidden, for: .windowToolbar)
            .background(SettingsToolbarBackdrop(isScrolled: detailIsScrolled))
            .background { Color(nsColor: .textBackgroundColor).ignoresSafeArea(.container, edges: .top) }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .toolbar(removing: defaultTitleItem)
        .frame(minWidth: 772, maxWidth: 772, minHeight: 528, maxHeight: .infinity)
        .onAppear {
            ensureVisiblePage()
        }
        .onChange(of: features.revision) { _, _ in ensureVisiblePage() }
        .onChange(of: searchResults, initial: true) { previous, current in
            updateSearchSelection(previous: previous, current: current)
        }
        .onChange(of: router.requestID) { _, _ in
            ensureVisiblePage()
        }
        .onChange(of: router.page) { _, _ in
            if #available(macOS 15, *) { detailIsScrolled = false }
        }
    }

    @ToolbarContentBuilder
    var settingsNavigationToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            let strings = SettingsNavigationStrings.localized(l10n.language)
            Button {
                router.goBack(isPageVisible: isPageVisible)
            } label: {
                Label(strings.back, systemImage: "chevron.backward")
            }
            .disabled(!router.canGoBack(isPageVisible: isPageVisible))
            .help(strings.back)

            Button {
                router.goForward(isPageVisible: isPageVisible)
            } label: {
                Label(strings.forward, systemImage: "chevron.forward")
            }
            .disabled(!router.canGoForward(isPageVisible: isPageVisible))
            .help(strings.forward)
        }
        // Recreate only the native title item when its text changes. Reusing
        // the previous item can retain an obsolete width until a scroll redraw.
#if compiler(>=6.2)
        if #available(macOS 26, *) {
            ToolbarItem(id: "settings-title-\(detailTitle)", placement: .navigation) {
                toolbarTitle
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarSpacer(.flexible, placement: .primaryAction)
        } else {
            ToolbarItem(id: "settings-title-\(detailTitle)", placement: .navigation) {
                toolbarTitle
            }
        }
#else
        ToolbarItem(id: "settings-title-\(detailTitle)", placement: .navigation) {
            toolbarTitle
        }
#endif
    }

    var defaultTitleItem: ToolbarDefaultItemKind? {
        if #available(macOS 15, *) { return .title }
        return nil
    }

    var toolbarTitle: some View {
        Text(detailTitle)
            .font(.system(size: 17, weight: .semibold))
            .padding(.leading, 10)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("settings-page-title")
    }

    @ViewBuilder
    var scrollEdgeDetail: some View {
#if compiler(>=6.2)
        if #available(macOS 26, *) {
            observedScrollDetail.scrollEdgeEffectStyle(.hard, for: .top)
        } else {
            observedScrollDetail
        }
#else
        observedScrollDetail
#endif
    }

    @ViewBuilder
    var observedScrollDetail: some View {
        if #available(macOS 15, *) {
            detail.onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > 0.5
            } action: { _, isScrolled in
                detailIsScrolled = isScrolled
            }
        } else {
            detail.onAppear { detailIsScrolled = true }
        }
    }

    func handleSearchKey(_ keyCode: UInt16,
                                  searchResults: [SettingsSearchSuggestion]) -> Bool {
        switch keyCode {
        case 126: // Up
            guard !searchResults.isEmpty else { return false }
            activeSearchIndex = SettingsSearchSupport.moveSelection(
                index: activeSearchIndex, delta: -1, count: searchResults.count)
            return true
        case 125: // Down
            guard !searchResults.isEmpty else { return false }
            activeSearchIndex = SettingsSearchSupport.moveSelection(
                index: activeSearchIndex, delta: 1, count: searchResults.count)
            return true
        case 36, 76: // Return / Keypad Enter
            guard let index = activeSearchIndex,
                  searchResults.indices.contains(index) else { return false }
            requestSearchItem(searchResults[index])
            return true
        default:
            return false
        }
    }

    func updateSearchSelection(previous: SearchResultsSnapshot,
                                       current: SearchResultsSnapshot) {
        guard !current.isBlank, !current.items.isEmpty else {
            activeSearchIndex = nil
            return
        }
        if previous.query != current.query {
            activeSearchIndex = 0
        } else if previous.ids != current.ids {
            activeSearchIndex = SettingsSearchSupport.reconciledSelection(
                index: activeSearchIndex,
                previousIDs: previous.ids,
                resultIDs: current.ids)
        }
    }

    func requestSearchItem(_ suggestion: SettingsSearchSuggestion) {
        let routed = SettingsSearchSupport.route(for: suggestion)
        router.request(routed.destination, targetFeature: routed.targetFeature,
                       sidebarFeature: suggestion.item.feature)
    }

    /// Legacy destinations fall back to General. Disabling a feature keeps
    /// its owning destination and navigation history reachable.
    func ensureVisiblePage() {
        if !isPageVisible(router.page) {
            router.page = .general
            return
        }
        if let fallback = SettingsSidebarSupport.fallbackDestination(
            for: router.destination, in: sidebarItems) {
            router.request(fallback, replacingVisit: true)
        }
    }

    func isPageVisible(_ page: SettingsPage) -> Bool {
        FeatureVisibilitySupport.isPageVisible(page, isAvailable: { $0.isAvailable })
    }


}
