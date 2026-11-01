// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

// MARK: - Auto Scroller & Clip View Accessor

final class HubStripAutoScroller: ObservableObject {
    private weak var scrollView: NSScrollView?
    private var timer: Timer?
    private var lastTick: TimeInterval = 0
    private var speed: CGFloat = 0
    var onTick: ((CGFloat) -> Void)?

    func attach(_ scroll: NSScrollView) {
        self.scrollView = scroll
    }

    func updateSpeed(_ newSpeed: CGFloat) {
        self.speed = newSpeed
        if newSpeed == 0 {
            stop()
        } else if timer == nil {
            start()
        }
    }

    private func start() {
        lastTick = ProcessInfo.processInfo.systemUptime
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        self.timer = t
        RunLoop.main.add(t, forMode: .common)
        RunLoop.main.add(t, forMode: .eventTracking)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        speed = 0
    }

    private func tick() {
        guard let scrollView, let document = scrollView.documentView, speed != 0 else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = min(0.05, max(0, now - lastTick))
        lastTick = now
        let clip = scrollView.contentView
        let viewport = clip.bounds
        let maxX = max(0, document.bounds.width - viewport.width)
        let nextX = min(maxX, max(0, viewport.minX + speed * elapsed))
        if nextX != viewport.origin.x {
            clip.scroll(to: NSPoint(x: nextX, y: viewport.origin.y))
            scrollView.reflectScrolledClipView(clip)
            onTick?(nextX)
        }
    }

    deinit {
        timer?.invalidate()
    }
}

struct HubStripScrollAccessor: NSViewRepresentable {
    var onAttach: (NSScrollView) -> Void
    var onOffsetChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> AccessorView {
        let view = AccessorView()
        view.onAttach = onAttach
        view.onOffsetChange = onOffsetChange
        return view
    }

    func updateNSView(_ nsView: AccessorView, context: Context) {
        nsView.onAttach = onAttach
        nsView.onOffsetChange = onOffsetChange
    }

    final class AccessorView: NSView {
        var onAttach: ((NSScrollView) -> Void)?
        var onOffsetChange: ((CGFloat) -> Void)?
        private weak var observedClip: NSClipView?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            attach()
        }

        override func viewDidMoveToSuperview() {
            super.viewDidMoveToSuperview()
            attach()
        }

