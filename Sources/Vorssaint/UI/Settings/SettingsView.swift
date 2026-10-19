// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Directory construction is much more expensive than selecting an existing
/// row. Rebuild only when its language, icon source or availability changes.
private final class SettingsDirectoryCache {
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

/// Settings window with named tools in the sidebar. The detail keeps each
/// tool's existing settings and section anchor.
struct SettingsView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var router = SettingsRouter.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.superKeySource) private var superKeySourceRaw =
        SuperKeySource.capsLock.rawValue
    @State private var searchQuery = ""
    @State private var activeSearchIndex: Int?
    @State private var directoryCache = SettingsDirectoryCache()
    @State private var collapsedSectionIDs: Set<Int> = []
    @State private var navigationFromSidebar = false
    /// The row just picked in the sidebar, until the router has taken it.
    @State private var sidebarPick: SettingsSidebarItem.ID?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @FocusState private var sidebarSearchFocused: Bool

    private struct SearchResultsSnapshot: Equatable {
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

    private var sidebarSections: [SettingsSidebarSection] {
        directoryCache.navigation(
            strings: l10n.s, language: l10n.language,
            superKeySource: SuperKeySource.sanitized(superKeySourceRaw),
            featureRevision: features.revision,
            isAvailable: { features.isAvailable($0) })
    }

    private var sidebarItems: [SettingsSidebarItem] {
        _ = sidebarSections
        return directoryCache.items
    }

    private var sidebarSelection: Binding<SettingsSidebarItem.ID?> {
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

    private func routeSidebarPick(_ selectedID: SettingsSidebarItem.ID?) {
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

        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar(searchResults: searchResults)
                .navigationSplitViewColumnWidth(min: 198, ideal: 210, max: 240)
        } detail: {
            // NavigationSplitView's detail slot sometimes queries its content
            // for an unconstrained ideal size (settling the divider, or on a
            // page switch). `List` answers that with its full content height
            // rather than a viewport size the way `ScrollView` does, and
            // `.frame(maxHeight: .infinity)` only bounds a size it is given,
            // not one it is asked to report - so a few hundred rows (Kill
            // Process) grew the whole window. `GeometryReader` reports the
            // real space it was actually given for normal layout, and ~zero
            // when asked for an unconstrained ideal size, breaking the chain.
            GeometryReader { geometry in
                detail
                    .settingsSectionFocus(for: router.page)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar {
            // SwiftUI adds its sidebar button only to windows it creates, and
            // this one is AppKit's. Without it, a sidebar dragged shut could
            // only be dragged back from a one-point strip at the window's
            // edge, and a full-screen window could only peek at it.
            ToolbarItem(placement: .navigation) {
                let strings = SettingsNavigationStrings.localized(l10n.language)
                let title = sidebarShown ? strings.hideSidebar : strings.showSidebar
                Button(action: toggleSidebar) {
                    Label(title, systemImage: "sidebar.left")
                }
                .keyboardShortcut("s", modifiers: [.control, .command])
                .help(title)
            }
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
        }
        .frame(minWidth: 772, maxWidth: .infinity, minHeight: 528, maxHeight: .infinity)
        .onAppear {
            ensureVisiblePage()
            expandSelectedSection()
        }
        .onChange(of: features.revision) { _, _ in ensureVisiblePage() }
        .onChange(of: searchResults, initial: true) { previous, current in
            updateSearchSelection(previous: previous, current: current)
        }
        .onChange(of: router.requestID) { _, _ in
            ensureVisiblePage()
        }
    }

    /// macOS 27 backs the pinned sidebar search field with a hard top scroll
    /// edge, so rows fade out cleanly under it. On macOS 26 that effect does
    /// not render inside split-view sidebars and the pinned field has no
    /// backing of its own, so rows slid legibly across the placeholder
    /// (issues #183, #254); there the field lives on a fixed header above the
    /// list, where rows can never reach it. Earlier systems keep the classic
    /// opaque sidebar chrome.
    @ViewBuilder
    private func sidebar(searchResults: SearchResultsSnapshot) -> some View {
#if compiler(>=6.2)
        if #available(macOS 27, *) {
            sidebarList(searchResults: searchResults)
                .searchable(text: $searchQuery,
                            placement: .sidebar,
                            prompt: l10n.s.settingsSearchPlaceholder)
                .scrollEdgeEffectStyle(.hard, for: .top)
        } else if #available(macOS 26, *) {
            VStack(spacing: 0) {
                SidebarSearchField(query: $searchQuery, isFocused: $sidebarSearchFocused)
                sidebarList(searchResults: searchResults)
            }
        } else {
            sidebarList(searchResults: searchResults)
                .searchable(text: $searchQuery,
                            placement: .sidebar,
                            prompt: l10n.s.settingsSearchPlaceholder)
        }
#else
        sidebarList(searchResults: searchResults)
            .searchable(text: $searchQuery,
                        placement: .sidebar,
                        prompt: l10n.s.settingsSearchPlaceholder)
#endif
    }

    private var hasSearchQuery: Bool {
        !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// A sidebar dragged shut reports `.detailOnly` here as well.
    private var sidebarShown: Bool { columnVisibility != .detailOnly }

    private func toggleSidebar() {
        let next: NavigationSplitViewVisibility = sidebarShown ? .detailOnly : .all
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            columnVisibility = next
        } else {
            withAnimation { columnVisibility = next }
        }
    }

    @ViewBuilder
    private func sidebarList(searchResults: SearchResultsSnapshot) -> some View {
        ScrollViewReader { proxy in
            List(selection: sidebarSelection) {
                if hasSearchQuery {
                    searchResultRows(searchResults)
                } else {
                    normalSidebarRows
                }
            }
            .listStyle(.sidebar)
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
                expandSelectedSection()
                DispatchQueue.main.async { scrollSidebarToSelection(proxy) }
            }
            .onChange(of: router.requestID) { _, _ in
                // A click in the sidebar is already visible. Only external
                // routes need to reveal and scroll to their destination.
                let fromSidebar = navigationFromSidebar
                navigationFromSidebar = false
                guard !fromSidebar else { return }
                expandSelectedSection()
                DispatchQueue.main.async { scrollSidebarToSelection(proxy) }
            }
            .background {
                SearchKeyMonitor(customSearchFocused: sidebarSearchFocused) { keyCode in
                    handleSearchKey(keyCode, searchResults: searchResults.items)
                }
            }
        }
    }

    private var selectedSidebarItem: SettingsSidebarItem.ID? {
        let items = sidebarItems
        return SettingsSidebarSupport.selection(for: router.destination, in: items,
                                                preferredID: router.sidebarFeature.map { .feature($0) })
            ?? items.first?.id
    }

    private func scrollSidebarToSelection(_ proxy: ScrollViewProxy) {
        guard !hasSearchQuery, let selected = selectedSidebarItem else { return }
        proxy.scrollTo(selected, anchor: .center)
    }

    private func expandSelectedSection() {
        guard let selected = selectedSidebarItem,
              let section = sidebarSections.first(where: { section in
                  section.items.contains(where: { $0.id == selected })
              }) else { return }
        collapsedSectionIDs.remove(section.id)
    }

    @ViewBuilder
    private var normalSidebarRows: some View {
        let sections = sidebarSections
        let items = directoryCache.items
        let selectedID = SettingsSidebarSupport.selection(for: router.destination, in: items,
                                                          preferredID: router.sidebarFeature.map { .feature($0) })
        ForEach(sections) { section in
            Section {
                if !collapsedSectionIDs.contains(section.id) {
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
                }
            } header: {
                Button {
                    if !collapsedSectionIDs.insert(section.id).inserted {
                        collapsedSectionIDs.remove(section.id)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: collapsedSectionIDs.contains(section.id)
                            ? "chevron.right" : "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .frame(width: 12)
                        Text(section.title)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func searchResultRows(_ searchResults: SearchResultsSnapshot) -> some View {
        ForEach(searchResults.groups, id: \.parentSuggestion.id) { group in
            searchPageRow(group, searchResults: searchResults)
            ForEach(group.suggestions) { suggestion in
                searchSuggestionRow(suggestion, searchResults: searchResults)
            }
        }
    }

    private func searchPageRow(_ group: SettingsSearchGroup,
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

    private func searchSuggestionRow(_ suggestion: SettingsSearchSuggestion,
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

    private func handleSearchKey(_ keyCode: UInt16,
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

    private func updateSearchSelection(previous: SearchResultsSnapshot,
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

    private struct SearchKeyMonitor: NSViewRepresentable {
        var customSearchFocused: Bool
        var handleKey: (UInt16) -> Bool

        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            context.coordinator.install(for: view)
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            context.coordinator.customSearchFocused = customSearchFocused
            context.coordinator.handleKey = handleKey
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(customSearchFocused: customSearchFocused, handleKey: handleKey)
        }

        static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
            coordinator.removeMonitor()
        }

        final class Coordinator: NSObject {
            var customSearchFocused: Bool
            var handleKey: (UInt16) -> Bool
            private var monitor: Any?

            init(customSearchFocused: Bool, handleKey: @escaping (UInt16) -> Bool) {
                self.customSearchFocused = customSearchFocused
                self.handleKey = handleKey
            }

            func install(for view: NSView) {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
                    [weak self, weak view] event in
                    guard let self, let view, let window = view.window,
                          event.window === window,
                          Self.isNavigationKey(event),
                          let editor = window.firstResponder as? NSTextView,
                          editor.isFieldEditor,
                          (customSearchFocused || Self.isSidebarSearchEditor(editor, near: view)),
                          !editor.hasMarkedText() else { return event }
                    return handleKey(event.keyCode) ? nil : event
                }
            }

            func removeMonitor() {
                guard let monitor else { return }
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }

            private static func isNavigationKey(_ event: NSEvent) -> Bool {
                let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
                guard event.modifierFlags.intersection(blockedModifiers).isEmpty else { return false }
                return [UInt16(126), 125, 36, 76].contains(event.keyCode)
            }

            private static func isSidebarSearchEditor(_ editor: NSTextView,
                                                      near monitorView: NSView) -> Bool {
                guard let searchField = editor.delegate as? NSSearchField else { return false }
                let searchMidX = searchField.convert(searchField.bounds, to: nil).midX
                let sidebarFrame = monitorView.convert(monitorView.bounds, to: nil)
                return sidebarFrame.minX...sidebarFrame.maxX ~= searchMidX
            }
        }
    }

    private func requestSearchItem(_ suggestion: SettingsSearchSuggestion) {
        let routed = SettingsSearchSupport.route(for: suggestion)
        router.request(routed.destination, targetFeature: routed.targetFeature,
                       sidebarFeature: suggestion.item.feature)
    }

    /// The selected page can leave the sidebar when its last feature is
    /// switched off in the hub; fall back to the hub itself, where the
    /// feature can be brought back.
    private func ensureVisiblePage() {
        if !isPageVisible(router.page) {
            router.page = .features
            return
        }
        if let fallback = SettingsSidebarSupport.fallbackDestination(
            for: router.destination, in: sidebarItems) {
            router.request(fallback, replacingVisit: true)
        }
    }

    private func isPageVisible(_ page: SettingsPage) -> Bool {
        FeatureVisibilitySupport.isPageVisible(page, isAvailable: { $0.isAvailable })
    }

    @ViewBuilder
    private var detail: some View {
        switch router.page {
        case .general:
            if router.destination.sectionAnchor == .panelConfiguration,
               sidebarItems.contains(where: { $0.destination == router.destination }) {
                GeneralToolSettings()
            } else {
                GeneralSettings()
            }
        case .features: FeatureHubSettings()
        case .textSnippets: TextSnippetsSettings()
        case .notch: NotchSettings()
        case .notchMascot: NotchMascotSettings()
        case .radialMenu: RadialMenuSettings()
        case .commandBar: CommandBarSettings()
        case .energy: EnergySettings(focus: router.destination.sectionAnchor)
        case .monitor: MonitorSettings()
        case .mouse: MouseSettings()
        case .switcher: SwitcherSettings()
        case .dock: DockSettings()
        case .keyboard: KeyboardSettings()
        case .cutPaste: CutPasteSettings()
        case .autoQuit: AutoQuitSettings()
        case .uninstaller: UninstallerView()
        case .killProcess: KillProcessView()
        case .portManager: PortManagerView()
        case .urlCleaner: URLCleanerSettings()
        case .cleaner: CleanerSettings()
        case .homebrew: HomebrewSettings()
        case .appUpdates: AppUpdatesSettings()
        case .media: MediaSettings()
        case .clipboard: ClipboardSettings()
        case .audioInput: AudioInputSettings()
        case .audioOutput: AudioOutputSettings()
        case .scratchpad: ScratchpadSettings()
        case .screenshot: ScreenshotSettings()
        case .screenRecorder: ScreenRecorderSettings()
        case .windowLayout: WindowLayoutSettings()
        case .shelf: ShelfSettings()
        case .shortcuts: ShortcutsSettings()
        case .dataPermissions: DataPermissionsSettings()
        case .about: AboutSettings()
        }
    }
}

/// Search field for the macOS 26 sidebar, styled after the system pill.
/// It sits on a fixed header outside the List, so scrolling rows can never
/// cross it (issues #183, #254). Esc and the clear button empty the query,
/// matching the system field.
private struct SidebarSearchField: View {
    @ObservedObject private var l10n = L10n.shared
    @Binding var query: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(l10n.s.settingsSearchPlaceholder, text: $query)
                .textFieldStyle(.plain)
                .focused(isFocused)
                .onExitCommand { query = "" }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.s.urlCleanerClearButton)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 7)
        .background(.quaternary.opacity(0.5), in: Capsule())
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

private extension View {
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
