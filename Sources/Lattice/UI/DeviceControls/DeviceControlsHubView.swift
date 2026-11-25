// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// Hosted container view for Device Controls in the Lattice Hub.
/// Manages navigation between the main Device Controls overview and the App Volumes subpage.
struct DeviceControlsHubView: View {
    @ObservedObject private var navigation = DeviceControlsNavigationState.shared
    @AppStorage(DefaultsKey.volumeMixerEnabled) private var volumeMixerEnabled = true
    var onClose: () -> Void
    var notchSize: CGSize? = nil
    /// The height the host shows, when it is less than the content: the
    /// floating panel caps it, and the list must scroll inside that space.
    var viewportHeight: CGFloat? = nil

    /// App Volumes taller than the height it is given.
    private var appVolumesOverflow: Bool {
        let available = notchSize?.height ?? viewportHeight ?? navigation.contentHeight
        return navigation.measuredAppVolumesHeight > available + 1
    }

    var body: some View {
        Group {
            if navigation.currentSubpage == .appVolumes && volumeMixerEnabled {
                // App Volumes can outgrow the space: it scrolls under soft
                // edges, with room for them at rest.
                ScrollView(showsIndicators: false) {
                    DeviceControlsAppVolumesView()
                        .padding(.horizontal, 2)
                        .padding(.vertical, HubScrollEdge.inset)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                            navigation.updateMeasuredAppVolumesHeight(height)
                        }
                }
                // Shorter than the space it has (never less than the main
                // page), it holds still with hard edges.
                .scrollDisabled(!appVolumesOverflow)
                .scrollBounceBehavior(.basedOnSize)
                .hubScrollEdgeFade(appVolumesOverflow)
            } else {
                // Device Controls never scrolls and keeps hard edges: the
                // island and the floating Hub are sized to all of it.
                DeviceControlsMainView()
                    .padding(.horizontal, 2)
                    .padding(.top, 4)
                    .padding(.bottom, 14)
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                        navigation.updateMeasuredMainHeight(height)
                    }
            }
        }
        .frame(height: notchSize?.height ?? viewportHeight ?? navigation.contentHeight, alignment: .top)
        .onAppear {
            if !volumeMixerEnabled, navigation.currentSubpage == .appVolumes {
                navigation.resetSubpage()
            }
            NotchService.shared.noteDeviceControlsSuppression(active: true)
        }
        .onChange(of: volumeMixerEnabled) { _, enabled in
            if !enabled, navigation.currentSubpage == .appVolumes {
                navigation.resetSubpage()
            }
        }
        .onDisappear {
            NotchService.shared.noteDeviceControlsSuppression(active: false)
        }
    }
}
