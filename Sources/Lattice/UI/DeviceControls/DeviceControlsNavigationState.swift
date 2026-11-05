// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation
import Combine

/// Session-scoped navigation and filter state for Device Controls and App Volumes.
final class DeviceControlsNavigationState: ObservableObject {
    static let shared = DeviceControlsNavigationState()

    enum Subpage: Equatable {
        case main
        case appVolumes
    }

    @Published var currentSubpage: Subpage = .main
    /// Measured content height of the active Device Controls subpage to fit perfectly in the Dynamic Island.
    @Published var contentHeight: CGFloat = 430
    /// Inactive applications are hidden by default on a fresh session.
    /// Preserved while navigating between Device Controls and App Volumes in the same session.
    @Published var showInactiveApps: Bool = false

    func resetSubpage() {
        currentSubpage = .main
    }
}
