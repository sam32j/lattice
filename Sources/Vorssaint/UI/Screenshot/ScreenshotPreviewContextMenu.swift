// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

enum ScreenshotPreviewMenuAction: CaseIterable {
    case edit, pin, extractText, rotateLeft, flipHorizontal, quickLook, printImage, saveAs, mail, reveal, share, discard, close
}

/// Native menu grouping, shared by the floating and Dynamic Island previews.
struct ScreenshotPreviewContextMenu: View {
    let perform: @MainActor (ScreenshotPreviewMenuAction) -> Void
    let applications: () -> [URL]
    let openWith: (URL) -> Void
    let canReveal: Bool
    let opened: () -> Void
    let closed: () -> Void
    @State private var apps: [URL] = []
    @ObservedObject private var l10n = L10n.shared
    private var text: ScreenshotEditorRefinementStrings { FeatureStrings.editorRefinements(l10n.language) }
    private var screenshot: ScreenshotFeatureStrings { FeatureStrings.screenshot(l10n.language) }

    var body: some View {
        Button(screenshot.editButton) { perform(.edit) }.keyboardShortcut("e")
            .onAppear { opened(); apps = applications() }.onDisappear(perform: closed)
        Button(screenshot.pinButton) { perform(.pin) }
        Button(screenshot.copyTextButton) { perform(.extractText) }.disabled(!AppFeature.screenOCR.isAvailable)
        Divider()
        Button(text.rotateLeft) { perform(.rotateLeft) }
        Button(text.flipHorizontal) { perform(.flipHorizontal) }
        Divider()
        Button(text.quickLook) { perform(.quickLook) }.keyboardShortcut("y")
        Button(text.printImage) { perform(.printImage) }.keyboardShortcut("p")
        Button(screenshot.saveAsButton) { perform(.saveAs) }.keyboardShortcut("s", modifiers: [.command, .shift])
        Divider()
        Menu(l10n.s.shelfActionOpenWith) {
            ForEach(apps, id: \.self) { app in
                Button { openWith(app) } label: {
                    Label {
                        Text(FileManager.default.displayName(atPath: app.path))
                    } icon: {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                    }
                }
            }
        }
        Button(text.openInMail) { perform(.mail) }
        Divider()
        Button(screenshot.discardConfirm, role: .destructive) { perform(.discard) }
        Button(FeatureStrings.commandBar(l10n.language).actionRevealInFinder) { perform(.reveal) }
        Divider()
        Button(screenshot.shareButton) { perform(.share) }
        Divider()
        Button(l10n.s.menuClose) { perform(.close) }.keyboardShortcut("w")
    }
}
