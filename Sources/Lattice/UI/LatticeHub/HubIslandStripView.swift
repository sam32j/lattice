// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// Paging and live slot feedback share the native session used by the hide
/// tray. Only a changed destination index updates SwiftUI while dragging.
struct HubIslandStripView<Content: View>: View {
    let items: [LatticeHubItem]
    let notchWidth: CGFloat
    let columns: Int
    let isEditing: Bool
    @ObservedObject var launcher: LatticeHubService
    @ObservedObject var session: HubDragSession
    let onTap: (LatticeHubItem) -> Void
    let cellContent: (LatticeHubItem, @escaping () -> Void) -> Content

    init(
        items: [LatticeHubItem], notchWidth: CGFloat, columns: Int,
        isEditing: Bool, launcher: LatticeHubService, session: HubDragSession,
        onTap: @escaping (LatticeHubItem) -> Void,
        @ViewBuilder cellContent: @escaping (LatticeHubItem, @escaping () -> Void) -> Content
    ) {
        self.items = items
        self.notchWidth = notchWidth
        self.columns = columns
        self.isEditing = isEditing
        self.launcher = launcher
        self.session = session
        self.onTap = onTap
        self.cellContent = cellContent
    }

    init(
        items: [LatticeHubItem], notchWidth: CGFloat, columns: Int,
        isEditing: Bool, launcher: LatticeHubService, session: HubDragSession,
        onTap: @escaping (LatticeHubItem) -> Void,
        @ViewBuilder cellContent: @escaping (LatticeHubItem) -> Content
    ) {
        self.init(
            items: items, notchWidth: notchWidth, columns: columns,
            isEditing: isEditing, launcher: launcher, session: session, onTap: onTap
        ) { item, _ in
            cellContent(item)
        }
    }

    @StateObject private var scrollState = HubScrollState()
    @State private var visiblePage = 0
    @State private var isTrackingOffset = false

    private var isShowingHubGrid: Bool {
        let notch = NotchService.shared
        return notch.expanded && [.hub, .controls, .mixer].contains(notch.selected)
            && launcher.activeUtility == nil
    }

    private var layout: HubToolLayout {
        .island(count: items.count, width: notchWidth, columns: columns)
    }

