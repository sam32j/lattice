// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

struct LatticeHubHostedUtility: View {
    let item: LatticeHubItem
    let notchSize: CGSize?
    let onClose: () -> Void

    private var fallbackHeight: CGFloat {
        switch item {
        case .appUpdates:
            return AppUpdatesListView.compactUtilityHeight(itemCount: AppUpdatesService.shared.items.count)
        case .videoDownloader:
            return 172
        default:
            return 470
        }
    }

    var body: some View {
        if item == .recentCaptures {
            RecentCapturesView(onClose: onClose, notchSize: notchSize)
                .frame(height: notchSize?.height)
        } else {
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
                    case .killProcess:
                        KillProcessView(inlineOptions: true)
                    case .wallpaper:
                        WallpaperSection(collapsible: false, onClose: onClose)
                    case .videoDownloader:
                        NotchVideoDownloaderView(size: CGSize(width: notchSize?.width ?? 420, height: notchSize?.height ?? 470))
                    default:
                        EmptyView()
                    }
                }
            }
            .frame(height: notchSize?.height ?? fallbackHeight)
        }
    }
}
