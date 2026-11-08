// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import CoreGraphics
import Foundation
import SwiftUI

// MARK: - Layout Constants & Arithmetic
enum HubStripLayout {
    static let itemWidth: CGFloat = NotchLayout.toolWidth  // 76
    static let itemHeight: CGFloat = NotchLayout.toolHeight  // 72
    static let spacing: CGFloat = NotchLayout.toolSpacing  // 6
    static let rowSpacing: CGFloat = NotchLayout.toolSpacing  // 6
    static let itemsPerRowPerPage: Int = NotchSupport.toolColumns  // 5
    static let itemsPerPage: Int = 10  // 2 rows * 5 columns
    static let twoRowThreshold: Int = 6
    static var columnStride: CGFloat { itemWidth + spacing }  // 82
    static var rowStride: CGFloat { itemHeight + rowSpacing }  // 78

    static func rows(for count: Int, columns: Int = itemsPerRowPerPage) -> Int {
        guard count > 0 else { return 0 }
        return count <= max(1, columns) ? 1 : 2
    }

    static func gridPosition(
        for index: Int, totalRows: Int, columns: Int = itemsPerRowPerPage
    ) -> (row: Int, col: Int, page: Int) {
        if totalRows <= 1 {
            return (0, index, 0)
        }
        let columns = max(1, columns)
        let page = index / (columns * 2)
        let rem = index % (columns * 2)
        let row = rem < columns ? 0 : 1
        let colInPage = rem % columns
        let col = page * columns + colInPage
        return (row, col, page)
    }

    static func index(row: Int, col: Int, columns: Int = itemsPerRowPerPage) -> Int {
        let columns = max(1, columns)
        let page = col / columns
        let colInPage = col % columns
        return page * (columns * 2) + row * columns + colInPage
    }

    static func railIndex(
        after current: Int,
        count: Int,
        columns: Int = itemsPerRowPerPage,
        direction: QuickToolsSupport.GridDirection
    ) -> Int {
        guard count > 0 else { return 0 }
        let current = min(max(current, 0), count - 1)
        let totalRows = rows(for: count, columns: columns)

        if totalRows <= 1 {
            switch direction {
            case .left: return max(0, current - 1)
            case .right: return min(count - 1, current + 1)
            case .up, .down: return current
            }
        }

        let pos = gridPosition(for: current, totalRows: totalRows, columns: columns)
        switch direction {
        case .left:
            let targetCol = pos.col - 1
            guard targetCol >= 0 else { return current }
            let candidate = index(row: pos.row, col: targetCol, columns: columns)
            if candidate < count { return candidate }
            let fallback = index(row: 0, col: targetCol, columns: columns)
            return fallback < count ? fallback : current
        case .right:
            let targetCol = pos.col + 1
            let candidate = index(row: pos.row, col: targetCol, columns: columns)
            if candidate < count { return candidate }
            if pos.row == 1 {
                let fallback = index(row: 0, col: targetCol, columns: columns)
                if fallback < count { return fallback }
            }
            return current
        case .up:
            guard pos.row > 0 else { return current }
            let candidate = index(row: pos.row - 1, col: pos.col, columns: columns)
            return candidate < count ? candidate : current
        case .down:
            guard pos.row < totalRows - 1 else { return current }
            let candidate = index(row: pos.row + 1, col: pos.col, columns: columns)
            return candidate < count ? candidate : current
        }
    }

    static func totalColumns(count: Int, columns: Int = itemsPerRowPerPage) -> Int {
        guard count > 0 else { return 0 }
        let columns = max(1, columns)
        if count <= columns { return count }
        let fullPages = count / (columns * 2)
        let rem = count % (columns * 2)
        let lastCols = rem == 0 ? 0 : min(columns, rem)
        return fullPages * columns + lastCols
    }

    static func slotOrigin(for index: Int, totalRows: Int) -> CGPoint {
        let pos = gridPosition(for: index, totalRows: totalRows)
        let x = CGFloat(pos.col) * columnStride
        let y = CGFloat(pos.row) * rowStride
        return CGPoint(x: x, y: y)
    }

    static func slotCenter(for index: Int, totalRows: Int) -> CGPoint {
        let origin = slotOrigin(for: index, totalRows: totalRows)
        return CGPoint(x: origin.x + itemWidth / 2, y: origin.y + itemHeight / 2)
    }

    static func contentSize(count: Int, columns: Int = itemsPerRowPerPage) -> CGSize {
        guard count > 0 else { return .zero }
        let r = rows(for: count, columns: columns)
        let cols = totalColumns(count: count, columns: columns)
        let width = cols > 0 ? CGFloat(cols) * itemWidth + CGFloat(cols - 1) * spacing : 0
        let height = r > 0 ? CGFloat(r) * itemHeight + CGFloat(r - 1) * rowSpacing : 0
        return CGSize(width: width, height: height)
    }

    static func previewIndex(
        for originalIndex: Int, draggingFrom sourceIndex: Int?, targetIndex: Int?
    ) -> Int {
        guard let source = sourceIndex, let target = targetIndex, source != target else {
            return originalIndex
        }
        if originalIndex == source {
            return target
        }
        if target > source {
            if originalIndex > source && originalIndex <= target {
                return originalIndex - 1
            }
        } else {
            if originalIndex >= target && originalIndex < source {
                return originalIndex + 1
            }
        }
        return originalIndex
    }
}

/// Immutable slots keep native targeting independent of the animated tiles.
/// Both presentations use the same insertion geometry and pointer deadband.
struct HubToolLayout: Equatable {
    let frames: [CGRect]
    let size: CGSize
    let pageStride: CGFloat
    let isPaged: Bool
    let pages: Int

