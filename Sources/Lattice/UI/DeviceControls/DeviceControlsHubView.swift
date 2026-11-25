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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if navigation.currentSubpage == .appVolumes && volumeMixerEnabled {
                    DeviceControlsAppVolumesView()
                } else {
                    DeviceControlsMainView()
                }
            }
            .padding(.horizontal, 2)
            // The island is sized to this content, as before; the floating
            // Hub keeps room for its soft edges at rest.
            .padding(.top, notchSize == nil ? HubScrollEdge.inset : 4)
            .padding(.bottom, notchSize == nil ? HubScrollEdge.inset : 6)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                if navigation.currentSubpage == .appVolumes && volumeMixerEnabled {
                    navigation.updateMeasuredAppVolumesHeight(height)
                } else {
                    navigation.updateMeasuredMainHeight(height)
                }
            }
        }
        .frame(height: notchSize?.height ?? viewportHeight ?? navigation.contentHeight, alignment: .top)
        .hubScrollEdgeFade()
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
