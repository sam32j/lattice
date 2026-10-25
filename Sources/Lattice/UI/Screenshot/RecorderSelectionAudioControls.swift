// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import Carbon.HIToolbox

struct RecorderSelectionAudioControls: View {
    @ObservedObject var options: RecorderSelectionAudioOptions
    @ObservedObject private var l10n = L10n.shared

    private var strings: RecorderFeatureStrings { FeatureStrings.recorder(l10n.language) }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                options.systemAudio.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(strings.systemAudioTrackLabel)
                        .font(.system(size: 10.5, weight: .medium))
                }
                .foregroundStyle(options.systemAudio ? Color.white : Color.secondary)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    options.systemAudio
                        ? Color.accentColor
                        : Color.primary.opacity(0.06),
                    in: Capsule(style: .continuous)
                )
                .overlay {
                    if options.systemAudio {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                    }
                }
            }
            .buttonStyle(.plain)
            .focusable(false)

            Button {
                options.microphone.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(strings.microphoneTrackLabel)
                        .font(.system(size: 10.5, weight: .medium))
                }
                .foregroundStyle(options.microphone ? Color.white : Color.secondary)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(
                    options.microphone
                        ? Color.accentColor
                        : Color.primary.opacity(0.06),
                    in: Capsule(style: .continuous)
                )
                .overlay {
                    if options.microphone {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                    }
                }
            }
            .buttonStyle(.plain)
            .focusable(false)
            .contextMenu { RecorderInputSourceMenu(camera: false) }

            RecorderOverlayInputControls()
        }
        .padding(3)
        .background(CaptureChromeBackdrop(material: .regularMaterial,
                                          shape: Capsule(style: .continuous)))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
    }
}
