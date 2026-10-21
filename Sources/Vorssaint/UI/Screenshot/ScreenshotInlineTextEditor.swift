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
            let height = mark.isBounded ? mark.rect.height * zoom : measured.height + 4 * zoom
            ScreenshotAnnotationTextEditor(text: $text, fontSize: fontSize,
                textColor: ScreenshotRenderer.nsColor(mark.color), isBounded: mark.isBounded,
                width: width, onCommit: { model.commitText(id, text: text) })
                .frame(width: width, height: height, alignment: .topLeading)
                .padding(.horizontal, 2 * zoom)
                .overlay {
                    Rectangle().strokeBorder(Color.accentColor,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])).allowsHitTesting(false)
                }
                .offset(x: (mark.rect.minX + model.backdropPaddingPixels) * zoom,
                        y: (mark.rect.minY + model.backdropPaddingPixels) * zoom)
                .onAppear { text = mark.text }
                .id(id)
        }
    }
}

struct ScreenshotAnnotationTextEditor: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let textColor: NSColor
    let isBounded: Bool
    let width: CGFloat
    let onCommit: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = EditorTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.string = text
        textView.isVerticallyResizable = true
        scrollView.documentView = textView
        configure(textView)
        DispatchQueue.main.async {
            guard textView.isEditable, !textView.isHidden, let window = textView.window else { return }
            window.makeFirstResponder(textView)
            if !textView.string.isEmpty {
                textView.selectAll(nil)
            }
        }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? EditorTextView else { return }
        let reopening = !textView.isEditable || textView.isHidden || nsView.isHidden
        // SwiftUI may reuse the same native view when an edit is reopened in
        // the same run-loop turn. Deactivation must not poison that new edit.
        nsView.isHidden = false
        textView.isHidden = false
        textView.isEditable = true
        textView.isSelectable = true
        context.coordinator.parent = self
        if textView.string != text {
            textView.string = text
        }
        configure(textView)
        if reopening {
            DispatchQueue.main.async {
                guard textView.isEditable, !textView.isHidden else { return }
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    private func configure(_ textView: EditorTextView) {
        textView.onCommit = onCommit
        textView.font = .systemFont(ofSize: fontSize, weight: .semibold)
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.isHorizontallyResizable = !isBounded
        textView.textContainer?.widthTracksTextView = false
        textView.setFrameSize(NSSize(width: width, height: textView.frame.height))
        textView.textContainer?.containerSize = NSSize(
            width: isBounded ? width : .greatestFiniteMagnitude,
            height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = isBounded
    }

    static func endEditing(in window: NSWindow?) {
        guard let textView = window?.firstResponder as? EditorTextView else { return }
        textView.deactivate()
        window?.makeFirstResponder(nil)
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        if let textView = nsView.documentView as? EditorTextView {
            textView.deactivate()
            textView.isolatedUndoManager.removeAllActions()
            textView.delegate = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ScreenshotAnnotationTextEditor

        init(_ parent: ScreenshotAnnotationTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

private final class EditorTextView: NSTextView {
    var onCommit: (() -> Void)?
    let isolatedUndoManager = UndoManager()

    override var acceptsFirstResponder: Bool { isEditable && !isHidden }
    override func hitTest(_ point: NSPoint) -> NSView? {
        isEditable && !isHidden ? super.hitTest(point) : nil
    }

    func deactivate() {
        let owner = window
        let scroll = enclosingScrollView
        isEditable = false
        isSelectable = false
        discardCursorRects()
        scroll?.discardCursorRects()
        if owner?.firstResponder === self { owner?.makeFirstResponder(nil) }
        isHidden = true
        scroll?.isHidden = true
        if let content = owner?.contentView { owner?.invalidateCursorRects(for: content) }
        onCommit = nil
        if owner?.isKeyWindow == true { NSCursor.arrow.set() }
    }

    private func commitEditing() {
        let commit = onCommit
        deactivate()
        commit?()
    }
    override var undoManager: UndoManager? { isolatedUndoManager }

    deinit {
        isolatedUndoManager.removeAllActions()
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if event.keyCode == 36 || event.keyCode == 76 { // Return / Enter
            if flags.contains(.command) {
                commitEditing()
                return
            }
            insertNewline(nil)
            return
        }
        if event.keyCode == 53 { // Esc
            commitEditing()
            return
        }
        super.keyDown(with: event)
    }

}