    var body: some View {
        Group {
            if layout.isPaged {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        ZStack(alignment: .topLeading) {
                            HubScrollOffsetTracker { offset in
                                // AppKit reports offset zero while a ScrollView is being
                                // mounted or torn down. Those reports must not overwrite
                                // the page saved before opening a child module.
                                guard isTrackingOffset, isShowingHubGrid else { return }
                                let page = pageIndex(at: offset)
                                if let target = scrollState.programmaticTargetPage,
                                   page != target { return }
                                scrollState.currentOffset = offset
                                // Scroll bounds notifications arrive on every animation frame.
                                // A redundant @Published assignment still broadcasts a change
                                // and redraws the entire Island/Hub view hierarchy.
                                commitPageIfChanged(page)
                            } onScrollStart: { startOffset in
                                guard isTrackingOffset, isShowingHubGrid else { return }
                                scrollState.programmaticTargetPage = nil
                                scrollState.gestureStartOffset = startOffset
                                scrollState.gestureStartPage = pageIndex(at: startOffset)
                            } onScrollEnd: {
                                guard isTrackingOffset, isShowingHubGrid else { return }
                                scrollState.gestureStartOffset = nil
                                let page = pageIndex(at: scrollState.currentOffset)
                                if let target = scrollState.programmaticTargetPage,
                                   page != target { return }
                                commitPageIfChanged(page)
                            }
                            .frame(width: 0, height: 0)
                            .allowsHitTesting(false)

                            // Invisible targets match the non-uniform first/last page offsets.
                            HStack(spacing: 0) {
                                ForEach(0..<layout.pages, id: \.self) { page in
                                    let start = layout.pageOffset(
                                        for: page,
                                        viewportWidth: notchWidth)
                                    let end =
                                        page + 1 < layout.pages
                                        ? layout.pageOffset(for: page + 1, viewportWidth: notchWidth)
                                        : layout.size.width

                                    Color.clear
                                        .frame(width: max(0, end - start), height: layout.size.height)
                                        .id("hub_island_page_\(page)")
                                }
                            }
                            .scrollTargetLayout()

                            surface(proxy: proxy)
                        }
                    }
                    .scrollIndicators(.never)
                    .scrollDisabled(session.active != nil)
                    .scrollTargetBehavior(
                        HubIslandPagingBehavior(
                            layout: layout, viewportWidth: notchWidth, state: scrollState)
                    )
                    .overlay { edgeNavigation(proxy: proxy) }
                    .onAppear {
                        isTrackingOffset = false
                        let target = min(max(0, launcher.hubIslandPage), max(0, layout.pages - 1))
                        visiblePage = target
                        scrollState.currentPage = target
                        scrollState.currentOffset = layout.pageOffset(for: target, viewportWidth: notchWidth)
                        scrollState.programmaticTargetPage = target > 0 ? target : nil
                        DispatchQueue.main.async {
                            proxy.scrollTo("hub_island_page_\(target)", anchor: .leading)
                            isTrackingOffset = true
                        }
                    }
                    .onChange(of: launcher.selectedIndex) { _, _ in
                        scrollToSelectedItem(proxy: proxy)
                    }
                    .onChange(of: launcher.navigationToken) { _, _ in
                        scrollToSelectedItem(proxy: proxy)
                    }
                    // A floating-Hub presentation may change presentationID
                    // while the Island stays open; it must not reset Island paging.
                    .onChange(of: layout.pages) { _, pageCount in
                        if visiblePage >= pageCount {
                            scrollToPage(max(0, pageCount - 1), proxy: proxy)
                        }
                    }
                }
            } else {
                surface(proxy: nil)
            }
        }
        .frame(width: notchWidth, height: layout.size.height, alignment: .leading)
        .onDisappear {
            isTrackingOffset = false
            session.cancel()
        }
        .onChange(of: isEditing) { _, editing in
            if !editing { session.cancel() }
        }
    }

    /// Only a *different* page may invalidate the launcher and its observers.
    /// Keep the raw pixel offset in HubScrollState (not @Published) so the
    /// native ScrollView can continue scrolling without SwiftUI re-rendering.
    private func commitPageIfChanged(_ page: Int) {
        if scrollState.currentPage != page { scrollState.currentPage = page }
        if visiblePage != page { visiblePage = page }
        if launcher.hubIslandPage != page { launcher.hubIslandPage = page }
    }

    private func pageIndex(at offset: CGFloat) -> Int {
        (0..<layout.pages).min { lhs, rhs in
            abs(layout.pageOffset(for: lhs, viewportWidth: notchWidth) - offset)
                < abs(layout.pageOffset(for: rhs, viewportWidth: notchWidth) - offset)
        } ?? 0
    }

    /// Clickable strips cover the full area beyond this page's first/last tile,
    /// including the neighboring page preview. The current grid stays clickable.
    @ViewBuilder
    private func edgeNavigation(proxy: ScrollViewProxy) -> some View {
        let page = min(max(0, visiblePage), layout.pages - 1)
        let offset = layout.pageOffset(for: page, viewportWidth: notchWidth)
        let leading = max(0, CGFloat(page) * layout.pageStride - offset)
        let trailing = max(0, notchWidth - leading - layout.pageContentWidth)

        HStack(spacing: 0) {
            if page > 0, leading > 0 {
                Button {
                    scrollToPage(page - 1, proxy: proxy)
                } label: {
                    Color.clear.frame(width: leading, height: layout.size.height)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Previous page")
            }

            Spacer(minLength: 0)

            if page < layout.pages - 1, trailing > 0 {
                Button {
                    scrollToPage(page + 1, proxy: proxy)
                } label: {
                    Color.clear.frame(width: trailing, height: layout.size.height)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Next page")
            }
        }
        .buttonStyle(.plain)
        .frame(width: notchWidth, height: layout.size.height)
        .allowsHitTesting(session.active == nil)
    }

    private func scrollToSelectedItem(proxy: ScrollViewProxy) {
        guard let index = launcher.selectedIndex, items.indices.contains(index) else { return }
        let capacity = max(1, columns * 2)
        scrollToPage(index / capacity, proxy: proxy)
    }

    private func scrollToPage(_ targetPage: Int, proxy: ScrollViewProxy) {
        let page = min(max(0, targetPage), max(0, layout.pages - 1))
        scrollState.programmaticTargetPage = page
        scrollState.currentOffset = layout.pageOffset(for: page, viewportWidth: notchWidth)
        commitPageIfChanged(page)

        withAnimation(.easeInOut(duration: 0.25)) {
            proxy.scrollTo("hub_island_page_\(page)", anchor: .leading)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if scrollState.programmaticTargetPage == page {
                scrollState.programmaticTargetPage = nil
            }
        }
    }

    private func handleTap(for item: LatticeHubItem, proxy: ScrollViewProxy?) {
        if layout.isPaged, let index = items.firstIndex(of: item), let proxy {
            let capacity = max(1, columns * 2)
            let itemPage = min(max(0, index / capacity), layout.pages - 1)
            if itemPage != scrollState.currentPage {
                scrollToPage(itemPage, proxy: proxy)
                return
            }
        }
        onTap(item)
    }

    @ViewBuilder
    private func surface(proxy: ScrollViewProxy?) -> some View {
        HubToolSurface(
            items: items, layout: layout, isEditing: isEditing,
            session: session, onTap: { handleTap(for: $0, proxy: proxy) },
            onManage: { launcher.isEditing = true },
            cellContent: { item in
                cellContent(item, { handleTap(for: item, proxy: proxy) })
            })
    }
}

final class HubScrollState: ObservableObject {
    var currentPage: Int = 0
    var currentOffset: CGFloat = 0
    var gestureStartOffset: CGFloat? = nil
    var gestureStartPage: Int = 0
    var programmaticTargetPage: Int? = nil

    func reset() {
        currentPage = 0
        currentOffset = 0
        gestureStartOffset = nil
        gestureStartPage = 0
        programmaticTargetPage = nil
    }
}

private struct HubScrollOffsetTracker: NSViewRepresentable {
    let onOffsetChange: (CGFloat) -> Void
    let onScrollStart: (CGFloat) -> Void
    let onScrollEnd: () -> Void

    func makeNSView(context: Context) -> TrackerNSView {
        let view = TrackerNSView()
        view.onOffsetChange = onOffsetChange
        view.onScrollStart = onScrollStart
        view.onScrollEnd = onScrollEnd
        return view
    }

    func updateNSView(_ nsView: TrackerNSView, context: Context) {
        nsView.onOffsetChange = onOffsetChange
        nsView.onScrollStart = onScrollStart
        nsView.onScrollEnd = onScrollEnd
    }
}

final class TrackerNSView: NSView {
    var onOffsetChange: ((CGFloat) -> Void)?
    var onScrollStart: ((CGFloat) -> Void)?
    var onScrollEnd: (() -> Void)?

    private var boundsObserver: NSObjectProtocol?
    private var startObserver: NSObjectProtocol?
    private var endObserver: NSObjectProtocol?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachObservers()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        attachObservers()
    }

    private func attachObservers() {
        guard let scrollView = enclosingScrollView else { return }
        let clipView = scrollView.contentView

        if boundsObserver == nil {
            clipView.postsBoundsChangedNotifications = true
            boundsObserver = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self] _ in
                guard let self, let clip = self.enclosingScrollView?.contentView else { return }
                self.onOffsetChange?(clip.bounds.origin.x)
            }
        }

        if startObserver == nil {
            startObserver = NotificationCenter.default.addObserver(
                forName: NSScrollView.willStartLiveScrollNotification,
                object: scrollView,
                queue: .main
            ) { [weak self] _ in
                guard let self, let clip = self.enclosingScrollView?.contentView else { return }
                self.onScrollStart?(clip.bounds.origin.x)
            }
        }

        if endObserver == nil {
            endObserver = NotificationCenter.default.addObserver(
                forName: NSScrollView.didEndLiveScrollNotification,
                object: scrollView,
                queue: .main
            ) { [weak self] _ in
                self?.onScrollEnd?()
            }
        }
    }

    deinit {
        if let boundsObserver { NotificationCenter.default.removeObserver(boundsObserver) }
        if let startObserver { NotificationCenter.default.removeObserver(startObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }
}

private struct HubIslandPagingBehavior: ScrollTargetBehavior {
    let layout: HubToolLayout
    let viewportWidth: CGFloat
    let state: HubScrollState

    private func offset(for page: Int, maxScroll: CGFloat) -> CGFloat {
        min(max(0, layout.pageOffset(for: page, viewportWidth: viewportWidth)), maxScroll)
    }

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let maxScroll = max(0, context.contentSize.width - context.containerSize.width)
        guard maxScroll > 0 else { return }
        let maxPage = max(0, layout.pages - 1)

        if let request = state.programmaticTargetPage {
            let page = min(max(0, request), maxPage)
            let snapped = offset(for: page, maxScroll: maxScroll)
            state.currentPage = page
            state.currentOffset = snapped
            target.rect.origin.x = snapped
            return
        }

        let startPage = min(
            max(
                0,
                state.gestureStartOffset != nil
                    ? state.gestureStartPage : state.currentPage), maxPage)
        let startX = offset(for: startPage, maxScroll: maxScroll)
        let displacement =
            state.gestureStartOffset != nil
            ? state.currentOffset - startX
            : target.rect.origin.x - startX

        let page = HubIslandPagingLogic.targetPage(
            startPage: startPage, displacement: displacement,
            velocity: context.velocity.dx, maxPage: maxPage)
        let snapped = offset(for: page, maxScroll: maxScroll)

        state.currentPage = page
        state.currentOffset = snapped
        state.gestureStartOffset = nil
        target.rect.origin.x = snapped
    }
}
