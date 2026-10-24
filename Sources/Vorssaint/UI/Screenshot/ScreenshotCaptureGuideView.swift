// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI
import Carbon.HIToolbox

final class CaptureGuideViewModel: ObservableObject {
    @Published var overlapsSelection = false
    @Published var isAreaDragging = false
    @Published var offersScrollingCapture = false
    @Published var offersRepeatLastRegion = false
    @Published var requiresDraggedRegion = false
    @Published var scrollingCaptureEnabled = false
    @Published var loupeEnabled = false
    @Published var selectedWindowsCount = 0
    var onHoverChanged: ((Bool) -> Void)?
    @Published var isHovered = false {
        didSet {
            if oldValue != isHovered {
                onHoverChanged?(isHovered)
            }
        }
    }
}

struct CaptureGuideView: View {
    let strings: ScreenshotFeatureStrings
    let purpose: String?
    @ObservedObject var model: CaptureGuideViewModel
    let screenCaptureOptions: ScreenCaptureSelectionOptions?
    let onFullScreen: () -> Void
    let onToggleScrolling: () -> Void
    let onToggleLoupe: () -> Void
    let onRepeatLastRegion: () -> Void
    let onToggleMode: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Group {
        if let screenCaptureOptions {
            UnifiedCaptureGuideContent(strings: strings,
                                       options: screenCaptureOptions,
                                       model: model,
                                       onFullScreen: onFullScreen,
                                       onToggleScrolling: onToggleScrolling,
                                       onToggleLoupe: onToggleLoupe,
                                       onRepeatLastRegion: onRepeatLastRegion,
                                       onToggleMode: onToggleMode,
                                       onCancel: onCancel)
                .allowsHitTesting(true)
        } else {
            standardGuide
        }
        }
        .opacity(CapturePresentationPolicy.toolbarOpacity(overlapsSelection: model.overlapsSelection,
                                                          isDragging: model.isAreaDragging))
        .animation(.easeOut(duration: 0.12), value: model.overlapsSelection)
        .animation(.easeOut(duration: 0.12), value: model.isHovered)
    }

    private var standardGuide: some View {
        HStack(spacing: 8) {
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

            HStack(spacing: 7) {
                Text(subtitle)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                CaptureKeyHint(key: "X",
                               icon: "rectangle.dashed",
                               isEnabled: model.offersRepeatLastRegion,
                               action: model.offersRepeatLastRegion ? onRepeatLastRegion : nil)
                CaptureKeyHint(key: "F", icon: "rectangle.inset.filled", action: onFullScreen)
                if model.offersScrollingCapture {
                    CaptureKeyHint(key: "S",
                                   icon: "rectangle.stack",
                                   isActive: model.scrollingCaptureEnabled,
                                   action: onToggleScrolling)
                }
                CaptureKeyHint(key: "Z",
                               icon: "plus.magnifyingglass",
                               isActive: model.loupeEnabled,
                               action: onToggleLoupe)
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
            .onTapGesture {}
        }
        .onHover { hovering in
            model.isHovered = hovering
        }
        .allowsHitTesting(true)
    }

    private var subtitle: String {
        if model.selectedWindowsCount > 0 {
            return CaptureWorkflowStrings.localized(L10n.shared.language).selectedWindows(model.selectedWindowsCount)
        }
        return strings.hintDrag + "  ·  " + strings.hintClick
    }
}
