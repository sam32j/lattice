// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

struct LatticeHubHostedUtility: View {
    let item: LatticeHubItem
    let notchSize: CGSize?
    let onClose: () -> Void
    @ObservedObject private var launcher = LatticeHubService.shared
    @ObservedObject private var deviceControlsNav = DeviceControlsNavigationState.shared
    @ObservedObject private var appManager = AppManagerPanelState.shared

    private var viewportHeight: CGFloat {
        // Floating panels can be moved upward; only content taller than the
        // available display needs its own scroll viewport.
        guard let notchSize else {
            // The App Manager's tabs add a row to the header above.
            let header: CGFloat = item == .appManager ? 92 + 33 : 92
            return min(fallbackHeight, max(100, launcher.floatingPanelHeightBudget - header))
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
        } else if item == .appManager, [.uninstaller, .updates].contains(appManager.shownTab) {
            // The uninstaller and updates fill the panel and scroll their
            // own lists, so a heading or button stays put rather than
            // scrolling away.
            PanelAppManagerView(onClose: onClose, showsPicker: false)
                .frame(height: viewportHeight)
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
                        // The tab is chosen in the header, which never scrolls.
                        PanelAppManagerView(onClose: onClose, showsPicker: false)
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
            // Content scrolls out under a soft edge rather than being cut by
            // a hard line against the header and the bottom; the margin keeps
            // it clear of the fade until it scrolls.
            .contentMargins(.vertical, HubScrollEdge.inset, for: .scrollContent)
            .frame(height: viewportHeight)
            .hubScrollEdgeFade()
        }
    }
}

/// The soft top and bottom edges of a Hub utility that scrolls.
enum HubScrollEdge {
    /// The fade's height, and the margin that keeps content out of it at rest.
    static let inset: CGFloat = 10
    static let cornerRadius: CGFloat = 12
}

extension View {
    /// Fades the top and bottom `HubScrollEdge.inset` of a scrolling area and
    /// rounds its corners; the content needs that much room at rest. The fade
    /// only shows while the content is taller than the area: a page that
    /// fits, as most island pages do, keeps every row at full strength.
    func hubScrollEdgeFade(_ isActive: Bool = true) -> some View {
        modifier(HubScrollEdgeFade(isActive: isActive))
    }
}

private struct HubScrollEdgeFade: ViewModifier {
    let isActive: Bool
    @State private var overflows = true

    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom
                        > geometry.containerSize.height + 1
                } action: { _, value in
                    overflows = value
                }
                .mask { mask(fading: isActive && overflows) }
        } else {
            content.mask { mask(fading: isActive) }
        }
    }

    @ViewBuilder
    private func mask(fading: Bool) -> some View {
        if fading {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: HubScrollEdge.inset)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: HubScrollEdge.inset)
            }
            .clipShape(RoundedRectangle(cornerRadius: HubScrollEdge.cornerRadius, style: .continuous))
        } else {
            Rectangle()
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
            .contentMargins(.vertical, HubScrollEdge.inset, for: .scrollContent)
            .frame(height: notchSize.height)
            .hubScrollEdgeFade()
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
            .contentMargins(.vertical, HubScrollEdge.inset, for: .scrollContent)
            .frame(height: min(floatingDetailNaturalHeight + HubScrollEdge.inset * 2,
                               max(100, launcher.floatingPanelHeightBudget - 92)))
            .hubScrollEdgeFade()
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
