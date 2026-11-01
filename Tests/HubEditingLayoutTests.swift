// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation
import CoreGraphics

enum HubEditingLayoutTests {
    static func run(_ suite: TestSuite) {
        let geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1440, height: 900),
                                     safeAreaTop: 32, cameraWidth: 210)
        let normal = geometry.contentSize(for: geometry.expandedSize(
            module: .hub, toolCount: 11, toolsControlsHeight: 66))
        let editing = geometry.contentSize(for: geometry.expandedSize(
            module: .hub, toolCount: 11, toolsControlsHeight: 66,
            hubIsEditing: true, hubAvailableCount: 1))
        suite.expect(abs(editing.height - normal.height - 60) < 0.5,
                     "editing preserves the display rail and adds only the 60-point Available Tools strip")
        let crowded = geometry.contentSize(for: geometry.expandedSize(
            module: .hub, toolCount: 11, toolsControlsHeight: 66,
            hubIsEditing: true, hubAvailableCount: 40))
        suite.expect(crowded == editing, "hidden tools scroll in a bounded strip instead of growing or clipping the editor")
        suite.expect(NotchLayout.toolRailRows(count: 8, width: 900, height: 320) == 2,
                     "eight apps use two rows even when all eight could fit across")
        let empty = geometry.contentSize(for: geometry.expandedSize(
            module: .hub, toolCount: 0, toolsControlsHeight: 0))
        suite.expect(empty.height >= 160, "an all-hidden hub reserves room for its complete empty state and action")

        // Hub Strip Layout & Drag Reordering Tests

        // 1. Row counts: <= 5 is 1 row, >= 6 is 2 rows, never more than 2
        suite.expect(HubStripLayout.rows(for: 1) == 1, "1 item has 1 row")
        suite.expect(HubStripLayout.rows(for: 5) == 1, "5 items have 1 row")
        suite.expect(HubStripLayout.rows(for: 6) == 2, "6 items have 2 rows")
        suite.expect(HubStripLayout.rows(for: 20) == 2, "20 items have 2 rows")
        suite.expect(HubStripLayout.rows(for: 1000) == 2, "never more than 2 rows")

        // 2. Reading order: Row 0 left-to-right (0..4), Row 1 left-to-right (5..9), next page Row 0 (10..14), Row 1 (15..19)
        for i in 0..<5 {
            let pos = HubStripLayout.gridPosition(for: i, totalRows: 2)
            suite.expect(pos.row == 0 && pos.col == i && pos.page == 0, "item \(i) is in page 0, row 0, col \(i)")
        }
        for i in 5..<10 {
            let pos = HubStripLayout.gridPosition(for: i, totalRows: 2)
            suite.expect(pos.row == 1 && pos.col == i - 5 && pos.page == 0, "item \(i) is in page 0, row 1, col \(i - 5)")
        }
        for i in 10..<15 {
            let pos = HubStripLayout.gridPosition(for: i, totalRows: 2)
            suite.expect(pos.row == 0 && pos.col == i - 10 + 5 && pos.page == 1, "item \(i) is in page 1, row 0, col \(i - 10 + 5)")
        }
        for i in 15..<20 {
            let pos = HubStripLayout.gridPosition(for: i, totalRows: 2)
            suite.expect(pos.row == 1 && pos.col == i - 15 + 5 && pos.page == 1, "item \(i) is in page 1, row 1, col \(i - 15 + 5)")
        }

        // 3. Fixed mathematical rule: total count never changes where an existing item sits
        let posAt6 = HubStripLayout.gridPosition(for: 5, totalRows: HubStripLayout.rows(for: 6))
        let posAt20 = HubStripLayout.gridPosition(for: 5, totalRows: HubStripLayout.rows(for: 20))
        let posAt100 = HubStripLayout.gridPosition(for: 5, totalRows: HubStripLayout.rows(for: 100))
        suite.expect(posAt6 == posAt20 && posAt20 == posAt100, "total count never changes where existing item sits")

        // 4. Columns count
        suite.expect(HubStripLayout.totalColumns(count: 5) == 5, "5 items use 5 columns")
        suite.expect(HubStripLayout.totalColumns(count: 6) == 5, "6 items use 5 columns")
        suite.expect(HubStripLayout.totalColumns(count: 10) == 5, "10 items use 5 columns")
        suite.expect(HubStripLayout.totalColumns(count: 11) == 6, "11 items use 6 columns")
        suite.expect(HubStripLayout.totalColumns(count: 16) == 10, "16 items use 10 columns")

        // 5. Drag reorder live preview rule:
        // Dragging 12 to 3 pushes items 3..11 forward by one, item 12 takes 3, others untouched
        for k in 0..<3 {
            suite.expect(HubStripLayout.previewIndex(for: k, draggingFrom: 12, targetIndex: 3) == k, "item \(k) untouched")
        }
        suite.expect(HubStripLayout.previewIndex(for: 12, draggingFrom: 12, targetIndex: 3) == 3, "dragged item 12 takes slot 3")
        for k in 3...11 {
            suite.expect(HubStripLayout.previewIndex(for: k, draggingFrom: 12, targetIndex: 3) == k + 1, "item \(k) pushed forward to \(k + 1)")
        }
        // Specifically, item 9 (end of row 2 on page 0) moves to index 10 (start of row 1 on page 1)
        let item9NewIndex = HubStripLayout.previewIndex(for: 9, draggingFrom: 12, targetIndex: 3)
        let item9NewPos = HubStripLayout.gridPosition(for: item9NewIndex, totalRows: 2)
        suite.expect(item9NewPos.page == 1 && item9NewPos.row == 0 && item9NewPos.col == 5, "item 9 moves to page 1, row 0, col 5")
        for k in 13...20 {
            suite.expect(HubStripLayout.previewIndex(for: k, draggingFrom: 12, targetIndex: 3) == k, "item \(k) untouched")
        }

        // Dragging 3 to 7: items 4..7 shift back by one, item 3 takes 7, others untouched
        suite.expect(HubStripLayout.previewIndex(for: 3, draggingFrom: 3, targetIndex: 7) == 7, "dragged item 3 takes slot 7")
        for k in 4...7 {
            suite.expect(HubStripLayout.previewIndex(for: k, draggingFrom: 3, targetIndex: 7) == k - 1, "item \(k) shifts back to \(k - 1)")
        }
        suite.expect(HubStripLayout.previewIndex(for: 2, draggingFrom: 3, targetIndex: 7) == 2, "item 2 untouched")
        suite.expect(HubStripLayout.previewIndex(for: 8, draggingFrom: 3, targetIndex: 7) == 8, "item 8 untouched")

        // 6. Closest index search: Euclidean nearest slot center across rows and pages
        let center0 = HubStripLayout.slotCenter(for: 0, totalRows: 2)
        suite.expect(HubToolLayout.island(count: 20).closestIndex(to: center0) == 0, "center of slot 0 maps to index 0")
        let center5 = HubStripLayout.slotCenter(for: 5, totalRows: 2)
        suite.expect(HubToolLayout.island(count: 20).closestIndex(to: center5) == 5, "center of slot 5 maps to index 5 (row 2 col 0)")
        let center10 = HubStripLayout.slotCenter(for: 10, totalRows: 2)
        suite.expect(HubToolLayout.island(count: 20).closestIndex(to: center10) == 10, "center of slot 10 maps to index 10 (page 1 row 0)")
        let center19 = HubStripLayout.slotCenter(for: 19, totalRows: 2)
        suite.expect(HubToolLayout.island(count: 20).closestIndex(to: center19) == 19, "center of slot 19 maps to index 19 (page 1 row 1 col 4)")
        suite.expect(HubToolLayout.island(count: 20).closestIndex(to: CGPoint(x: -10000, y: 0)) == 0,
                     "dragging past the first edge safely targets the first slot")
        suite.expect(HubToolLayout.island(count: 20).closestIndex(to: CGPoint(x: 10000, y: 0)) == 14,
                     "dragging past the last edge safely targets the last top-row slot")

        // 7. Column stride & Snapping
        suite.expect(HubStripLayout.columnStride == 82, "column stride is 76 + 6 = 82")
        suite.expect(HubStripLayout.rowStride == 78, "row stride is 72 + 6 = 78")

        let hud = HubToolLayout.hud(count: 8, width: 380)
        suite.expect(hud.frames[7] == CGRect(x: 130, y: 148, width: 120, height: 64),
                     "HUD keeps three columns, 64-point tiles and ten-point gaps")
        suite.expect(hud.size == CGSize(width: 380, height: 212), "HUD reserves its complete three-row grid")
        for x in [CGFloat(254), 256, 254, 256] {
            suite.expect(hud.closestIndex(to: CGPoint(x: x, y: 32), keeping: 1) == 1,
                         "pointer noise across a slot midpoint does not reverse the preview")
        }
        suite.expect(hud.closestIndex(to: CGPoint(x: 262, y: 32), keeping: 1) == 2,
                     "a deliberate move past the deadband changes the destination")
        suite.expect(hud.closestIndex(to: CGPoint(x: 254, y: 32), keeping: 2) == 2,
                     "the same deadband applies when moving back")
        suite.expect(hud.closestIndex(to: CGPoint(x: 248, y: 32), keeping: 2) == 1,
                     "deliberately crossing back restores the previous destination")
        suite.expect(hud.closestIndex(to: CGPoint(x: 220, y: 32), keeping: 7) == 1,
                     "the right half of HUD slot two targets slot two")
        suite.expect((0..<8).map { HubStripLayout.previewIndex(for: $0, draggingFrom: 7, targetIndex: 1) }
                     == [0, 2, 3, 4, 5, 6, 7, 1], "moving tool eight to slot two shifts every intervening tool")
    }
}
