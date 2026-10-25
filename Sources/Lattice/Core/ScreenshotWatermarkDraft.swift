// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Keeps both input modes while the sanitized active mode previews live.
struct ScreenshotWatermarkDraft {
    var style: ScreenshotSupport.WatermarkStyle

    init(_ initial: ScreenshotSupport.WatermarkStyle) {
        let initial = initial.sanitized()
        style = initial.kind == .none ? .init(kind: .text) : initial
    }

    var previewStyle: ScreenshotSupport.WatermarkStyle { style.sanitized() }
    var hasInput: Bool { previewStyle.kind != .none }

    mutating func reset() { style = .init(kind: .text) }
}
