// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

enum UpdateSettingsLayoutTests {
    final class MarkerView: NSView {}
    struct Marker: NSViewRepresentable {
        let name: String
        func makeNSView(context: Context) -> MarkerView {
            let view = MarkerView()
            view.identifier = NSUserInterfaceItemIdentifier(name)
            return view
        }
        func updateNSView(_ view: MarkerView, context: Context) {}
    }

    static func run(_ expect: (Bool, String) -> Void) {
        MainActor.assumeIsolated {
            let content = UpdateSettingsStatusRow(
                status: HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill").frame(width: 20)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Update available: 9.9.9").font(.callout.weight(.medium))
                        Text("Last checked: Oct 18, 2026 at 1:02 PM").font(.caption)
                    }
                }.background(Marker(name: "status")),
                actions: HStack(spacing: 8) {
                    Button("Check for updates") {}
                    Button("Review update…") {}.buttonStyle(.borderedProminent)
                }.fixedSize(horizontal: true, vertical: false)
                    .background(Marker(name: "actions")))
            let host = NSHostingView(rootView: content.frame(width: 490, height: 100))
            let window = NSWindow(contentRect: NSRect(x: -10_000, y: -10_000, width: 490, height: 100),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            defer { window.close() }
            window.orderFront(nil)
            let deadline = Date().addingTimeInterval(0.2)
            while Date() < deadline {
                host.layoutSubtreeIfNeeded()
                RunLoop.current.run(until: Date().addingTimeInterval(0.01))
            }
            let markers = descendants(in: host)
            guard let status = markers.first(where: { $0.identifier?.rawValue == "status" }),
                  let actions = markers.first(where: { $0.identifier?.rawValue == "actions" }) else {
                expect(false, "update row renders both status and action group")
                return
            }
            let statusFrame = status.convert(status.bounds, to: host)
            let actionsFrame = actions.convert(actions.bounds, to: host)
            expect(abs(statusFrame.midY - actionsFrame.midY) < 2,
                   "update status and actions remain on one row at the reported settings width")
            expect(actionsFrame.minX >= statusFrame.maxX && actionsFrame.maxX <= 491,
                   "update actions remain beside the status without overflowing")
        }
    }

    private static func descendants(in view: NSView) -> [MarkerView] {
        (view as? MarkerView).map { [$0] } ?? view.subviews.flatMap { descendants(in: $0) }
    }
}
