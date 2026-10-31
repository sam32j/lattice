// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// A fixed active signal shared by the menu bar, Hub, and island.
enum KeepAwakeAppearance {
    static let symbol = "bolt.fill"
    static var color: NSColor { .systemOrange }
    static var indicatorColor: Color { Color(nsColor: color) }
}
