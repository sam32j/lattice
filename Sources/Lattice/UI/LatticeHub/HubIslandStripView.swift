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
    @ViewBuilder let cellContent: (LatticeHubItem) -> Content

    @StateObject private var scrollState = HubScrollState()

    private var layout: HubToolLayout { .island(count: items.count, width: notchWidth, columns: columns) }

    var body: some View {
        Group {
            if layout.isPaged {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        ZStack(alignment: .topLeading) {
                            HubScrollOffsetTracker { offset in
                                scrollState.currentOffset = offset
                            } onScrollStart: { startOffset in
                                scrollState.gestureStartOffset = startOffset
                                let stride = max(1, layout.pageStride)
                                scrollState.gestureStartPage = Int(round(startOffset / stride))
                            } onScrollEnd: {
                                scrollState.gestureStartOffset = nil
                            }
                            .frame(width: 0, height: 0)
                            .allowsHitTesting(false)

                            HStack(spacing: 0) {
                                ForEach(0..<layout.pages, id: \.self) { pageIndex in
                                    Color.clear
                                        .frame(width: pageIndex == layout.pages - 1 ? notchWidth : layout.pageStride,
                                               height: layout.size.height)
                                        .id("hub_island_page_\(pageIndex)")
                                }
                            }
                            .scrollTargetLayout()
                            surface
                        }
                    }
                    .scrollIndicators(.never)
                    .scrollDisabled(session.active != nil)
                    .scrollTargetBehavior(HubIslandPagingBehavior(pageStride: layout.pageStride, state: scrollState))
                    .onChange(of: launcher.selectedIndex) { _, newIndex in
                        guard let newIndex, items.indices.contains(newIndex) else { return }
                        let capacity = max(1, columns * 2)
                        let targetPage = min(max(0, newIndex / capacity), max(0, layout.pages - 1))
                        scrollState.currentPage = targetPage
                        scrollState.currentOffset = CGFloat(targetPage) * layout.pageStride
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo("hub_island_page_\(targetPage)", anchor: .leading)
                        }
                    }
                    .onChange(of: launcher.presentationID) { _, _ in
                        scrollState.reset()
                        proxy.scrollTo("hub_island_page_0", anchor: .leading)
                    }
                }
            } else { surface }
        }
        .frame(width: notchWidth, height: layout.size.height, alignment: .leading)
        .onDisappear {
            session.cancel()
            scrollState.reset()
        }
        .onChange(of: isEditing) { _, editing in if !editing { session.cancel() } }
    }

    private var surface: some View {
        HubToolSurface(items: items, layout: layout, isEditing: isEditing,
            session: session, onTap: onTap, onManage: { launcher.isEditing = true }, cellContent: cellContent)
    }
}

final class HubScrollState: ObservableObject {
    var currentPage: Int = 0
    var currentOffset: CGFloat = 0
    var gestureStartOffset: CGFloat? = nil
    var gestureStartPage: Int = 0

    func reset() {
        currentPage = 0
        currentOffset = 0
        gestureStartOffset = nil
        gestureStartPage = 0
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
    let pageStride: CGFloat
    let state: HubScrollState

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let stride = max(1, pageStride)
        let maxScroll = max(0, context.contentSize.width - context.containerSize.width)
        guard maxScroll > 0 else { return }

        let maxPage = Int(ceil(maxScroll / stride))
        let startPage: Int
        if state.gestureStartOffset != nil {
            startPage = min(max(0, state.gestureStartPage), maxPage)
        } else {
            startPage = min(max(0, state.currentPage), maxPage)
        }

        let startX = CGFloat(startPage) * stride
        let currentX = state.currentOffset
        let displacement: CGFloat
        if state.gestureStartOffset != nil || currentX != 0 {
            displacement = currentX - startX
        } else {
            displacement = target.rect.origin.x - startX
        }

        let velocity = context.velocity.dx

        let targetPage = HubIslandPagingLogic.targetPage(
            startPage: startPage,
            displacement: displacement,
            velocity: velocity,
            maxPage: maxPage
        )

        state.currentPage = targetPage
        state.currentOffset = CGFloat(targetPage) * stride
        state.gestureStartOffset = nil

        let snappedX = max(0, min(CGFloat(targetPage) * stride, maxScroll))
        target.rect.origin.x = snappedX
    }
}
