// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Non-key controls leave keyboard ownership with the editable selection.
final class RecorderWaitingControls {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }
    let panel: NSPanel
    init(audio: RecorderSelectionAudioOptions, start: @escaping () -> Void, cancel: @escaping () -> Void) {
        panel = Panel(contentRect: CGRect(x: 0, y: 0, width: 264, height: 48),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: RecorderWaitingBar(audio: audio, start: start, cancel: cancel))
    }
    func show(in selection: CGRect, screen: CGRect) {
        let size = panel.frame.size
        let x = min(max(selection.midX - size.width / 2, screen.minX + 8), screen.maxX - size.width - 8)
        let y = min(max(selection.midY - size.height / 2, screen.minY + 8), screen.maxY - size.height - 8)
        panel.setFrameOrigin(CGPoint(x: x, y: y))
        panel.orderFrontRegardless()
    }
    func hide() { panel.orderOut(nil) }
    deinit { panel.orderOut(nil) }
}

private struct RecorderWaitingBar: View {
    @ObservedObject var audio: RecorderSelectionAudioOptions
    let start: () -> Void
    let cancel: () -> Void
    private var strings: RecorderFeatureStrings { FeatureStrings.recorder(L10n.shared.language) }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                WaitingInputButton(icon: "speaker.wave.2.fill", title: strings.systemAudioTrackLabel,
                                   enabled: audio.systemAudio) { audio.systemAudio.toggle() }
                WaitingInputButton(icon: "mic.fill", title: strings.microphoneTrackLabel,
                                   enabled: audio.microphone) { audio.microphone.toggle() }
                    .contextMenu { RecorderInputSourceMenu(camera: false) }
                RecorderOverlayInputControls()
            }
            .padding(6)
            .background(.regularMaterial, in: Capsule())

            HStack(spacing: 4) {
                WaitingActionButton(icon: "play.fill", isDestructive: false,
                                    tooltip: strings.startButton, action: start)
                WaitingActionButton(icon: "xmark", isDestructive: true,
                                    tooltip: strings.cancelButton, action: cancel)
            }
            .padding(4)
            .background(.regularMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .padding(2)
    }
}

private struct WaitingActionButton: View {
    let icon: String
    var isDestructive: Bool = false
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isDestructive ? Color.red : Color.primary)
                .frame(width: 28, height: 32)
                .background(
                    Capsule()
                        .fill(isHovered
                              ? (isDestructive ? Color.red.opacity(0.15) : Color.primary.opacity(0.10))
                              : Color.clear)
                )
                .overlay {
                    if isHovered {
                        Capsule()
                            .strokeBorder(isDestructive ? Color.red.opacity(0.25) : Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
                }
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(WaitingFeedbackButtonStyle(isDestructive: isDestructive))
        .onHover { isHovered = $0 }
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }
}

private struct WaitingInputButton: View {
    let icon: String
    let title: String
    let enabled: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(enabled ? .white : (isHovered ? .primary : .secondary))
                .frame(width: 32, height: 26)
                .background(
                    enabled
                        ? (isHovered ? Color.accentColor.opacity(0.85) : Color.accentColor)
                        : (isHovered ? Color.primary.opacity(0.14) : Color.primary.opacity(0.06)),
                    in: Capsule()
                )
                .overlay {
                    if isHovered && !enabled {
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                    }
                }
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct WaitingFeedbackButtonStyle: ButtonStyle {
    var isDestructive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Capsule()
                    .fill(configuration.isPressed
                          ? (isDestructive ? Color.red.opacity(0.25) : Color.accentColor.opacity(0.28))
                          : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
