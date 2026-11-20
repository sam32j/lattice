// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The wallpaper page's fixed measures. The island sizes itself from these
/// (`height(for:)`), so it opens and changes at the page's own height
/// without measuring the view.
enum WallpaperIslandLayout {
    static let thumbHeight: CGFloat = 54
    static let gridSpacing: CGFloat = 8
    static let columns = 3
    static let rowsPerPage = 4
    static var pageSize: Int { columns * rowsPerPage }
    static let dotsSpacing: CGFloat = 8
    static let dotSize: CGFloat = 6
    static let sectionSpacing: CGFloat = 10
    static let statusHeight: CGFloat = 16
    static let groupHeaderHeight: CGFloat = 16
    static let groupInnerSpacing: CGFloat = 6
    static let groupSpacing: CGFloat = 14
    static let emptyHeight: CGFloat = 150
    static let inset: CGFloat = 2
    /// Imported folders scroll inside this.
    static var importedMaxHeight: CGFloat { gridHeight(rows: rowsPerPage) + 2 * groupChrome }

    static func rows(_ count: Int) -> Int { (count + columns - 1) / columns }

    static func gridHeight(rows: Int) -> CGFloat {
        CGFloat(rows) * thumbHeight + CGFloat(max(0, rows - 1)) * gridSpacing
    }

    static func pageCount(_ count: Int) -> Int {
        WallpaperSupport.pageCount(itemCount: count, pageSize: pageSize)
    }

    /// A header, its rule and the space around the rule.
    static var groupChrome: CGFloat { groupHeaderHeight + 2 * groupInnerSpacing + 1 }

    static func pagerHeight(itemCount: Int) -> CGFloat {
        let grid = gridHeight(rows: min(rowsPerPage, rows(itemCount)))
        return pageCount(itemCount) > 1 ? grid + dotsSpacing + dotSize : grid
    }

    static func importedHeight(groupSizes: [Int]) -> CGFloat {
        let natural = groupSizes.reduce(CGFloat(0)) { $0 + groupChrome + gridHeight(rows: rows($1)) }
            + CGFloat(max(0, groupSizes.count - 1)) * groupSpacing
        return min(natural, importedMaxHeight)
    }

    static func height(for service: WallpaperService) -> CGFloat {
        let items = service.visibleEntries
        let content: CGFloat
        if items.isEmpty {
            content = emptyHeight
        } else if service.filter == .own {
            content = importedHeight(groupSizes: service.ownGroups.map(\.entries.count))
        } else {
            content = pagerHeight(itemCount: items.count)
        }
        let status: CGFloat = service.isDownloading || service.lastError != nil
            ? sectionSpacing + statusHeight : 0
        return ceil(content + status + 2 * inset)
    }
}

/// Wallpaper tab in the menu panel.
struct WallpaperSection: View {
    private typealias Layout = WallpaperIslandLayout

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = WallpaperService.shared
    @Environment(\.notchPresentation) private var inNotch
    /// The island's page, as the paging scroll view reports it.
    @State private var islandPage: Int? = 0
    /// How many pictures the HUD's grid has built; more as it nears the end.
    @State private var hudLimit = Self.hudBatch
    @State private var viewerID = UUID()
    var collapsible = true
    var showHeader = true
    var onClose: (() -> Void)? = nil

    private static let hudBatch = 36

    private var text: WallpaperFeatureStrings {
        FeatureStrings.wallpaper(l10n.language)
    }

