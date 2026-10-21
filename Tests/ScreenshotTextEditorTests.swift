// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

enum ScreenshotTextEditorTests {
    private static func textView(in view: NSView) -> NSTextView? {
        if let text = view as? NSTextView { return text }
        return view.subviews.lazy.compactMap { textView(in: $0) }.first
    }

    private static func settle(_ host: NSView) {
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        host.layoutSubtreeIfNeeded()
    }

    static func run(_ suite: TestSuite) {
        _ = NSApplication.shared
        var firstText = "first"
        var nextText = "next"
        var firstCommits = 0
        var nextCommits = 0
        let first = ScreenshotAnnotationTextEditor(
            text: Binding(get: { firstText }, set: { firstText = $0 }),
            fontSize: 12, textColor: .black, isBounded: true, width: 120,
            onCommit: { firstCommits += 1 })
        let host = NSHostingView(rootView: first.frame(width: 120, height: 80))
        host.frame = NSRect(x: 0, y: 0, width: 200, height: 100)
        let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 200, height: 100),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.contentView = nil; window.close() }
        settle(host)
        guard let original = textView(in: host) else {
            suite.expect(false, "annotation editor creates a native text view")
            return
        }
        suite.expect(original.textContainer?.lineFragmentPadding == 0 && original.textContainerInset == .zero,
                     "native annotation editing has the same zero padding as measured text")
        let sample = "MMMMM"
        let font = original.font!
        let boundaryWidth = (sample as NSString).size(withAttributes: [.font: font]).width + 1
        original.string = sample
        original.setFrameSize(CGSize(width: boundaryWidth, height: 80))
        original.textContainer?.containerSize = CGSize(width: boundaryWidth, height: 1000)
        if let container = original.textContainer, let manager = original.layoutManager {
            manager.ensureLayout(for: container)
            suite.expectClose(ceil(manager.usedRect(for: container).height),
                ScreenshotEditorGeometry.textSize(sample, font: font, width: boundaryWidth).height,
                "native wrapping agrees with shared measurement at the line boundary")
        }
        host.rootView = ScreenshotAnnotationTextEditor(
            text: Binding(get: { nextText }, set: { nextText = $0 }),
            fontSize: 18, textColor: .red, isBounded: false, width: 180,
            onCommit: { nextCommits += 1 }).frame(width: 180, height: 80)
        settle(host)
        guard let updated = textView(in: host) else {
            suite.expect(false, "annotation editor survives an input update")
            return
        }
        suite.expect(updated === original && updated.string == "next",
                     "SwiftUI reuses the native text view while updating the selected annotation")
        updated.string = "edited next"
        updated.didChangeText()
        suite.expect(firstText == "first" && nextText == "edited next",
                     "native typing updates the current annotation binding instead of the previous one")
        if let modifiers = NSEvent.keyEvent(with: .flagsChanged, location: .zero,
                                           modifierFlags: [.command, .shift], timestamp: 0,
                                           windowNumber: window.windowNumber, context: nil,
                                           characters: "", charactersIgnoringModifiers: "",
                                           isARepeat: false, keyCode: 56) {
            updated.flagsChanged(with: modifiers)
        }
        suite.expect(firstCommits == 0 && nextCommits == 0,
                     "holding Command and Shift keeps the annotation open for editing shortcuts")
        if let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                        timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                        characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                                        isARepeat: false, keyCode: 53) {
            updated.keyDown(with: escape)
        }
        suite.expect(firstCommits == 0 && nextCommits == 1,
                     "committing a reused editor invokes the current annotation callback")
        suite.expect(updated.isHorizontallyResizable
                     && updated.textContainer?.widthTracksTextView == false
                     && (updated.textContainer?.containerSize.width ?? 0) > 1_000_000,
                     "switching to unbounded text refreshes native wrapping configuration")
        updated.setSelectedRange(NSRange(location: 2, length: 3))
        host.rootView = ScreenshotAnnotationTextEditor(
            text: Binding(get: { nextText }, set: { nextText = $0 }),
            fontSize: 18, textColor: .red, isBounded: true, width: 80,
            onCommit: { nextCommits += 1 }).frame(width: 80, height: 80)
        settle(host)
        suite.expect(updated.isEditable && updated.isSelectable && !updated.isHidden
                     && updated.enclosingScrollView?.isHidden == false,
                     "rapidly reopening a committed native editor restores its visible editable surface")
        suite.expect(!updated.isHorizontallyResizable
                     && updated.textContainer?.widthTracksTextView == true
                     && abs((updated.textContainer?.containerSize.width ?? 0) - 80) < 1,
                     "returning to bounded text applies the current wrapping width")
        suite.expect(updated.selectedRange() == NSRange(location: 2, length: 3),
                     "updating an unchanged text value preserves its native selection")
        suite.expect(updated.frame.height > 0 && updated.visibleRect.height > 0,
                     "a reopened text editor immediately has a visible drawing and caret surface")
        if let scrollView = updated.enclosingScrollView {
            window.makeFirstResponder(updated)
            ScreenshotAnnotationTextEditor.dismantleNSView(scrollView, coordinator: first.makeCoordinator())
            suite.expect(window.firstResponder !== updated && !updated.isEditable && scrollView.isHidden
                         && updated.hitTest(CGPoint(x: 5, y: 5)) == nil,
                         "ending text editing immediately releases focus and disables the native hit and cursor surface")
        } else { suite.expect(false, "native editing retains its scroll wrapper until teardown") }
        ScreenshotFontTextEditingTests.run(suite)
        ScreenshotCanvasInputTests.run(suite)
    }
}
