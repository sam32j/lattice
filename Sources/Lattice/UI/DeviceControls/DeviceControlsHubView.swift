// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// Hosted container view for Device Controls in the Lattice Hub.
/// Manages navigation between the main Device Controls overview and the App Volumes subpage.
struct DeviceControlsHubView: View {
    @ObservedObject private var navigation = DeviceControlsNavigationState.shared
    var onClose: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if navigation.currentSubpage == .appVolumes {
                    DeviceControlsAppVolumesView()
                } else {
                    DeviceControlsMainView()
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }
}
