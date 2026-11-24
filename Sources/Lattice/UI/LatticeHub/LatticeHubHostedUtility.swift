// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

struct LatticeHubHostedUtility: View {
    let item: LatticeHubItem
    let notchSize: CGSize?
    let onClose: () -> Void
    @ObservedObject private var launcher = LatticeHubService.shared
    @ObservedObject private var deviceControlsNav = DeviceControlsNavigationState.shared

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
        case .appManager:
            return AppManagerPanelState.shared.contentHeight ?? 470
        case .videoDownloader:
            return 172
        case .deviceControls:
            return DeviceControlsNavigationState.shared.contentHeight
        case .recentCaptures:
            // Same height as All Tools, so opening it never resizes the
            // panel, but always room for three 150pt previews.
            return max(RecentCapturesView.floatingMinimumHeight, launcher.floatingRootPageHeight)
        default:
            return 470
        }
    }

    var body: some View {
        utilityContent
            .clipped()
    }

    @ViewBuilder
    private var utilityContent: some View {
        if item == .recentCaptures {
            // Floating HUD history owns the whole viewport, not the
            // compact menu-panel list height. Island history stays horizontal.
            RecentCapturesView(onClose: onClose, showHeader: false, notchSize: notchSize,
                               fillsAvailableSpace: notchSize == nil)
                .frame(height: viewportHeight, alignment: .top)
        } else if item == .deviceControls {
            DeviceControlsHubView(onClose: onClose, notchSize: notchSize, viewportHeight: viewportHeight)
                .frame(height: viewportHeight, alignment: .top)
        } else if item == .killProcess {
            // Its list scrolls itself; inside another scroll view it would
            // collapse to no height.
            KillProcessView(surface: notchSize == nil ? .hud : .island)
                .frame(height: viewportHeight)
        } else if item == .system {
            LatticeHubSystemUtility(notchSize: notchSize)
        } else if item == .wallpaper, let notchSize {
            // The island is sized to the page (WallpaperIslandLayout), which
            // pages sideways itself; an outer scroll view would only steal
            // the wheel from it.
            WallpaperSection(collapsible: false, showHeader: false, onClose: onClose)
                .frame(height: notchSize.height, alignment: .top)
        } else if item == .windowLayout {
            if let notchSize {
                // Pin the page to its top so it never re-centres while the
                // island springs; the island's page clip bounds it.
                WindowSnappingHubUtility(layoutWidth: notchSize.width, horizontalInset: 12,
                                         verticalInset: 8, showsModeSwitcher: false,
                                         drivesIslandHeight: true)
                    .frame(height: notchSize.height, alignment: .top)
            } else {
                // Never scrolls: the grid and presets use the wheel, and the
                // HUD follows the page's animated height frame by frame.
                WindowSnappingHubUtility()
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    switch item {
                    case .media:
                        PanelMediaView(showHeader: false, onClose: onClose)
                    case .urlCleaner:
                        PanelURLCleanerView(showHeader: false, onClose: onClose)
                    case .appManager:
                        PanelAppManagerView(onClose: onClose)
                    case .cleaner:
                        PanelCleanerView(showHeader: false, onClose: onClose)
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

private struct WindowSnappingHubUtility: View {
    var layoutWidth: CGFloat = 376
    var horizontalInset: CGFloat = 14
    var verticalInset: CGFloat = 14
    var showsModeSwitcher = true
    var drivesIslandHeight = false

    @ObservedObject private var service = WindowLayoutService.shared

    var body: some View {
        WindowSnappingControlView(
            callbacks: WindowSnappingCallbacks(
                onPreview: { rect, _ in
                    service.showPreview(normalizedRect: rect)
                },
                onSnap: { rect, _ in
                    service.hidePreview(immediately: true)
                    service.apply(normalizedRect: rect)
                },
                onAction: { action in
                    service.hidePreview(immediately: true)
                    service.apply(action.layoutAction)
                    service.refreshSnappingSessionSoon()
                },
                onLayoutTransition: { duration in
                    LatticeHubService.shared.followContentDrivenResize(for: duration)
                }
            ),
            // Cached for the session: computing it here asked the window
            // server and the front app on every redraw of the island.
            canRestore: service.snappingRestoreAvailable,
            layoutWidth: layoutWidth,
            horizontalInset: horizontalInset,
            verticalInset: verticalInset,
            showsModeSwitcher: showsModeSwitcher,
            drivesIslandHeight: drivesIslandHeight
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .onAppear {
            PanelInteractionState.shared.viewKeepsPopoverOpen = true
            service.beginSnappingSession()
        }
        .onDisappear {
            PanelInteractionState.shared.viewKeepsPopoverOpen = false
            service.endSnappingSession()
        }
    }
}

private struct LatticeHubSystemUtility: View {
    let notchSize: CGSize?
    @ObservedObject private var navigation = SystemNavigationState.shared
    @ObservedObject private var launcher = LatticeHubService.shared
    @ObservedObject private var deviceControlsNav = DeviceControlsNavigationState.shared
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
                if notchSize != nil {
                    navigation.selectMetric(kind)
                    NotchService.shared.refreshPresentation(transitionContent: .page)
                } else {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        navigation.selectMetric(kind)
                    }
                }
            }
            .transition(.opacity)
        }
    }
}
