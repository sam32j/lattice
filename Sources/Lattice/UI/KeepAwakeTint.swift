// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

extension KeepAwakeIconTint {
    /// Match the native menu-bar indicator's colors on other surfaces.
    var indicatorColor: Color {
        switch self {
        case .orange: return Color(nsColor: .systemOrange)
        case .green: return Color(nsColor: .systemGreen)
        case .blue: return Color(nsColor: .systemBlue)
        case .purple: return Color(nsColor: .systemPurple)
        case .pink: return Color(nsColor: .systemPink)
        case .none: return .white
        }
    }
}
