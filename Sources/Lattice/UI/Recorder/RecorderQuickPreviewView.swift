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
    let onQuickLink: (RecordingShareDuration) -> Void
    let onCopyLink: () -> Void
    let onDelete: () -> Void
    let onContextDelete: () -> Void
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
    private var previewNotice: CapturePreviewNoticeStrings { .localized(l10n.language) }

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
        Group {
            if embedded { islandPreview }
            else { floatingPreview }
        }
        .onHover(perform: onHoverChanged)
        .contextMenu {
            contextMenuItems
            if !embedded {
                Divider()
                if UserDefaults.standard.bool(forKey: DefaultsKey.recorderSharingEnabled) {
                    Menu(previewNotice.quickLink) { quickLinkActions }
                        .disabled(model.sharing)
                }
                Button(previewNotice.trashAction, action: onContextDelete)
            }
        }
    }

    /// Reuses the image preview's measured canvas. The Island's native size
    /// never changes: no lower action row, and the movie artwork fills the
    /// full available rectangle underneath its floating toolbar.
    private var islandPreview: some View {
        GeometryReader { canvas in
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image = model.thumbnail {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                            .frame(width: canvas.size.width, height: canvas.size.height)
                            .clipped()
                            .onDrag {
                                NSItemProvider(contentsOf: url) ?? NSItemProvider()
                            } preview: {
                                Image(decorative: image, scale: 1)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: min(canvas.size.width, 240),
                                           height: min(canvas.size.height, 150))
                                    .clipped()
                            }
                            .onTapGesture(count: 2, perform: onQuickLook)
                    } else {
                        Color.black.opacity(0.2)
                            .overlay(ProgressView().controlSize(.small))
                    }
                }
                .frame(width: canvas.size.width, height: canvas.size.height)
                .background(Color.black.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    // Playback is a deliberate action, not an icon covering the
                    // center of the image or the source used for dragging.
                    thumbnailButton(symbol: "play.fill", title: CaptureInterfaceStrings.localized(l10n.language).quickLook, action: onQuickLook)
                        .padding(6)
                }

                islandVideoToolbar.padding(6)
            }
        }
    }

    private func islandTool(_ symbol: String, title: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) { islandToolImage(symbol) }
            .buttonStyle(NotchButtonStyle(cornerRadius: 8))
            .controlSize(.small)
            .focusable(false)
            .screenshotSafeHelp(title)
            .help(title)
            .accessibilityLabel(title)
    }

    private func islandToolImage(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle()) // Entire hover backdrop is clickable.
    }

    private var islandSeparator: some View {
        Rectangle()
            .fill(Color.white.opacity(0.18))
            .frame(width: 1, height: 15)
            .padding(.horizontal, 5)
            .accessibilityHidden(true)
    }

    /// Copy, Save | Share, Quick Link | Trim, Delete.
    private var islandVideoToolbar: some View {
        HStack(spacing: 3) {
            islandTool("doc.on.doc", title: recorder.copyButton, action: onCopy)
            islandTool("square.and.arrow.down", title: recorder.saveButton, action: onDownload)
            islandSeparator
            islandTool("square.and.arrow.up", title: screenshot.shareButton, action: onShare)
            if UserDefaults.standard.bool(forKey: DefaultsKey.recorderSharingEnabled) {
                quickLinkIslandControl
            }
            islandSeparator
            islandTool("scissors", title: screenshot.editButton, action: onEdit)
            CaptureDeleteConfirmationButton(presentation: .island,
                                            title: CaptureInterfaceStrings.localized(l10n.language).delete,
                                            action: onDelete)
        }
        .fixedSize(horizontal: true, vertical: true)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(HUDBackdrop(cornerRadius: 12, contrast: .standard))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.7)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
    }

    /// Canonical floating controls, independent of how the preview opened.
    /// The thumbnail alone is the media drag source; the 10-point rim moves
    /// the panel. Island toolbar and preview layout are intentionally separate.
    private var floatingPreview: some View {
        VStack(spacing: 10) {
            ZStack {
                if let image = model.thumbnail {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .frame(width: 320, height: 138)
                        .clipped()
                        .background(Color.black.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                .allowsHitTesting(false)
                        }
                        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
                        .onTapGesture(count: 2, perform: onQuickLook)
                } else {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 320, height: 138)
                        .overlay(ProgressView().controlSize(.small))
                }

                VStack(spacing: 0) {
                    HStack(spacing: 5) {
                        thumbnailButton(symbol: "play.fill", title: CaptureInterfaceStrings.localized(l10n.language).quickLook, action: onQuickLook)
                        thumbnailButton(symbol: "square.and.arrow.up",
                                        title: screenshot.shareButton, action: onShare)
                            .background(ShelfSharePickerAnchor(anchor: shareAnchor))
                        if UserDefaults.standard.bool(forKey: DefaultsKey.recorderSharingEnabled) {
                            quickLinkFloatingControl
                        }
                        Spacer(minLength: 0)
                        thumbnailButton(symbol: "xmark", title: "\(screenshot.done)  (⎋)",
                                        action: onClose)
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 5) {
                        thumbnailButton(symbol: "scissors",
                                        title: "\(screenshot.editButton)  (⏎ / E)", action: onEdit)
                        Spacer(minLength: 0)
                        CaptureDeleteConfirmationButton(presentation: .floating,
                            title: CaptureInterfaceStrings.localized(l10n.language).delete, action: onDelete)
                    }
                }
                .padding(6)

                // Preserve the existing hover-only Copy / Save overlay.
                if isViewportHovered {
                    centerActions
                        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }
            }
            .frame(width: 320, height: 138)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .onHover { inside in isViewportHovered = inside }
        }
        .padding(10)
        .frame(width: 340, height: 158)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.22),
                        radius: 10, y: 4)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay { FloatingCapturePreviewDragBorder() }
    }



    @ViewBuilder
    private var quickLinkActions: some View {
        if model.sharedRecord != nil {
            Button(previewNotice.copyQuickLink, action: onCopyLink)
            Menu(CaptureInterfaceStrings.localized(l10n.language).createNewQuickLink) {
                quickLinkDurations
            }
        } else {
            quickLinkDurations
        }
    }

    private var quickLinkDurations: some View {
        ForEach(RecordingShareDuration.allCases) { duration in
            Button(duration.title(screenshot)) { onQuickLink(duration) }
        }
    }

    /// Use a normal Button (not a SwiftUI Menu label) so the icon's green
    /// status is rendered explicitly and cannot be overridden by macOS's
    /// borderless menu-button styling. Keep the button mounted while loading.
    private var quickLinkIslandControl: some View {
        Button(action: showQuickLinkMenu) {
            Group {
                if model.sharing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .medium))
                        .symbolRenderingMode(.monochrome)
                        .foregroundColor(model.sharedRecord != nil ? Color.blue : Color.primary)
                }
            }
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 8))
        .controlSize(.small)
        .focusable(false)
        .disabled(model.sharing)
        .screenshotSafeHelp(previewNotice.quickLink)
        .help(previewNotice.quickLink)
        .accessibilityLabel(previewNotice.quickLink)
    }

    private var quickLinkFloatingControl: some View {
        Button(action: showQuickLinkMenu) {
            Group {
                if model.sharing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 11, weight: .semibold))
                        .symbolRenderingMode(.monochrome)
                        .foregroundColor(model.sharedRecord != nil ? Color.blue : Color.white)
                }
            }
            .frame(width: 24, height: 24)
            .background(Color.black.opacity(0.65), in: Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .disabled(model.sharing)
        .screenshotSafeHelp(previewNotice.quickLink)
        .help(previewNotice.quickLink)
        .accessibilityLabel(previewNotice.quickLink)
    }

    /// AppKit snapshots this menu when it opens. SwiftUI state updates while
    /// export starts or the cache refreshes therefore cannot close it mid-tap.
    private func showQuickLinkMenu() {
        guard !model.sharing else { return }
        let menu = NSMenu()
        func add(_ title: String, to target: NSMenu, action: @escaping () -> Void) {
            let item = NSMenuItem(title: title,
                                  action: #selector(ScreenshotQuickPreviewMenuHelper.handleDurationAction(_:)),
                                  keyEquivalent: "")
            item.target = ScreenshotQuickPreviewMenuHelper.shared
            item.representedObject = action
            target.addItem(item)
        }
        func addDurations(to target: NSMenu) {
            for duration in RecordingShareDuration.allCases {
                add(duration.title(screenshot), to: target) { onQuickLink(duration) }
            }
        }
        if model.sharedRecord != nil {
            add(previewNotice.copyQuickLink, to: menu, action: onCopyLink)
            let item = NSMenuItem(title: CaptureInterfaceStrings.localized(l10n.language).createNewQuickLink, action: nil, keyEquivalent: "")
            let durations = NSMenu(title: CaptureInterfaceStrings.localized(l10n.language).createNewQuickLink)
            addDurations(to: durations)
            item.submenu = durations
            menu.addItem(item)
        } else {
            addDurations(to: menu)
        }
        // Protect the Island from outside-click dismissal while the native
        // popup and its submenus are open. End protection after the popup ends.
        onMenuChanged(true)
        defer { onMenuChanged(false) }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
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

/// A transparent border around floating capture previews. The NSView owns
/// window dragging; content inside the border keeps its own drag payload.
struct FloatingCapturePreviewDragBorder: View {
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                FloatingCapturePreviewDragHandle().frame(maxWidth: .infinity).frame(height: 8)
                Spacer(minLength: 0)
                FloatingCapturePreviewDragHandle().frame(maxWidth: .infinity).frame(height: 8)
            }
            HStack(spacing: 0) {
                FloatingCapturePreviewDragHandle().frame(width: 8).frame(maxHeight: .infinity)
                Spacer(minLength: 0)
                FloatingCapturePreviewDragHandle().frame(width: 8).frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct FloatingCapturePreviewDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> Handle { Handle() }
    func updateNSView(_ nsView: Handle, context: Context) {}

    final class Handle: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}
