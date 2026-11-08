// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Heights shared by the content and window. Optional sections and app rows
/// come from the same state that drives rendering.
enum SystemWidgetLayout {
    static let topInset: CGFloat = 6
    static let spacing: CGFloat = 12
    static let graphHeight: CGFloat = 76
    static let graphCaptionHeight: CGFloat = 14
    static let graphSpacing: CGFloat = 4
    static let factRowHeight: CGFloat = 42
    static let factRowSpacing: CGFloat = 10
    static let diskPickerHeight: CGFloat = 32
    static let processRowHeight: CGFloat = 24
    static let processHeaderHeight: CGFloat = 16
    static let processSpacing: CGFloat = 8
    static let processInset: CGFloat = 12
    static let speedButtonHeight: CGFloat = 42
    static let speedHeroHeight: CGFloat = 90
    static let speedGraphHeight: CGFloat = 85
    static let detailsButtonHeight: CGFloat = 24
    static let detailsRowHeight: CGFloat = 16
    static let detailsRowSpacing: CGFloat = 7
    static let detailsInset: CGFloat = 12
    static let detailsSpacing: CGFloat = 8

    static let summaryTileHeight: CGFloat = 120
    static let summarySpacing: CGFloat = 8
    static let summaryTopInset: CGFloat = 8
    static let summaryFooterHeight: CGFloat = 22
    static let summaryEmptyHeight: CGFloat = 100

    static func summaryHeight(tileCount: Int) -> CGFloat {
        guard tileCount > 0 else { return summaryEmptyHeight }
        let rows = (tileCount + 2) / 3
        return summaryTopInset + CGFloat(rows) * (summaryTileHeight + summarySpacing) + summaryFooterHeight
    }

    static func isEnergyMetric(_ kind: MetricDetailKind) -> Bool {
        kind == .battery || kind == .power
    }

    static func showsHeroTitle(_ kind: MetricDetailKind) -> Bool {
        kind == .cpu || kind == .gpu || kind == .memory || kind == .network || kind == .disk || isEnergyMetric(kind)
    }

    static func heroHeight(_ kind: MetricDetailKind) -> CGFloat {
        showsHeroTitle(kind) ? 96 : 76
    }

    static func factColumns(_ kind: MetricDetailKind) -> Int {
        kind == .memory ? 4 : 3
    }

    static func detailHeight(kind: MetricDetailKind, hasGraph: Bool, factCount: Int, detailsCount: Int,
                             hasDiskPicker: Bool, navigation: SystemNavigationState) -> CGFloat {
        if navigation.showingSpeedTest {
            return topInset + speedHeroHeight + speedGraphHeight + factRowHeight + speedButtonHeight + 3 * spacing
        }
        var height = topInset + heroHeight(kind)
        if hasDiskPicker { height += spacing + diskPickerHeight }
        if hasGraph { height += spacing + graphHeight + graphSpacing + graphCaptionHeight }
        if factCount > 0 {
            let columns = factColumns(kind)
            let rows = (factCount + columns - 1) / columns
            height += spacing + CGFloat(rows) * factRowHeight + CGFloat(rows - 1) * factRowSpacing
        }
        if kind.processKind != nil {
            height += spacing + processInset * 2 + processHeaderHeight + processSpacing
                + CGFloat(navigation.displayedProcessCount) * processRowHeight
        }
        if kind == .network { height += spacing + speedButtonHeight }
        if detailsCount > 0 {
            height += spacing + detailsButtonHeight
            if navigation.showMoreDetails {
                height += detailsSpacing + detailsInset * 2 + CGFloat(detailsCount) * detailsRowHeight
                    + CGFloat(detailsCount - 1) * detailsRowSpacing
            }
        }
        return height
    }
}
