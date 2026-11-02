// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum AppUpdateUtilityLayoutTests {
    static func run(_ suite: TestSuite) {
        for preset in [NotchSize.compact, .spacious] {
            let geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1512, height: 982),
                                         safeAreaTop: 32, cameraWidth: 185, layout: preset)
            for height: CGFloat in [148, 215, 290] {
                let size = geometry.expandedSize(module: .hub, hubActiveUtilityHeight: height)
                suite.expectClose(geometry.contentSize(for: size).height, height,
                                  "hosted App Updates keeps its requested readable height in \(preset)")
            }
        }
    }
}
