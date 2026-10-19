// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AVFoundation
import SwiftUI

struct RecorderOverlayInputControls: View {
    @ObservedObject private var overlays = RecorderOverlayController.shared
    private var text: RecorderOverlayStrings { FeatureStrings.recorderOverlay(L10n.shared.language) }
    var body: some View {
        HStack(spacing: 6) {
            Button { overlays.toggleCamera() } label: {
                Image(systemName: "video.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(overlays.cameraEnabled ? .white : .secondary)
                    .frame(width: 32, height: 26)
                    .background(overlays.cameraEnabled ? Color.accentColor : Color.primary.opacity(0.06), in: Capsule())
            }
            .help(text.camera)
            .accessibilityLabel(text.camera)
            .contextMenu { RecorderInputSourceMenu(camera: true) }
            Button { overlays.keysEnabled.toggle() } label: {
                Image(systemName: "keyboard")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(overlays.keysEnabled ? .white : .secondary)
                    .frame(width: 32, height: 26)
                    .background(overlays.keysEnabled ? Color.accentColor : Color.primary.opacity(0.06), in: Capsule())
            }
            .help(text.keys)
            .accessibilityLabel(text.keys)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .alert(text.unavailable, isPresented: Binding(get: { overlays.errorMessage != nil },
            set: { if !$0 { overlays.dismissError() } })) {
                Button("OK") { overlays.dismissError() }
            } message: { Text(overlays.errorMessage ?? "") }
    }
}

struct RecorderInputSourceMenu: View {
    let camera: Bool
    @ObservedObject private var overlays = RecorderOverlayController.shared
    @State private var devices: [AVCaptureDevice] = []
    private var selected: String? { camera ? overlays.selectedCameraID : overlays.selectedMicrophoneID }
    private var text: RecorderOverlayStrings { FeatureStrings.recorderOverlay(L10n.shared.language) }
    var body: some View {
        Button { select(nil) } label: {
            if selected == nil { Label(text.defaultInput, systemImage: "checkmark") }
            else { Text(text.defaultInput) }
        }
        .onAppear { devices = camera ? RecorderCaptureInputs.cameras : RecorderCaptureInputs.microphones }
        Divider()
        ForEach(devices, id: \.uniqueID) { device in
            Button { select(device.uniqueID) } label: {
                if selected == device.uniqueID { Label(device.localizedName, systemImage: "checkmark") }
                else { Text(device.localizedName) }
            }
        }
        if devices.isEmpty { Text(camera ? text.noCamera : text.noMicrophone).disabled(true) }
    }
    private func select(_ id: String?) {
        if camera { overlays.selectedCameraID = id }
        else { overlays.selectedMicrophoneID = id }
    }
}