    private var allItems: [WallpaperSupport.Entry] { service.visibleEntries }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            if showHeader { header }
            if !inNotch {
                // The island's band holds the menu; the HUD keeps it in the
                // page's corner, under its pin and close buttons.
                HStack {
                    Spacer(minLength: 0)
                    WallpaperSourceMenu(surface: .hud)
                }
            }
            if allItems.isEmpty {
                emptyState
            } else if service.filter == .own {
                importedGallery
            } else if inNotch {
                islandPager
            } else {
                hudGrid
            }
            if let status = statusText {
                Text(status.text)
                    .font(.caption)
                    .foregroundStyle(status.isError ? Color.orange : Color.secondary)
                    .lineLimit(1)
                    .frame(height: Layout.statusHeight)
            }
        }
        .padding(Layout.inset)
        .onAppear {
            // own folders can change on disk; keep Apple catalog cache
            service.beginViewing(viewerID)
        }
        .onDisappear {
            service.endViewing(viewerID)
        }
        .onChange(of: service.filter) { _, _ in
            islandPage = 0
            hudLimit = Self.hudBatch
        }
        .onChange(of: allItems.count) { _, count in
            let last = max(0, Layout.pageCount(count) - 1)
            if (islandPage ?? 0) > last { islandPage = last }
        }
    }

    private var statusText: (text: String, isError: Bool)? {
        if service.isDownloading { return (text.downloading, false) }
        if let error = service.lastError { return (error, true) }
        return nil
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.tv")
                .font(.system(size: 13, weight: .semibold))
            Text(text.pageTitle)
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.s.menuClose)
            }
        }
    }

    private static var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Layout.gridSpacing), count: Layout.columns)
    }

    // MARK: - Island: pages that scroll sideways

    /// Four rows a page; a swipe or the wheel turns it, and the dots under
    /// it follow. Only the pages near the visible one are built.
    private var islandPager: some View {
        let items = allItems
        let pages = Layout.pageCount(items.count)
        let gridHeight = Layout.gridHeight(rows: min(Layout.rowsPerPage, Layout.rows(items.count)))
        return VStack(spacing: Layout.dotsSpacing) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(0..<pages, id: \.self) { page in
                        LazyVGrid(columns: Self.gridColumns, spacing: Layout.gridSpacing) {
                            ForEach(WallpaperSupport.pageSlice(items, page: page + 1,
                                                               pageSize: Layout.pageSize)) { entry in
                                thumb(entry)
                            }
                        }
                        .frame(height: gridHeight, alignment: .top)
                        .containerRelativeFrame(.horizontal)
                        .id(page)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.never)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $islandPage)
            .frame(height: gridHeight)
            if pages > 1 {
                WallpaperPageDots(count: pages, current: min(islandPage ?? 0, pages - 1))
                    .frame(maxWidth: .infinity)
                    .frame(height: Layout.dotSize)
            }
        }
    }

    // MARK: - HUD: one grid that grows as it scrolls

    /// Builds a batch of pictures at a time; reaching the last one builds the
    /// next. Each picture's thumbnail loads only once its cell appears.
    private var hudGrid: some View {
        let items = allItems
        let shown = items.prefix(hudLimit)
        return LazyVGrid(columns: Self.gridColumns, spacing: Layout.gridSpacing) {
            ForEach(shown) { entry in
                thumb(entry)
                    .onAppear {
                        if entry.id == shown.last?.id, hudLimit < items.count {
                            hudLimit += Self.hudBatch
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func thumb(_ entry: WallpaperSupport.Entry) -> some View {
        WallpaperThumbButton(
            entry: entry,
            isApplied: service.appliedPath == entry.imageURL.path,
            thumbEpoch: service.thumbEpoch,
            height: Layout.thumbHeight,
            appliesEnabled: !service.isApplying,
            downloadProgress: service.downloadProgress[entry.id],
            needsDownload: entry.needsDownload,
            downloadLabel: text.download
        ) {
            service.apply(entry)
        }
        .contextMenu {
            if entry.source == .own {
                Button(text.removeAdded, role: .destructive) { service.removeOwnEntry(entry) }
            }
        }
    }

    // MARK: - Imported

    /// Imported pictures under the folder each came from: the path, a
    /// rule, then the pictures. In the island it scrolls within its height.
    @ViewBuilder
    private var importedGallery: some View {
        if inNotch {
            let groups = service.ownGroups
            ScrollView(.vertical) { importedGroups }
                .scrollIndicators(.never)
                .frame(height: Layout.importedHeight(groupSizes: groups.map(\.entries.count)))
        } else {
            importedGroups
        }
    }

    private var importedGroups: some View {
        LazyVStack(alignment: .leading, spacing: Layout.groupSpacing) {
            ForEach(service.ownGroups) { group in
                VStack(alignment: .leading, spacing: Layout.groupInnerSpacing) {
                    Text(WallpaperSupport.displayPath(group.path))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(height: Layout.groupHeaderHeight)
                        .help(group.path)
                    Divider()
                    LazyVGrid(columns: Self.gridColumns, spacing: Layout.gridSpacing) {
                        ForEach(group.entries) { entry in thumb(entry) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Empty

    /// As the other tools' empty pages: the island's own empty view and
    /// pill, or the HUD's headline and accent button. Only Imported has a
    /// next step: adding a folder.
    @ViewBuilder
    private var emptyState: some View {
        if inNotch {
            Group {
                if service.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    NotchEmptyView(symbol: emptySymbol, message: emptyMessage) {
                        if service.filter == .own {
                            NotchPillButton(title: text.addFolder, prominent: true) {
                                service.addFolder(inNotch: true)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: Layout.emptyHeight)
        } else {
            Group {
                if service.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    hudEmptyState
                }
            }
            .frame(maxWidth: .infinity)
            // The scroll view's height, less the menu row above it.
            .containerRelativeFrame(.vertical) { length, _ in max(140, length - 36) }
        }
    }

    private var hudEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: emptySymbol)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(emptyMessage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            if service.filter == .own {
                Text(text.emptyOwnHint)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    service.addFolder()
                } label: {
                    Text(text.addFolder)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(text.addFolder)
                .padding(.top, 4)
            }
        }
    }

    private var emptySymbol: String {
        service.filter == .own ? "folder.badge.plus" : "photo.on.rectangle.angled"
    }

    private var emptyMessage: String {
        switch service.filter {
        case .all: return text.emptyAll
        case .own: return text.emptyOwn
        case .apple: return text.emptyApple
        }
    }
}

/// Page dots that show at most five. The active dot walks to the middle,
/// then stays there while the row slides under it, and walks on again for
/// the last two pages. Dots at a window edge with more pages beyond shrink.
struct WallpaperPageDots: View {
    let count: Int
    let current: Int

    static let visible = 5

    /// The first page the window shows.
    static func windowStart(count: Int, current: Int) -> Int {
        guard count > visible else { return 0 }
        return min(max(0, current - visible / 2), count - visible)
    }

    var body: some View {
        let start = Self.windowStart(count: count, current: current)
        let end = min(count, start + Self.visible)
        HStack(spacing: WallpaperIslandLayout.dotSize) {
            ForEach(start..<end, id: \.self) { page in
                let atEdge = (page == start && start > 0) || (page == end - 1 && end < count)
                Circle()
                    .fill(Color.white.opacity(page == current ? 0.9 : 0.3))
                    .frame(width: WallpaperIslandLayout.dotSize, height: WallpaperIslandLayout.dotSize)
                    .scaleEffect(atEdge ? 0.6 : 1)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: current)
        .accessibilityElement()
        .accessibilityLabel("\(current + 1) / \(count)")
    }
}

private struct WallpaperThumbButton: View {
    let entry: WallpaperSupport.Entry
    let isApplied: Bool
    let thumbEpoch: Int
    var height: CGFloat = 54
    var appliesEnabled = true
    /// Set while the picture downloads.
    var downloadProgress: Double? = nil
    /// An Apple picture macOS has not downloaded; choosing it downloads it.
    var needsDownload = false
    var downloadLabel = ""
    let action: () -> Void
    @State private var image: NSImage?

    private var previewPath: String { entry.previewURL.path }

    /// A download glyph in the corner, which becomes a ring while it runs.
    @ViewBuilder
    private var downloadBadge: some View {
        if let downloadProgress {
            ZStack {
                Circle().fill(.black.opacity(0.5))
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 2)
                    .padding(2)
                Circle()
                    .trim(from: 0, to: max(0.04, downloadProgress))
                    .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(2)
                    .animation(.linear(duration: 0.2), value: downloadProgress)
            }
            .frame(width: 16, height: 16)
            .padding(4)
            .accessibilityLabel(downloadLabel)
            .accessibilityValue("\(Int(downloadProgress * 100))%")
        } else if needsDownload {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.5))
                .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                .padding(4)
                .accessibilityHidden(true)
        }
    }
    // epoch in id so a generation bump restarts load (same path can stay blank otherwise)
    private var taskID: String { "\(previewPath)#\(thumbEpoch)" }

    var body: some View {
        Button(action: action) {
            WallpaperThumbnailView(image: image, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isApplied ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .overlay(alignment: .bottomTrailing) { downloadBadge }
        }
        .buttonStyle(.plain)
        .disabled(!appliesEnabled || downloadProgress != nil)
        .help(needsDownload ? "\(entry.title) — \(downloadLabel)" : entry.title)
        .accessibilityLabel(entry.title)
        .accessibilityHint(needsDownload ? downloadLabel : "")
        .onAppear {
            if image == nil, let cached = WallpaperThumbnailCache.image(for: entry.previewURL) {
                image = cached
            }
        }
        .task(id: taskID) {
            let gen = WallpaperThumbnailCache.snapshotGeneration()
            if let cached = WallpaperThumbnailCache.image(for: entry.previewURL) {
                image = cached
                return
            }
            let url = entry.previewURL
            let loaded = await WallpaperThumbnailCache.load(url: url, generation: gen)
            guard !Task.isCancelled,
                  WallpaperThumbnailCache.matchesGeneration(gen)
            else { return }
            image = loaded
        }
    }
}