        private func attach() {
            guard let scroll = enclosingScrollView else { return }
            onAttach?(scroll)
            if observedClip !== scroll.contentView {
                if let old = observedClip {
                    NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: old)
                }
                observedClip = scroll.contentView
                scroll.contentView.postsBoundsChangedNotifications = true
                NotificationCenter.default.addObserver(self, selector: #selector(boundsChanged),
                                                       name: NSView.boundsDidChangeNotification, object: scroll.contentView)
            }
        }

        @objc private func boundsChanged() {
            guard let clip = observedClip else { return }
            onOffsetChange?(clip.bounds.origin.x)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

// MARK: - Hub Island Strip View

struct HubIslandStripView<Content: View>: View {
    let items: [LatticeHubItem]
    let notchWidth: CGFloat
    let isEditing: Bool
    @ObservedObject var launcher: LatticeHubService
    let onTap: (LatticeHubItem) -> Void
    @ViewBuilder let cellContent: (LatticeHubItem) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scrollOffset: CGFloat = 0
    @State private var draggingItem: LatticeHubItem?
    @State private var dragSourceIndex: Int?
    @State private var dragTargetIndex: Int?
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartLocation: CGPoint = .zero
    @State private var keyMonitor: Any?

    @StateObject private var scroller = HubStripAutoScroller()

    private var rows: Int { HubStripLayout.rows(for: items.count) }
    private var contentSize: CGSize { HubStripLayout.contentSize(count: items.count) }

    /// Dynamic Island compact content fits 5 columns (404pt) plus sliver (14pt) + spacing (6pt) = 424pt.
    private var viewportWidth: CGFloat {
        if contentSize.width <= 404 {
            return contentSize.width
        }
        return min(notchWidth, 424)
    }

    var body: some View {
        ScrollView(.horizontal) {
            ZStack(alignment: .topLeading) {
                // 1. Dashed Box Target Preview
                if draggingItem != nil, let target = dragTargetIndex {
                    let origin = HubStripLayout.slotOrigin(for: target, totalRows: rows)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .frame(width: HubStripLayout.itemWidth, height: HubStripLayout.itemHeight)
                        .offset(x: origin.x, y: origin.y)
                        .animation(reduceMotion ? nil : .snappy(duration: 0.22, extraBounce: 0.05), value: target)
                        .allowsHitTesting(false)
                        .zIndex(0)
                }

                // 2. Tile Items
                let visibleColMin = items.count > 40 ? max(0, Int((scrollOffset - 30) / HubStripLayout.columnStride) - 2) : 0
                let visibleColMax = items.count > 40 ? Int((scrollOffset + viewportWidth + 30) / HubStripLayout.columnStride) + 2 : Int.max

                ForEach(items) { item in
                    let origIndex = items.firstIndex(of: item) ?? 0
                    let isDragging = draggingItem == item
                    let pIndex = isDragging
                        ? (dragTargetIndex ?? origIndex)
                        : HubStripLayout.previewIndex(for: origIndex,
                                                      draggingFrom: dragSourceIndex,
                                                      targetIndex: dragTargetIndex)
                    let slotPos = HubStripLayout.gridPosition(for: pIndex, totalRows: rows)
                    let shouldRender = isDragging || (slotPos.col >= visibleColMin && slotPos.col <= visibleColMax)

                    if shouldRender {
                        let baseOrigin = HubStripLayout.slotOrigin(for: pIndex, totalRows: rows)
                        let sourceOrigin = HubStripLayout.slotOrigin(for: dragSourceIndex ?? origIndex, totalRows: rows)
                        let currentX = isDragging ? (sourceOrigin.x + dragOffset.width) : baseOrigin.x
                        let currentY = isDragging ? (sourceOrigin.y + dragOffset.height) : baseOrigin.y

                        cellContent(item)
                            .frame(width: HubStripLayout.itemWidth, height: HubStripLayout.itemHeight)
                            .scaleEffect(isDragging ? 1.06 : 1.0)
                            .shadow(color: isDragging ? Color.black.opacity(0.35) : Color.clear, radius: 8, x: 0, y: 4)
                            .offset(x: currentX, y: currentY)
                            .animation(isDragging || reduceMotion ? nil : .snappy(duration: 0.22, extraBounce: 0.05), value: pIndex)
                            .zIndex(isDragging ? 100 : 1)
                            .gesture(isEditing ? itemDragGesture(for: item, index: origIndex, origin: sourceOrigin) : nil)
                            .simultaneousGesture(itemLongPressGesture(for: item, index: origIndex, origin: sourceOrigin))
                    }
                }
            }
            .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
            .coordinateSpace(name: "hubStripContent")
        }
        .scrollIndicators(.never)
        .scrollTargetBehavior(HubStripScrollTargetBehavior(isDragging: draggingItem != nil))
        .frame(width: viewportWidth, height: contentSize.height, alignment: .leading)
        .coordinateSpace(name: "hubStripViewport")
        .background {
            HubStripScrollAccessor(onAttach: { scroll in
                scroller.attach(scroll)
            }, onOffsetChange: { offset in
                scrollOffset = offset
            })
        }
        .onAppear {
            scroller.onTick = { nextOffset in
                scrollOffset = nextOffset
                handleAutoScrollTick()
            }
        }
        .onDisappear {
            cancelDrag()
        }
        .onChange(of: isEditing) { _, editing in
            if !editing { cancelDrag() }
        }
    }

    // MARK: - Drag Gestures

    private func itemDragGesture(for item: LatticeHubItem, index: Int, origin: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("hubStripViewport"))
            .onChanged { value in
                if draggingItem == nil {
                    draggingItem = item
                    dragSourceIndex = index
                    dragTargetIndex = index
                    dragStartLocation = CGPoint(x: origin.x, y: origin.y)
                    dragOffset = .zero
                    installEscapeMonitor()
                }
                guard draggingItem == item else { return }
                dragOffset = value.translation
                let contentX = dragStartLocation.x + dragOffset.width + HubStripLayout.itemWidth / 2
                let contentY = dragStartLocation.y + dragOffset.height + HubStripLayout.itemHeight / 2
                let newTarget = HubStripLayout.closestIndex(to: CGPoint(x: contentX, y: contentY), count: items.count)
                if newTarget != dragTargetIndex {
                    if NotchSupport.usesHapticFeedback() {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                    }
                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.22, extraBounce: 0.05)) {
                        dragTargetIndex = newTarget
                    }
                }
                checkEdgeAutoScroll(viewportX: value.location.x)
            }
            .onEnded { _ in
                guard draggingItem == item else { return }
                finishDrop(for: item)
            }
    }

    private func itemLongPressGesture(for item: LatticeHubItem, index: Int, origin: CGPoint) -> some Gesture {
        LongPressGesture(minimumDuration: 0.25)
            .onEnded { _ in
                if !isEditing {
                    launcher.isEditing = true
                }
                if draggingItem == nil {
                    draggingItem = item
                    dragSourceIndex = index
                    dragTargetIndex = index
                    dragStartLocation = CGPoint(x: origin.x, y: origin.y)
                    dragOffset = .zero
                    if NotchSupport.usesHapticFeedback() {
                        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
                    }
                    installEscapeMonitor()
                }
            }
    }

    private func handleAutoScrollTick() {
        guard let _ = draggingItem else { return }
        let contentX = dragStartLocation.x + dragOffset.width + HubStripLayout.itemWidth / 2
        let contentY = dragStartLocation.y + dragOffset.height + HubStripLayout.itemHeight / 2
        let newTarget = HubStripLayout.closestIndex(to: CGPoint(x: contentX, y: contentY), count: items.count)
        if newTarget != dragTargetIndex {
            if NotchSupport.usesHapticFeedback() {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.22, extraBounce: 0.05)) {
                dragTargetIndex = newTarget
            }
        }
    }

    private func checkEdgeAutoScroll(viewportX: CGFloat) {
        let edge: CGFloat = 36
        let maxSpeed: CGFloat = 380
        if viewportX < edge {
            let intensity = max(0, min(1, (edge - viewportX) / edge))
            scroller.updateSpeed(-maxSpeed * intensity)
        } else if viewportX > viewportWidth - edge {
            let intensity = max(0, min(1, (viewportX - (viewportWidth - edge)) / edge))
            scroller.updateSpeed(maxSpeed * intensity)
        } else {
            scroller.updateSpeed(0)
        }
    }

    private func finishDrop(for item: LatticeHubItem) {
        scroller.stop()
        removeEscapeMonitor()
        let target = dragTargetIndex ?? (dragSourceIndex ?? 0)
        let source = dragSourceIndex ?? 0
        if target != source {
            launcher.moveTool(item, toIndex: target)
        }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
            draggingItem = nil
            dragSourceIndex = nil
            dragTargetIndex = nil
            dragOffset = .zero
        }
    }

    private func cancelDrag() {
        scroller.stop()
        removeEscapeMonitor()
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
            dragTargetIndex = dragSourceIndex
            draggingItem = nil
            dragSourceIndex = nil
            dragTargetIndex = nil
            dragOffset = .zero
        }
    }

    private func installEscapeMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                cancelDrag()
                return nil
            }
            return event
        }
    }

    private func removeEscapeMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}
