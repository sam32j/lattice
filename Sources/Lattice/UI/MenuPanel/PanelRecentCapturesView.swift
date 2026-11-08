// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct PanelRecentCapturesView: View {
    var onClose: () -> Void

    var body: some View {
        RecentCapturesView(onClose: onClose)
        .onAppear {
            PanelInteractionState.shared.viewKeepsPopoverOpen = true
        }
        .onDisappear { PanelInteractionState.shared.viewKeepsPopoverOpen = false }
    }
}

/// The same history surface is used by the menu panel and by the floating
/// palette opened from editors and the Command Bar.
struct RecentCapturesView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var history = RecentCaptureService.shared
    @Environment(\.notchPresentation) private var inNotch
    @State private var confirmingClear = false

    var onClose: (() -> Void)?
    var showHeader: Bool = true
    /// The island uses the same compact vertical rows as the capture history.
    var notchSize: CGSize? = nil

    private var text: RecentCaptureStrings {
        FeatureStrings.recentCaptures(l10n.language)
    }

    private var visibleEntries: [RecentCaptureEntry] { Self.visible(history.entries) }

    static func visible(_ entries: [RecentCaptureEntry]) -> [RecentCaptureEntry] {
        entries.filter { entry in
            entry.kind == .screenshot
                ? AppFeature.screenshot.isAvailable
                : AppFeature.screenRecorder.isAvailable
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showHeader && notchSize == nil {
                header
            } else if !showHeader && notchSize == nil {
                clearBar
            }
            content
        }
        .onAppear { history.reload() }
        .confirmationDialog("Delete recent captures?",
                            isPresented: $confirmingClear,
                            titleVisibility: .visible) {
            Button("Delete Captures", role: .destructive) {
                history.clearAndDeleteCaptureFiles { result in
                    Self.reportDeletionResult(result, aboveIsland: false)
                }
            }
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
        } message: {
            Text(Self.deletionWarning)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label(text.title, systemImage: "photo.stack")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            Button {
                if inNotch { Self.confirmClearAboveIsland() } else { confirmingClear = true }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Delete Captures")
            .accessibilityLabel("Delete Captures")
            .disabled(visibleEntries.isEmpty)
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(l10n.s.uninstallerCancel)
                .accessibilityLabel(l10n.s.uninstallerCancel)
            }
        }
    }

    private var clearBar: some View {
        HStack {
            Spacer()
            Button {
                confirmingClear = true
            } label: {
                Label("Delete Captures", systemImage: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(visibleEntries.isEmpty)
        }
        .padding(.horizontal, 4)
    }

    /// Confirm deletion of the on-disk captures as well as the history index.
    static func confirmClearAboveIsland() {
        DispatchQueue.main.async {
            let l10n = L10n.shared
            let text = FeatureStrings.recentCaptures(l10n.language)
            guard !visible(RecentCaptureService.shared.entries).isEmpty else { return }
            let alert = NSAlert()
            alert.messageText = "Delete recent captures?"
            alert.informativeText = deletionWarning
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Delete Captures").hasDestructiveAction = true
            alert.addButton(withTitle: l10n.s.uninstallerCancel).keyEquivalent = "\u{1b}"
            guard NotchIslandAlert.run(alert, above: NotchService.shared.presentationWindow)
                == .alertFirstButtonReturn else { return }
            RecentCaptureService.shared.clearAndDeleteCaptureFiles { result in
                reportDeletionResult(result, aboveIsland: true)
            }
        }
    }

    private static let deletionWarning = """
        This deletes the screenshots, editable copies, cached previews and stashed recordings stored by Recent Captures. Recordings saved elsewhere will be moved to Trash. Separately exported screenshots are not affected.
        """

    private static func reportDeletionResult(_ result: RecentCaptureService.CaptureDeletionResult,
                                              aboveIsland: Bool) {
        guard !result.succeeded else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Some recent captures could not be deleted"
        alert.informativeText = "Some files or history entries could not be removed. Check file permissions and try again."
        alert.addButton(withTitle: "OK")
        if aboveIsland {
            _ = NotchIslandAlert.run(alert, above: NotchService.shared.presentationWindow)
        } else {
            _ = alert.runModal()
        }
    }

    static func formattedCaptureTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = L10n.shared.language.formattingLocale()
        formatter.timeStyle = .short
        if calendar.isDateInToday(date) {
            formatter.dateStyle = .none
        } else if calendar.isDateInYesterday(date) {
            formatter.dateStyle = .medium
            formatter.doesRelativeDateFormatting = true
        } else {
            formatter.dateStyle = .short
        }
        return formatter.string(from: date)
    }

    @ViewBuilder
    private var content: some View {
        if visibleEntries.isEmpty {
            Text(text.empty)
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: notchSize == nil ? 92 : nil)
                .frame(maxHeight: notchSize == nil ? nil : .infinity)
                .panelCard()
        } else if let notchSize {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(visibleEntries) { entry in
                        islandCard(entry)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .frame(width: notchSize.width, height: notchSize.height)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 7) {
                    ForEach(visibleEntries) { entry in
                        row(entry)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
    }

    private func islandCard(_ entry: RecentCaptureEntry) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            RecentCapturePreviewThumbnail(
                entry: entry,
                history: history,
                onOpen: { history.open(entry, inNotch: inNotch) },
                width: 149,
                height: 100,
                cornerRadius: 8,
                showsKindBadge: true,
                text: text,
                enablesImageDrag: true
            )

            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    if entry.kind == .recording, let name = entry.recordingURL?.lastPathComponent {
                        Text(name)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Text(Self.formattedCaptureTime(entry.createdAt))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)

                RecentCaptureTrashButton(
                    action: { history.remove(entry) },
                    helpText: text.remove
                )
            }
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(width: 165)
        .modifier(NotchControlSurface(cornerRadius: 12))
    }

    private func row(_ entry: RecentCaptureEntry) -> some View {
        HStack(spacing: 10) {
            RecentCapturePreviewThumbnail(
                entry: entry,
                history: history,
                onOpen: { history.open(entry, inNotch: inNotch) },
                width: 104,
                height: 68,
                cornerRadius: 7,
                showsKindBadge: false,
                text: text
            )
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.kind == .screenshot ? text.screenshot : text.recording)
                    .font(.system(size: 11.5, weight: .semibold))
                if entry.kind == .recording, let name = entry.recordingURL?.lastPathComponent {
                    Text(name)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text(Self.formattedCaptureTime(entry.createdAt))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            RecentCaptureTrashButton(
                action: { history.remove(entry) },
                helpText: text.remove
            )
        }
        .panelCard()
    }
}

