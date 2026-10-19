// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Transparent inline editing uses the same measured lines as exported text.
struct ScreenshotInlineTextEditor: View {
    @ObservedObject var model: ScreenshotEditorModel
    @Binding var text: String
    let zoom: CGFloat

    var body: some View {
        if let id = model.editingTextID, let mark = model.annotations.first(where: { $0.id == id }) {
            let fontSize = max(1, ScreenshotRenderer.fontSize(for: mark.textSize, scale: model.scale) * zoom)
            let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
            let availableWidth = max(20, (model.imageSize.width - mark.rect.minX) * zoom)
            let wrapWidth = mark.isBounded ? max(20, mark.rect.width * zoom - 4 * zoom) : nil
            let measured = ScreenshotEditorGeometry.textSize(text, font: font, width: wrapWidth)
            let width = min(availableWidth, wrapWidth ?? max(40, measured.width + 4 * zoom))
            let height = max(measured.height + 4 * zoom, mark.isBounded ? mark.rect.height * zoom : 0)
            ScreenshotAnnotationTextEditor(text: $text, fontSize: fontSize,
                textColor: ScreenshotRenderer.nsColor(mark.color), isBounded: mark.isBounded,
                width: width, onCommit: { model.commitText(id, text: text) })
                .frame(width: width, height: height, alignment: .topLeading)
                .padding(.horizontal, 2 * zoom)
                .offset(x: (mark.rect.minX + model.backdropPaddingPixels) * zoom,
                        y: (mark.rect.minY + model.backdropPaddingPixels) * zoom)
                .onAppear { text = mark.text }
        }
    }
}
