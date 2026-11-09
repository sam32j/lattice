// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

struct LatticeHubHostedUtility: View {
    let item: LatticeHubItem
    let notchSize: CGSize?
    let onClose: () -> Void
    @ObservedObject private var launcher = LatticeHubService.shared

    private var viewportHeight: CGFloat {
        // Floating panels can be moved upward; only content taller than the
        // available display needs its own scroll viewport.
        guard let notchSize else {
            return min(fallbackHeight, max(100, launcher.floatingPanelHeightBudget - 92))
        }
        return notchSize.height
    }

    private var fallbackHeight: CGFloat {
        switch item {
        case .appUpdates:
            return AppUpdatesListView.compactUtilityHeight(itemCount: AppUpdatesService.shared.items.count)
        case .videoDownloader:
            return 172
        case .deviceControls:
            return DeviceControlsNavigationState.shared.contentHeight
        default:
            return 470
        }
    }

    var body: some View {
        if item == .recentCaptures {
            RecentCapturesView(onClose: onClose, showHeader: false, notchSize: notchSize)
                .frame(height: viewportHeight)
        } else if item == .deviceControls {
            DeviceControlsHubView(onClose: onClose)
                .frame(height: viewportHeight)
        } else if item == .system {
            LatticeHubSystemUtility(notchSize: notchSize)
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    switch item {
                    case .homebrew:
                        PanelHomebrewView(showHeader: false, onClose: onClose)
                    case .media:
                        PanelMediaView(showHeader: false, onClose: onClose)
                    case .urlCleaner:
                        PanelURLCleanerView(showHeader: false, onClose: onClose)
                    case .uninstaller:
                        PanelUninstallerView(showHeader: false, onClose: onClose)
                    case .cleaner:
                        PanelCleanerView(showHeader: false, onClose: onClose)
                    case .windowLayout:
                        PanelWindowLayoutView(showHeader: false, onClose: onClose)
                    case .appUpdates:
                        PanelAppUpdatesView(showHeader: false, onClose: onClose)
                    case .portManager:
                        PanelPortManagerView(showHeader: false, onClose: onClose)
                    case .killProcess:
                        KillProcessView(inlineOptions: true)
                    case .wallpaper:
                        WallpaperSection(collapsible: false, showHeader: false, onClose: onClose)
                    case .videoDownloader:
                        NotchVideoDownloaderView(size: CGSize(width: notchSize?.width ?? 388, height: notchSize?.height ?? 470))
                    default:
                        EmptyView()
                    }
                }
            }
            .frame(height: viewportHeight)
        }
    }
}

private struct LatticeHubSystemUtility: View {
    let notchSize: CGSize?
    @ObservedObject private var navigation = SystemNavigationState.shared
    @ObservedObject private var launcher = LatticeHubService.shared
    @State private var floatingDetailNaturalHeight: CGFloat = 470

    var body: some View {
        if let notchSize, navigation.selectedMetric != .cpu {
            ScrollView {
                content
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: notchSize.height)
        } else if notchSize == nil, navigation.selectedMetric != nil,
                  navigation.selectedMetric != .cpu {
            // Keep the natural detail height when it fits. Only oversized
            // floating details get a bounded scroll viewport.
            ScrollView {
                content
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                        if height > 0, abs(floatingDetailNaturalHeight - height) > 0.5 {
                            floatingDetailNaturalHeight = height
                        }
                    }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: min(floatingDetailNaturalHeight,
                               max(100, launcher.floatingPanelHeightBudget - 92)))
        } else {
            content
                .frame(height: notchSize?.height, alignment: .top)
        }
    }

    @ViewBuilder private var content: some View {
        if let metric = navigation.selectedMetric {
            MetricDetailView(kind: metric, presentation: notchSize == nil ? .hubPanel : .island)
                .id(metric)
                .padding(.horizontal, 4)
                .transition(.opacity)
        } else {
            NotchSystemView { kind in
                withAnimation(.easeInOut(duration: 0.22)) {
                    navigation.selectMetric(kind)
                    if notchSize != nil { NotchService.shared.refreshPresentation() }
                }
            }
            .transition(.opacity)
        }
    }
}
