// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

/// Synthetic views only. No feature runtime, capture or system registration.
enum CaptureEditorFollowupProbe {
    static func run(in directory: URL) -> [String] {
        var failures: [String] = []
        func render(_ name: String, content: AnyView, size: CGSize) {
            let host = NSHostingView(rootView: content.frame(width: size.width, height: size.height))
            host.frame = CGRect(origin: .zero, size: size)
            let window = NSWindow(contentRect: CGRect(origin: CGPoint(x: -10000, y: -10000), size: size),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderFront(nil)
            defer { window.contentView = nil; window.close() }
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.15))
            guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                failures.append("no image for \(name)"); return
            }
            host.cacheDisplay(in: host.bounds, to: bitmap)
            do {
                guard let png = bitmap.representation(using: .png, properties: [:]) else {
                    failures.append("no PNG for \(name)"); return
                }
                try png.write(to: directory.appendingPathComponent(name + ".png"))
            } catch { failures.append("cannot render \(name): \(error)") }
        }
        for compact in [false, true] {
            render(compact ? "editor-drop-compact" : "editor-drop-targets",
                   content: AnyView(NotchMediaDropTargets(canDropOnShelf: !compact,
                       optimizationDropAvailable: !compact, editorDropAvailable: true, optimizationAvailable: true,
                       targetsMediaDrop: false, targetsEditorDrop: true)
                       .padding(16).foregroundStyle(.white).background(.black).environment(\.colorScheme, .dark)),
                   size: compact ? CGSize(width: 360, height: 160) : CGSize(width: 520, height: 260))
        }
        return failures
    }
}
#endif