    init(
        frames: [CGRect], size: CGSize, pageStride: CGFloat = 0, isPaged: Bool = false, pages: Int = 1
    ) {
        self.frames = frames
        self.size = size
        self.pageStride = pageStride
        self.isPaged = isPaged
        self.pages = pages
    }

    /// The width occupied by a full page of tiles, excluding neighboring previews.
    var pageContentWidth: CGFloat {
        max(0, size.width - CGFloat(max(0, pages - 1)) * pageStride)
    }

    /// The scroll offset keeps the first page flush left, the last page flush
    /// right, and the middle pages centered between equal neighboring previews.
    func pageOffset(for page: Int, viewportWidth: CGFloat) -> CGFloat {
        guard isPaged else { return 0 }

        let page = min(max(0, page), pages - 1)
        let remaining = max(0, viewportWidth - pageContentWidth)
        let inset: CGFloat

        if page == 0 {
            inset = 0
        } else if page == pages - 1 {
            inset = remaining
        } else {
            inset = remaining / 2
        }

        return min(
            max(0, size.width - viewportWidth),
            max(0, CGFloat(page) * pageStride - inset))
    }

    static func island(count: Int, width: CGFloat = 424, columns: Int = 5) -> Self {
        let count = max(0, count)
        let columns = max(1, columns)
        let width = max(0, width)
        let rows = HubStripLayout.rows(for: count, columns: columns)
        let capacity = columns * 2
        let paged = count > capacity
        let gap = HubStripLayout.spacing
        let peek: CGFloat = paged ? min(14, width / 10) : 0

        // Preserve the established tile width and spacing within a page.
        let sizingColumns = min(columns, max(HubStripLayout.itemsPerRowPerPage, count))
        let tileWidth = max(
            0,
            (width - peek - CGFloat(paged ? sizingColumns : sizingColumns - 1) * gap)
                / CGFloat(sizingColumns))
        let tileStride = tileWidth + gap
        let pages = max(1, (count + capacity - 1) / capacity)
        let pageContentWidth = CGFloat(columns) * tileWidth + CGFloat(columns - 1) * gap

        // At 424pt wide, the middle-page left/right neighboring tiles each
        // reveal 7pt; 3pt is the inter-page gap. Edge pages use the space on
        // their missing-neighbor side rather than showing blank padding.
        let pageStride = pageContentWidth + (paged ? gap / 2 : gap)
        let height =
            rows == 0
            ? 0
            : CGFloat(rows) * HubStripLayout.itemHeight + CGFloat(rows - 1) * gap

        let frames: [CGRect] = (0..<count).map { index in
            let position = HubStripLayout.gridPosition(
                for: index, totalRows: rows,
                columns: columns)
            return CGRect(
                x: CGFloat(position.page) * pageStride
                    + CGFloat(position.col % columns) * tileStride,
                y: CGFloat(position.row) * HubStripLayout.rowStride,
                width: tileWidth, height: HubStripLayout.itemHeight)
        }

        let contentWidth =
            paged
            ? CGFloat(pages - 1) * pageStride + pageContentWidth
            : width

        return Self(
            frames: frames, size: CGSize(width: contentWidth, height: height),
            pageStride: pageStride, isPaged: paged, pages: pages)
    }

    static func hudHeight(count: Int) -> CGFloat {
        let rows = (max(0, count) + 2) / 3
        return CGFloat(rows) * 64 + CGFloat(max(0, rows - 1)) * 10
    }

    static func hud(count: Int, width: CGFloat) -> Self {
        let tileWidth = max(0, (width - 20) / 3)
        return Self(
            frames: (0..<max(0, count)).map {
                CGRect(
                    x: CGFloat($0 % 3) * (tileWidth + 10), y: CGFloat($0 / 3) * 74,
                    width: tileWidth, height: 64)
            }, size: CGSize(width: max(0, width), height: hudHeight(count: count)))
    }

    func closestIndex(to point: CGPoint, keeping current: Int? = nil) -> Int? {
        guard point.x.isFinite, point.y.isFinite,
            let nearest = frames.indices.min(by: {
                distance(to: $0, from: point) < distance(to: $1, from: point)
            })
        else {
            return nil
        }
        if let current, frames.indices.contains(current), current != nearest,
            distance(to: current, from: point) - distance(to: nearest, from: point) < 8
        {
            return current
        }
        return nearest
    }

    private func distance(to index: Int, from point: CGPoint) -> CGFloat {
        hypot(point.x - frames[index].midX, point.y - frames[index].midY)
    }
}

// MARK: - Island Horizontal Paging Logic
enum HubIslandPagingLogic {
    static let slowThreshold: CGFloat = 100
    static let flickMinDisplacement: CGFloat = 30
    static let flickMinVelocity: CGFloat = 180

    static func targetPage(
        startPage: Int,
        displacement: CGFloat,
        velocity: CGFloat,
        maxPage: Int,
        slowThreshold: CGFloat = slowThreshold,
        flickMinDisplacement: CGFloat = flickMinDisplacement,
        flickMinVelocity: CGFloat = flickMinVelocity
    ) -> Int {
        if displacement >= slowThreshold
            || (displacement >= flickMinDisplacement && velocity > flickMinVelocity)
        {
            return min(startPage + 1, maxPage)
        } else if displacement <= -slowThreshold
            || (displacement <= -flickMinDisplacement && velocity < -flickMinVelocity)
        {
            return max(startPage - 1, 0)
        } else {
            return startPage
        }
    }
}
