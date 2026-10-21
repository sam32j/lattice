// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

extension RecorderQuickPreviewView {
    @ViewBuilder
    var contextMenuItems: some View {
        Button {
            onEdit()
        } label: {
            Label(screenshot.editButton, systemImage: "scissors")
        }
        .keyboardShortcut("e")
        .onAppear { onMenuChanged(true) }
        .onDisappear { onMenuChanged(false) }

        Divider()

        Button(text.quickLook) {
            onQuickLook()
        }
        .keyboardShortcut("y")

        Button(recorder.copyButton) {
            onCopy()
        }
        .keyboardShortcut("c")

        Button(recorder.saveButton) {
            onDownload()
        }
        .keyboardShortcut("s")

        Button(recorder.saveAsButton) {
            onSaveAs()
        }
        .keyboardShortcut("s", modifiers: [.command, .shift])

        Divider()

        Menu(l10n.s.shelfActionOpenWith) {
            ForEach(applicationsForMenu(), id: \.self) { app in
                Button {
                    openWith(app)
                } label: {
                    Label {
                        Text(FileManager.default.displayName(atPath: app.path))
                    } icon: {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.path))
                    }
                }
            }
        }

        Divider()

        Button(FeatureStrings.commandBar(l10n.language).actionRevealInFinder) {
            revealInFinder()
        }

        Divider()

        Button(screenshot.shareButton) {
            onShare()
        }

        Divider()

        Button(l10n.s.menuClose) {
            onClose()
        }
        .keyboardShortcut("w")
    }

}