private struct RecentCaptureTrashButton: View {
    let action: () -> Void
    let helpText: String
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "trash")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isHovered ? Color.red : Color.secondary)
                .frame(width: 24, height: 22)
                .background(
                    isHovered ? Color.red.opacity(0.18) : Color.primary.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 5, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(isHovered ? Color.red.opacity(0.40) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(helpText)
        .accessibilityLabel(helpText)
    }
}

private struct RecentCapturePreviewThumbnail: View {
    let entry: RecentCaptureEntry
    @ObservedObject var history: RecentCaptureService
    let onOpen: () -> Void
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let showsKindBadge: Bool
    let text: RecentCaptureStrings
    var enablesImageDrag = false
    @State private var isHovered = false

    @ViewBuilder var body: some View {
        if enablesImageDrag && entry.kind == .screenshot {
            thumbnailButton.onDrag {
                history.dragItemProvider(for: entry) ?? NSItemProvider()
            } preview: {
                // Drag only the image artwork, not the card's badge, hover eye,
                // dimming overlay, or focus outline. The payload remains the
                // original full-resolution PNG from dragItemProvider(for:).
                thumbnailArtwork
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        } else {
            thumbnailButton
        }
    }

    private var thumbnailArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.13))
            if let image = history.thumbnail(for: entry) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                Image(systemName: entry.kind == .screenshot ? "photo" : "film")
                    .font(.system(size: min(width, height) * 0.32, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: width, height: height)
    }

    private var thumbnailButton: some View {
        Button(action: onOpen) {
            ZStack {
                thumbnailArtwork

                if entry.kind == .recording && !isHovered {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.85))
                        .shadow(radius: 2)
                }

                if showsKindBadge {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 3) {
                                Image(systemName: entry.kind == .screenshot ? "camera.fill" : "video.fill")
                                    .font(.system(size: 8))
                                Text(entry.kind == .screenshot ? text.screenshot : text.recording)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.6), in: Capsule())
                            .padding(6)
                        }
                        Spacer()
                    }
                }

                if isHovered {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.42))
                        .transition(.opacity.animation(.easeInOut(duration: 0.12)))

                    Image(systemName: "eye.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 4, y: 1)
                        .transition(.scale(scale: 0.88).combined(with: .opacity).animation(.spring(response: 0.22, dampingFraction: 0.75)))
                }
            }
            .frame(width: width, height: height)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(isHovered ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.1), lineWidth: isHovered ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(entry.kind == .screenshot ? text.restore : text.open)
        .accessibilityLabel(entry.kind == .screenshot ? text.restore : text.open)
    }
}

/// Borderless palette content. Its compact fixed width keeps the same list
/// readable over either editor without covering the work area.
struct RecentCapturesWindowView: View {
    var onClose: () -> Void

    var body: some View {
        RecentCapturesView(onClose: onClose)
            .padding(14)
            .frame(width: 440)
            .background(HUDBackdrop(cornerRadius: 18, contrast: .high))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
