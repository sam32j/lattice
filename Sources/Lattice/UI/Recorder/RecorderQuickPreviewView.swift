// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

final class RecorderQuickPreviewPanel: OverlayPanel {
    override var canBecomeKey: Bool { true }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, !isKeyWindow { makeKey() }
        super.sendEvent(event)
    }
}

struct RecorderQuickPreviewView: View {
    let url: URL
    @ObservedObject var model: RecorderQuickPreviewModel
    let shareAnchor: ShelfSharePickerAnchor.Anchor
    let embedded: Bool
    let onClose: () -> Void
    let onEdit: () -> Void
    let onCopy: () -> Void
    let onDownload: () -> Void
    let onSaveAs: () -> Void
    let onShare: () -> Void
    let onQuickLook: () -> Void
    let onHoverChanged: (Bool) -> Void
    let applicationsForMenu: () -> [URL]
    let openWith: (URL) -> Void
    let revealInFinder: () -> Void
    let onMenuChanged: (Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var l10n = L10n.shared
    @State private var isViewportHovered = false
    @State private var isCopyHovered = false
    @State private var isSaveHovered = false

    var recorder: RecorderFeatureStrings { FeatureStrings.recorder(l10n.language) }
    var screenshot: ScreenshotFeatureStrings { FeatureStrings.screenshot(l10n.language) }
    var text: ScreenshotEditorRefinementStrings { FeatureStrings.editorRefinements(l10n.language) }

    var toolbar: some View {
        HStack(spacing: 2) {
            Button {
                onDownload()
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(NotchButtonStyle(cornerRadius: 8))
            .controlSize(.small)
            .focusable(false)
            .screenshotSafeHelp("\(recorder.saveButton)  (⌘S)")
            .accessibilityLabel(recorder.saveButton)

            Button {
                onCopy()
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(NotchButtonStyle(cornerRadius: 8))
            .controlSize(.small)
            .focusable(false)
            .screenshotSafeHelp("\(recorder.copyButton)  (⌘C)")
            .accessibilityLabel(recorder.copyButton)

            Button {
                onShare()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(NotchButtonStyle(cornerRadius: 8))
            .controlSize(.small)
            .focusable(false)
            .background(ShelfSharePickerAnchor(anchor: shareAnchor))
            .screenshotSafeHelp(screenshot.shareButton)
            .accessibilityLabel(screenshot.shareButton)

            Button {
                onEdit()
            } label: {
                Image(systemName: "scissors")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(NotchButtonStyle(cornerRadius: 8))
            .controlSize(.small)
            .focusable(false)
            .screenshotSafeHelp("\(screenshot.editButton)  (⏎ / E)")
            .accessibilityLabel(screenshot.editButton)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                if let image = model.thumbnail {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: embedded ? nil : 320, height: 138)
                        .clipped()
                        .background(Color.black.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
                        .onTapGesture(count: 2, perform: onQuickLook)
                } else {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.black.opacity(0.2))
                        .frame(width: embedded ? nil : 320, height: 138)
                        .overlay(ProgressView().controlSize(.small))
                }

                // Play indicator when not hovered
                if !isViewportHovered {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 2)
                        .allowsHitTesting(false)
                        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }

                if !embedded {
                    VStack {
                        HStack {
                            thumbnailButton(symbol: "xmark", title: "\(screenshot.done)  (⎋)", action: onClose)
                            Spacer()
                            thumbnailButton(symbol: "square.and.arrow.up", title: "\(screenshot.shareButton)", action: onShare)
                                .background(ShelfSharePickerAnchor(anchor: shareAnchor))
                        }
                        Spacer()
                        HStack {
                            thumbnailButton(symbol: "scissors", title: "\(screenshot.editButton)  (⏎ / E)", action: onEdit)
                            Spacer()
                        }
                    }
                    .padding(6)

                    if isViewportHovered {
                        centerActions
                            .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                    }
                }
            }
            .frame(width: embedded ? nil : 320, height: 138)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .onHover { inside in
                isViewportHovered = inside
            }
        }
        .padding(embedded ? 0 : 10)
        .frame(width: embedded ? nil : 340, height: embedded ? nil : 158)
        .background {
            if !embedded {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.22), radius: 10, y: 4)
            }
        }
        .overlay {
            if !embedded {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            }
        }
        .onHover(perform: onHoverChanged)
        .contextMenu {
            contextMenuItems
        }
    }

    private var centerActions: some View {
        VStack(spacing: 6) {
            Button(action: onCopy) {
                HStack(spacing: 5) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                    Text(recorder.copyButton)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(minWidth: 84)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isCopyHovered ? Color.accentColor.opacity(0.85) : Color.accentColor,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(isCopyHovered ? 0.35 : 0.15), lineWidth: 1)
                )
                .scaleEffect(isCopyHovered ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: isCopyHovered)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .onHover { isCopyHovered = $0 }
            .screenshotSafeHelp("\(recorder.copyButton)  (⌘C)")

            Button(action: onDownload) {
                HStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                    Text(recorder.saveButton)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(minWidth: 84)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isSaveHovered ? Color.white.opacity(0.25) : Color.black.opacity(0.45),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(isSaveHovered ? 0.35 : 0.15), lineWidth: 1)
                )
                .scaleEffect(isSaveHovered ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 0.12), value: isSaveHovered)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .onHover { isSaveHovered = $0 }
            .screenshotSafeHelp("\(recorder.saveButton)  (⌘S)")
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 8, y: 3)
    }

    private func thumbnailButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.black.opacity(0.65), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8))
                .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .screenshotSafeHelp(title)
        .accessibilityLabel(title)
    }
}
