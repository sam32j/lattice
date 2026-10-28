// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

struct LatticeHubHostedUtility: View {
    let item: LatticeHubItem
    let notchSize: CGSize?
    let onClose: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                switch item {
                case .homebrew:
                    PanelHomebrewView(onClose: onClose)
                case .media:
                    PanelMediaView(onClose: onClose)
                case .urlCleaner:
                    PanelURLCleanerView(onClose: onClose)
                case .uninstaller:
                    PanelUninstallerView(onClose: onClose)
                case .cleaner:
                    PanelCleanerView(onClose: onClose)
                case .windowLayout:
                    PanelWindowLayoutView(onClose: onClose)
                case .appUpdates:
                    PanelAppUpdatesView(onClose: onClose)
                case .portManager:
                    PanelPortManagerView(onClose: onClose)
                default:
                    EmptyView()
                }
            }
        }
        .frame(height: notchSize?.height ?? 470)
    }
}
