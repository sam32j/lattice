import Foundation

extension SettingsSearchSupport {
    static func screenCaptureKeywords(_ strings: Strings,
                                       language: AppLanguage) -> [String] {
        screenCaptureFeatureKeywords(strings, language: language).flatMap(\.titles)
    }

    static func screenCaptureFeatureKeywords(_ strings: Strings,
                                              language: AppLanguage)
        -> [(feature: AppFeature, titles: [String])] {
        let screenshot = FeatureStrings.screenshot(language)
        let recorder = FeatureStrings.recorder(language)
        return [
            (.screenshot, [screenshot.pageTitle, screenshot.freezeToggle,
                           screenshot.highlightWindowsToggle, screenshot.highlightWindowsCaption,
                           screenshot.loupeStartsOnToggle,
                           screenshot.fullScreenShortcutTitle, screenshot.previewPositionLabel,
                           screenshot.previewFocusToggle, screenshot.confirmationPreviewToggle,
                           screenshot.confirmationPreviewDurationLabel,
                           screenshot.pinButton, screenshot.toolPixelate, screenshot.toolBlur,
                           screenshot.toolArrow, screenshot.addToShelfToggle]),
            (.screenRecorder, [recorder.pageTitle, recorder.startButton,
                               screenshot.previewPositionLabel,
                               recorder.systemAudioToggle, recorder.microphoneToggle,
                               recorder.qualityLabel, recorder.frameRateLabel]),
        ]
    }

    /// Keeps only the sections that still have items for the query, so an
    /// empty section never renders just its header.
    static func filteredIndices(query: String,
                                sections: [[String]]) -> [[Int]] {
        sections.map { titles in
            titles.indices.filter { matches(query: query, title: titles[$0]) }
        }
    }

    static func fold(_ value: String) -> String {
        // No locale: Turkish folds a dotted I to a dotless one, which would
        // make this page search answer differently there.
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func matchRank(foldedQuery: String,
                                   title: String,
                                   keywords: [String]) -> MatchRank? {
        let foldedTitle = fold(title)
        if foldedTitle == foldedQuery { return .exactTitle }
        if foldedTitle.contains(foldedQuery) { return .title }
        if keywords.contains(where: { fold($0).contains(foldedQuery) }) { return .keyword }
        return nil
    }

    /// Returns the next selection index with deterministic wrapping.
    static func moveSelection(index: Int?, delta: Int, count: Int) -> Int? {
        guard count > 0 else { return nil }
        let current = clampedSelection(index: index, count: count)
            ?? (delta >= 0 ? count - 1 : 0)
        let remainder = (current + delta % count) % count
        return remainder >= 0 ? remainder : remainder + count
    }

    static func clampedSelection(index: Int?, count: Int) -> Int? {
        guard count > 0, let index else { return nil }
        return min(max(index, 0), count - 1)
    }

    /// Keeps the same result selected if it moved, otherwise clamps its old
    /// position to the new result count.
    static func reconciledSelection<ID: Equatable>(index: Int?,
                                                    previousIDs: [ID],
                                                    resultIDs: [ID]) -> Int? {
        guard !resultIDs.isEmpty else { return nil }
        guard let index else { return 0 }
        if previousIDs.indices.contains(index),
           let movedIndex = resultIDs.firstIndex(of: previousIDs[index]) {
            return movedIndex
        }
        return clampedSelection(index: index, count: resultIDs.count)
    }
}

/// Fixed-width Settings geometry with independently restorable height.
enum SettingsWindowSupport {
    /// Width is locked; only height can grow from its minimum.
    static let minContentWidth: Double = 772
    static let minContentHeight: Double = 528
    /// Tall default so every sidebar entry is visible on regular screens.
    static let preferredContentHeight: Double = 838

    static func isValidContentSize(width: Double, height: Double) -> Bool {
        width == minContentWidth && height >= minContentHeight
    }

    /// A saved size wins when it is at least the minimum (0 means unset);
    /// otherwise the tall default, capped to the screen's available height.
    static func initialContentSize(savedHeight: Double,
                                   availableHeight: Double) -> (width: Double, height: Double) {
        if savedHeight.isFinite && savedHeight >= minContentHeight {
            return (minContentWidth, savedHeight)
        }
        let height = min(preferredContentHeight, max(availableHeight, minContentHeight))
        return (minContentWidth, height)
    }


    static func panelPlacement(preferredFrame: CGRect,
                               panelFrame: CGRect,
                               visibleFrame: CGRect) -> (frame: CGRect, closesPanel: Bool) {
        let avoidedFrame = frame(preferredFrame, avoiding: panelFrame, in: visibleFrame)
        let closesPanel = avoidedFrame.intersects(panelFrame)
        return (closesPanel ? clamped(preferredFrame, to: visibleFrame) : avoidedFrame,
                closesPanel)
    }

    private static func frame(_ frame: CGRect, avoiding panelFrame: CGRect,
                              in visibleFrame: CGRect) -> CGRect {
        let gap: CGFloat = 28
        let margin: CGFloat = 20
        var adjusted = frame

        let leftX = panelFrame.minX - gap - frame.width
        let rightX = panelFrame.maxX + gap
        if panelFrame.midX >= visibleFrame.midX, leftX >= visibleFrame.minX + margin {
            adjusted.origin.x = min(frame.origin.x, leftX)
        } else if panelFrame.midX < visibleFrame.midX,
                  rightX + frame.width <= visibleFrame.maxX - margin {
            adjusted.origin.x = max(frame.origin.x, rightX)
        } else {
            let belowY = panelFrame.minY - gap - frame.height
            let aboveY = panelFrame.maxY + gap
            if belowY >= visibleFrame.minY + margin {
                adjusted.origin.y = min(frame.origin.y, belowY)
            } else if aboveY + frame.height <= visibleFrame.maxY - margin {
                adjusted.origin.y = max(frame.origin.y, aboveY)
            }
        }

        return clamped(adjusted, to: visibleFrame)
    }

    private static func clamped(_ frame: CGRect, to visibleFrame: CGRect) -> CGRect {
        let margin: CGFloat = 20
        var clamped = frame
        clamped.origin.x = min(max(clamped.origin.x, visibleFrame.minX + margin),
                               visibleFrame.maxX - frame.width - margin)
        clamped.origin.y = min(max(clamped.origin.y, visibleFrame.minY + margin),
                               visibleFrame.maxY - frame.height - margin)
        return clamped
    }
}
