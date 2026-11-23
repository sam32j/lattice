// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AVFoundation
import SwiftUI

struct NotchCameraView: View {
    let size: CGSize
    @ObservedObject private var service = CameraPreviewService.shared
    @ObservedObject private var l10n = L10n.shared
    /// Capture stopped while this page stayed on screen.
    @State private var stoppedHere = false

    /// Showing the page is what starts the camera, and leaving it stops it:
    /// there is no closed state asking to open it.
    var body: some View {
        Group {
            if stoppedHere {
                // Only reached if capture stopped while the page stayed open:
                // offer to start it again rather than a spinner that never ends.
                Button(FeatureStrings.notchActivities(l10n.language).startCamera, action: start)
                    .controlSize(.small)
            } else {
                // The preview takes the whole page; its camera picker overlays
                // the preview viewport just as the floating window does.
                CameraPreviewView(size: NotchLayout.cameraPreviewSize(in: size), showsCameraMenu: true,
                                  showsCloseButton: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: start)
        .onDisappear { service.hideEmbedded() }
        .onChange(of: service.isEmbeddedPresented) { wasPresented, isPresented in
            if wasPresented && !isPresented { stoppedHere = true }
        }
    }

    private func start() {
        stoppedHere = false
        service.showEmbedded()
    }
}
