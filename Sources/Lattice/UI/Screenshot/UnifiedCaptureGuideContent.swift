// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import Carbon.HIToolbox

struct UnifiedCaptureGuideContent: View {
    let strings: ScreenshotFeatureStrings
    @ObservedObject var options: ScreenCaptureSelectionOptions
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject var model: CaptureGuideViewModel
    let onFullScreen: () -> Void
    let onToggleScrolling: () -> Void
    let onToggleLoupe: () -> Void
    let onRepeatLastRegion: () -> Void
    let onToggleMode: () -> Void
    let onCancel: () -> Void

    @State private var isTopHovered = false
    @State private var isEscapeHovered = false
    @State private var isGuideHovered = false
    @State private var isModeHovered = false

    private func updateHover() {
        model.isHovered = isTopHovered || isEscapeHovered || isGuideHovered || isModeHovered
    }

    private var isMultiWindowMode: Bool { model.selectedWindowsCount > 0 }

    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            topControlBar
                .onHover { hovering in
                    isTopHovered = hovering
                    updateHover()
                }
            HStack(spacing: 8) {
                escapeHint
                    .onHover { hovering in
                        isEscapeHovered = hovering
                        updateHover()
                    }
                contextualGuide
                    .onHover { hovering in
                        isGuideHovered = hovering
                        updateHover()
                    }
                modeSwitchHint
                    .onHover { hovering in
                        isModeHovered = hovering
                        updateHover()
                    }
            }
        }
    }

    @ViewBuilder
    private var topControlBar: some View {
        if options.selectedTool == .recording {
            RecorderSelectionAudioControls(options: options.recorderAudio)
                .opacity(options.selectedTool == .recording ? 1 : 0)
                .allowsHitTesting(options.selectedTool == .recording)
                .accessibilityHidden(options.selectedTool != .recording)
        } else if model.offersScrollingCapture && options.selectedTool == .screenshot {
            scrollToggleBar
        }
    }

    private var scrollToggleBar: some View {
        let isEnabled = !isMultiWindowMode
        return Button(action: onToggleScrolling) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 11, weight: .semibold))
                Text(CaptureWorkflowStrings.localized(l10n.language).scroll)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(
                !isEnabled
                    ? Color.secondary.opacity(0.4)
                    : (model.scrollingCaptureEnabled ? Color.white : Color.primary)
            )
            .padding(.horizontal, 12)
            .frame(height: 26)
            .background(
                !isEnabled
                    ? Color.primary.opacity(0.02)
                    : (model.scrollingCaptureEnabled ? Color.accentColor : Color.primary.opacity(0.06)),
                in: Capsule(style: .continuous)
            )
            .overlay {
                if isEnabled && model.scrollingCaptureEnabled {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                }
            }
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(!isEnabled)
        .padding(3)
        .background(CaptureChromeBackdrop(material: .regularMaterial,
                                          shape: Capsule(style: .continuous)))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
    }

    private var contextualGuide: some View {
        let isEnabled = !isMultiWindowMode
        return HStack(spacing: 7) {
            subtitleView
            if options.selectedTool != .color {
                CaptureKeyHint(key: "X",
                               icon: "rectangle.dashed",
                               isEnabled: model.offersRepeatLastRegion && isEnabled,
                               action: model.offersRepeatLastRegion && isEnabled ? onRepeatLastRegion : nil)
                CaptureKeyHint(key: "F",
                               icon: "rectangle.inset.filled",
                               isEnabled: isEnabled,
                               action: isEnabled ? onFullScreen : nil)
                CaptureKeyHint(key: "Z",
                               icon: "plus.magnifyingglass",
                               isActive: model.loupeEnabled,
                               isEnabled: isEnabled,
                               action: isEnabled ? onToggleLoupe : nil)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(CaptureChromeBackdrop(material: .ultraThinMaterial,
                                          shape: Capsule(style: .continuous)))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
        .contentShape(Capsule(style: .continuous))
        .onTapGesture {
            // Absorb clicks on the bar text / background so it doesn't start a drag or hide the tab
        }
    }

    private var escapeHint: some View {
        Button(action: onCancel) {
            HStack(spacing: 5) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                Text("esc")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(CaptureChromeBackdrop(
                material: .regularMaterial,
                shape: RoundedRectangle(cornerRadius: 14, style: .continuous)))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    private var modeSwitchHint: some View {
        let isRecording = options.selectedTool == .recording
        let iconName = isRecording ? "camera.viewfinder" : "record.circle"
        let isEnabled = !isMultiWindowMode
        return Button(action: onToggleMode) {
            HStack(spacing: 5) {
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .semibold))
                Text("R")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(isEnabled ? Color.secondary : Color.secondary.opacity(0.35))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(CaptureChromeBackdrop(
                material: .regularMaterial,
                shape: RoundedRectangle(cornerRadius: 14, style: .continuous)))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(isEnabled ? 0.10 : 0.04), lineWidth: 1)
            }
            .shadow(color: .black.opacity(isEnabled ? 0.18 : 0.05), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(!isEnabled)
    }

    @ViewBuilder
    private var subtitleView: some View {
        switch options.selectedTool {
        case .screenshot:
            if model.selectedWindowsCount > 0 {
                Text(CaptureWorkflowStrings.localized(L10n.shared.language).selectedWindows(model.selectedWindowsCount))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else {
                HStack(spacing: 4) {
                    Text(strings.hintDrag)
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(strings.hintClick)
                        .foregroundColor(model.scrollingCaptureEnabled ? .secondary.opacity(0.35) : .secondary)
                }
                .font(.system(size: 10.5, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
        case .recording:
            let clickText = CaptureWorkflowStrings.localized(l10n.language).recordWindow
            HStack(spacing: 4) {
                Text(strings.hintDrag)
                    .foregroundColor(.secondary)
                Text("·")
                    .foregroundColor(.secondary.opacity(0.5))
                Text(clickText)
                    .foregroundColor(.secondary)
            }
            .font(.system(size: 10.5, weight: .medium))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        case .text:
            Text(l10n.s.ocrCaption)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        case .color:
            Text(l10n.s.colorPickerCaption)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}
