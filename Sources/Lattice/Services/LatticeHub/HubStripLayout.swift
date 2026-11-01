// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import CoreGraphics
import Foundation
import SwiftUI

// MARK: - Layout Constants & Arithmetic

enum HubStripLayout {
    static let itemWidth: CGFloat = NotchLayout.toolWidth        // 76
    static let itemHeight: CGFloat = NotchLayout.toolHeight      // 72
    static let spacing: CGFloat = NotchLayout.toolSpacing        // 6
    static let rowSpacing: CGFloat = NotchLayout.toolSpacing     // 6
    static let itemsPerRowPerPage: Int = NotchSupport.toolColumns // 5
    static let itemsPerPage: Int = 10                            // 2 rows * 5 columns
    static let twoRowThreshold: Int = 6

    static var columnStride: CGFloat { itemWidth + spacing }     // 82
    static var rowStride: CGFloat { itemHeight + rowSpacing }    // 78

    static func rows(for count: Int) -> Int {
        guard count > 0 else { return 0 }
        return count < twoRowThreshold ? 1 : 2
    }

    static func gridPosition(for index: Int, totalRows: Int) -> (row: Int, col: Int, page: Int) {
        if totalRows <= 1 {
            return (0, index, 0)
        }
        let page = index / itemsPerPage
        let rem = index % itemsPerPage
        let row = rem < itemsPerRowPerPage ? 0 : 1
        let colInPage = rem % itemsPerRowPerPage
        let col = page * itemsPerRowPerPage + colInPage
        return (row, col, page)
    }

    static func totalColumns(count: Int) -> Int {
        guard count > 0 else { return 0 }
        if count < twoRowThreshold { return count }
        let fullPages = count / itemsPerPage
        let rem = count % itemsPerPage
        let lastCols = rem == 0 ? 0 : min(itemsPerRowPerPage, rem)
        return fullPages * itemsPerRowPerPage + lastCols
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

    static func contentSize(count: Int) -> CGSize {
        guard count > 0 else { return .zero }
        let r = rows(for: count)
        let cols = totalColumns(count: count)
        let width = cols > 0 ? CGFloat(cols) * itemWidth + CGFloat(cols - 1) * spacing : 0
        let height = r > 0 ? CGFloat(r) * itemHeight + CGFloat(r - 1) * rowSpacing : 0
        return CGSize(width: width, height: height)
    }

    static func closestIndex(to point: CGPoint, count: Int) -> Int {
        guard count > 1 else { return 0 }
        let r = rows(for: count)
        let totalCols = totalColumns(count: count)
        guard totalCols > 0 else { return 0 }

        let approxCol = Int(round((point.x - itemWidth / 2) / columnStride))
        let minCol = max(0, approxCol - 2)
        let maxCol = min(totalCols - 1, approxCol + 2)

        var bestIndex = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude

        for c in minCol...maxCol {
            let page = c / itemsPerRowPerPage
            let colInPage = c % itemsPerRowPerPage
            for row in 0..<r {
                let idx: Int
                if r == 1 {
                    idx = c
                } else {
                    idx = page * itemsPerPage + (row == 0 ? 0 : itemsPerRowPerPage) + colInPage
                }
                guard idx >= 0 && idx < count else { continue }
                let center = slotCenter(for: idx, totalRows: r)
                let dx = point.x - center.x
                let dy = point.y - center.y
                let dist = dx * dx + dy * dy
                if dist < bestDistance {
                    bestDistance = dist
                    bestIndex = idx
                }
            }
        }
        return bestIndex
    }

    static func previewIndex(for originalIndex: Int, draggingFrom sourceIndex: Int?, targetIndex: Int?) -> Int {
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

// MARK: - Column Snapping Behavior

struct HubStripScrollTargetBehavior: ScrollTargetBehavior {
    var isDragging: Bool

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard !isDragging else { return }
        let stride = HubStripLayout.columnStride
        let maxScroll = max(0, context.contentSize.width - context.containerSize.width)
        let rawX = target.rect.origin.x
        let snapped = round(rawX / stride) * stride
        target.rect.origin.x = max(0, min(snapped, maxScroll))
    }
}
