// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Own the popover so its native file chooser can temporarily suspend only
/// automatic click-away dismissal, without recreating the user's draft.
struct ScreenshotWatermarkToolAnchor: NSViewRepresentable {
    final class Presenter: NSObject, ObservableObject, NSPopoverDelegate {
        fileprivate weak var anchor: NSView?
        private var popover: NSPopover?
        private var choosingImage = false

        func toggle(model: ScreenshotEditorModel) {
            guard !choosingImage else { return }
            if popover?.isShown == true { close(); return }
            guard let anchor, anchor.window != nil else { return }
            let popover = NSPopover()
            popover.behavior = .transient
            popover.delegate = self
            let content = NSHostingController(rootView:
                ScreenshotWatermarkPopover(model: model,
                    close: { [weak self] in self?.close() },
                    fileSelectionChanged: { [weak self] in self?.setChoosingImage($0) }))
            content.sizingOptions = [.preferredContentSize]
            popover.contentViewController = content
            self.popover = popover
            popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minX)
        }

        private func setChoosingImage(_ choosing: Bool) {
            choosingImage = choosing
            popover?.behavior = choosing ? .applicationDefined : .transient
        }

        private func close() { popover?.performClose(nil) }

        func popoverShouldClose(_ popover: NSPopover) -> Bool { !choosingImage }

        func popoverDidClose(_ notification: Notification) {
            popover = nil
            choosingImage = false
        }

        deinit { popover?.close() }
    }

    let presenter: Presenter

    func makeNSView(context: Context) -> AnchorView {
        let view = AnchorView()
        presenter.anchor = view
        return view
    }

    func updateNSView(_ view: AnchorView, context: Context) { presenter.anchor = view }

    final class AnchorView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
