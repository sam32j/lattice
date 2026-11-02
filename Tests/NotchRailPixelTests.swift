// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

enum NotchRailPixelTests {
    static func run(_ suite: TestSuite) {
        for scale: CGFloat in [1, 2] {
            let state = NotchCompactTests.RailState()
            state.count = 5
            state.rows = 2
            let host = NSHostingView(rootView: NotchCompactTests.Rail(state: state)
                .environment(\.displayScale, scale))
            let window = NSWindow(contentRect: NSRect(x: -10000, y: -10000, width: 424, height: 152),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            host.frame = NSRect(x: 0, y: 0, width: 424, height: 152)
            NotchCompactTests.settle(host)
            let frames = (0..<5).compactMap { id in
                NotchCompactTests.descendants(host).first { $0.identifier?.rawValue == "rail-\(id)" }
                    .map { $0.convert($0.bounds, to: host) }
            }
            // The 424pt rail caps cells at 78.4pt (five columns with 8pt gaps).
            // Native view edges quantize independently to physical pixels.
            let pixel = 1 / scale
            suite.expect(frames.count == 5 && frames.allSatisfy { abs($0.width - 78.4) <= pixel + 0.001 },
                         "1x and 2x rail cells remain within one physical pixel of their logical width: \(frames)")
            if frames.count == 5 {
                suite.expect(abs((frames[3].minX + frames[4].maxX) / 2 - 212) <= pixel / 2 + 0.001,
                             "the short row remains centered at each display scale")
            }
            window.contentView = nil
        }
    }
}
