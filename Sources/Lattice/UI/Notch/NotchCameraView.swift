// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AVFoundation
import SwiftUI

struct NotchCameraView: View {
    let size: CGSize
    @ObservedObject private var service = CameraPreviewService.shared

    /// Showing the page is what starts the camera, and leaving it stops it:
    /// there is no closed state asking to open it.
    var body: some View {
        // The preview takes the whole page; its camera picker overlays the
        // preview viewport just as the floating window does.
        CameraPreviewView(size: NotchLayout.cameraPreviewSize(in: size), showsCameraMenu: true, showsCloseButton: false)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { service.showEmbedded() }
            .onDisappear { service.hideEmbedded() }
    }
}
