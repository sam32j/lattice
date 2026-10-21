// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum ScreenshotWatermarkDraftTests {
    static func run(_ suite: TestSuite) {
        var draft = ScreenshotWatermarkDraft(.init())
        suite.expect(!draft.hasInput && draft.previewStyle.kind == .none && draft.style.kind == .text,
                     "empty watermark opens the text composer with disabled styles and actions")
        draft.style.text = "  Copyright  "
        suite.expect(draft.hasInput && draft.previewStyle.text == "Copyright",
                     "typing resolves a sanitized live text watermark without a Save action")
        draft.style.kind = .image
        suite.expect(!draft.hasInput && draft.previewStyle.kind == .none,
                     "text in the other tab does not enable an empty image watermark")
        draft.style.imagePath = "/tmp/logo.png"
        suite.expect(draft.hasInput && draft.previewStyle.kind == .image,
                     "an image selection previews immediately and enables the styles and Done")
        draft.reset()
        suite.expect(!draft.hasInput && draft.style.text.isEmpty && draft.style.imagePath == nil,
                     "Reset clears both input modes instead of retaining a hidden watermark")
    }
}
