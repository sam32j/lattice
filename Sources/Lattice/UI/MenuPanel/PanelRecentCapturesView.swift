// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The same history surface is used by the menu panel and by the floating
/// palette opened from editors and the Command Bar.
struct RecentCapturesView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var history = RecentCaptureService.shared
    @Environment(\.notchPresentation) private var inNotch
    @State private var confirmingClear = false
    static var floatingMinimumHeight: CGFloat { RecentCaptureIslandRow.threePreviewHeight }

    var onClose: (() -> Void)?
    var showHeader: Bool = true
    /// The island uses the same compact vertical rows as the capture history.
    var notchSize: CGSize? = nil
    /// The standalone palette fills its fixed window; the menu-panel list
    /// retains its compact intrinsic size.
    var fillsAvailableSpace = false

    private var text: RecentCaptureStrings {
        FeatureStrings.recentCaptures(l10n.language)
    }

    // Recent Captures remains browsable regardless of capture-tool availability.
    private var visibleEntries: [RecentCaptureEntry] { history.entries }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showHeader && notchSize == nil {
                header
            } else if !showHeader && notchSize == nil && !fillsAvailableSpace {
                clearBar
            }
            content
                .frame(maxWidth: .infinity,
                       maxHeight: fillsAvailableSpace ? .infinity : nil,
                       alignment: .topLeading)
        }
        .frame(maxWidth: .infinity,
               maxHeight: fillsAvailableSpace ? .infinity : nil,
               alignment: .topLeading)
        .onAppear { history.reload() }
        .confirmationDialog(CaptureInterfaceStrings.localized(L10n.shared.language).deleteRecentTitle,
                            isPresented: $confirmingClear,
                            titleVisibility: .visible) {
            Button(CaptureInterfaceStrings.localized(L10n.shared.language).deleteAll, role: .destructive) {
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
            .help(CaptureInterfaceStrings.localized(L10n.shared.language).deleteCaptures)
            .accessibilityLabel(CaptureInterfaceStrings.localized(L10n.shared.language).deleteCaptures)
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
                Label(CaptureInterfaceStrings.localized(L10n.shared.language).deleteCaptures, systemImage: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(visibleEntries.isEmpty)
        }
        .padding(.horizontal, 4)
    }

    /// The floating Hub is a borderless non-activating NSPanel. Presenting a
    /// SwiftUI sheet from it fails on some macOS versions and its window-focus
    /// monitors can then dismiss the Hub while the presentation is pending.
    /// Run a standalone native alert with those monitors temporarily removed.
    static func confirmClearAboveFloatingHUD() {
        // Match the Island's early collapse protection: protect the floating
        // panel before deferring presentation to the next SwiftUI run loop.
        let hub = LatticeHubService.shared
        guard let panel = hub.panel, panel.isVisible else { return }
        hub.removeMonitors()
        DispatchQueue.main.async {
            defer {
                if panel.isVisible {
                    hub.installMonitors(for: panel)
                    panel.makeKey()
                }
            }
            // The Hub can close between the click and this turn. A pending
            // confirmation then goes with it instead of appearing on its own.
            guard panel.isVisible, !RecentCaptureService.shared.entries.isEmpty else { return }
            let strings = CaptureInterfaceStrings.localized(L10n.shared.language)
            guard confirmDestructiveAboveFloatingHUD(panel,
                title: strings.deleteRecentTitle, message: deletionWarning,
                action: strings.deleteAll, cancel: L10n.shared.s.uninstallerCancel
            ) else { return }
            RecentCaptureService.shared.clearAndDeleteCaptureFiles { result in
                guard !result.succeeded else { return }
                DispatchQueue.main.async {
                    let failure = NSAlert()
                    failure.alertStyle = .warning
                    failure.messageText = CaptureInterfaceStrings.localized(L10n.shared.language).deleteRecentFailureTitle
                    failure.informativeText = CaptureInterfaceStrings.localized(L10n.shared.language).deleteRecentFailureBody
                    failure.addButton(withTitle: "OK")
                    _ = runAboveFloatingHUD(failure)
                }
            }
        }
    }

    /// Uses the same native destructive presenter as the Island and Trash.
    /// The caller holds the floating Hub's dismissal monitors until return.
    private static func confirmDestructiveAboveFloatingHUD(
        _ panel: NSPanel, title: String, message: String, action: String, cancel: String
    ) -> Bool {
        NotchIslandAlert.confirmDestructive(
            title: title, message: message, action: action,
            cancel: cancel, above: panel)
    }

    /// Suspend the Hub's outside-click and focus-loss monitors for the entire
    /// modal lifetime, then reinstall them only if the Hub remains visible.
    /// This also restores normal menu-bar reopening after Cancel or Delete.
    private static func runAboveFloatingHUD(_ alert: NSAlert) -> NSApplication.ModalResponse? {
        let hub = LatticeHubService.shared
        guard let panel = hub.panel, panel.isVisible else { return nil }
        hub.removeMonitors()
        defer {
            if panel.isVisible {
                hub.installMonitors(for: panel)
                panel.makeKey()
            }
        }
        return NotchIslandAlert.run(alert, above: panel)
    }

    /// Confirm deletion of the on-disk captures as well as the history index.
    private static var islandClearConfirmationPending = false

    static func confirmClearAboveIsland() {
        // Keep the same visible owner for the entire modal. Re-reading the
        // presentation window after deferral could lose the owner and its
        // focus protection. Also prevent a second queued native modal.
        let notch = NotchService.shared
        guard !islandClearConfirmationPending,
              let island = notch.presentationWindow, island.isVisible else { return }
        islandClearConfirmationPending = true
        notch.beginIslandConfirmation()
        DispatchQueue.main.async {
            defer {
                islandClearConfirmationPending = false
                notch.endIslandConfirmation()
            }
            let l10n = L10n.shared
            guard island.isVisible, !RecentCaptureService.shared.entries.isEmpty else { return }
            let strings = CaptureInterfaceStrings.localized(l10n.language)
            guard NotchIslandAlert.confirmDestructive(
                title: strings.deleteRecentTitle,
                message: deletionWarning,
                action: strings.deleteAll,
                cancel: l10n.s.uninstallerCancel,
                above: island) else { return }
            RecentCaptureService.shared.clearAndDeleteCaptureFiles { result in
                reportDeletionResult(result, aboveIsland: true)
            }
        }
    }

    static var deletionWarning: String {
        CaptureInterfaceStrings.localized(L10n.shared.language).deleteRecentWarning
    }

    static func reportDeletionResult(_ result: RecentCaptureService.CaptureDeletionResult,
                                              aboveIsland: Bool) {
        guard !result.succeeded else { return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = CaptureInterfaceStrings.localized(L10n.shared.language).deleteRecentFailureTitle
        alert.informativeText = CaptureInterfaceStrings.localized(L10n.shared.language).deleteRecentFailureBody
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
        if visibleEntries.isEmpty, fillsAvailableSpace || notchSize != nil {
            // The floating Hub or the island is the container: no card inside it.
            Text(text.empty)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if visibleEntries.isEmpty {
            Text(text.empty)
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .frame(height: fillsAvailableSpace ? nil : (notchSize == nil ? 92 : nil))
                .frame(maxHeight: fillsAvailableSpace || notchSize != nil ? .infinity : nil)
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
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: fillsAvailableSpace ? 10 : 7) {
                        ForEach(visibleEntries) { entry in
                            // The floating Hub has the room to show each capture
                            // as a preview with its actions, with no extra step.
                            Group {
                                if fillsAvailableSpace { previewRow(entry) } else { row(entry) }
                            }
                            .id(entry.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.vertical, fillsAvailableSpace ? HubScrollEdge.inset : 0)
                }
                .onAppear {
                    // Back from editing a capture: open where that capture is.
                    guard fillsAvailableSpace, let id = history.revealEntryID else { return }
                    history.revealEntryID = nil
                    DispatchQueue.main.async { proxy.scrollTo(id, anchor: .center) }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: .infinity,
                   maxHeight: fillsAvailableSpace ? .infinity : 300)
            .hubScrollEdgeFade(fillsAvailableSpace)
        }
    }

    private func islandCard(_ entry: RecentCaptureEntry) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            RecentCapturePreviewThumbnail(
                entry: entry,
                history: history,
                onOpen: { history.open(entry, inNotch: notchSize != nil) },
                width: 149,
                height: 100,
                cornerRadius: 8,
                showsKindBadge: true,
                text: text,
                enablesImageDrag: true
            )

            HStack(spacing: 4) {
                Text(Self.formattedCaptureTime(entry.createdAt))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
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

    private func previewRow(_ entry: RecentCaptureEntry) -> some View {
        RecentCaptureIslandRow(entry: entry, history: history, text: text,
                               time: Self.formattedCaptureTime(entry.createdAt))
    }

    private func row(_ entry: RecentCaptureEntry) -> some View {
        HStack(spacing: 10) {
            RecentCapturePreviewThumbnail(
                entry: entry,
                history: history,
                onOpen: { history.open(entry, inNotch: notchSize != nil) },
                width: 104,
                height: 68,
                cornerRadius: 7,
                showsKindBadge: false,
                text: text
            )
            VStack(alignment: .leading, spacing: 5) {
                Text(entry.kind == .screenshot ? text.screenshot : text.recording)
                    .font(.system(size: 11.5, weight: .semibold))
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

/// One capture in the floating Hub's history, laid out like the Dynamic
/// Island's quick preview: the image fills the card and the island's control
/// strip floats over it. Hovering the image shows a Quick Look badge without
/// touching the strip; a click opens the capture in Quick Look. Nothing here
/// opens a floating preview.
private struct RecentCaptureIslandRow: View {
    let entry: RecentCaptureEntry
    @ObservedObject var history: RecentCaptureService
    let text: RecentCaptureStrings
    let time: String
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var featureRuntime = FeatureRuntime.shared
    @State private var imageHovered = false
    @State private var lastOpened: TimeInterval = 0
    @State private var rowWidth: CGFloat = 388
    private let shareAnchor = ShelfSharePickerAnchor.Anchor()

    static let imageHeight: CGFloat = 150
    /// Three previews and the gaps between them.
    static let threePreviewHeight: CGFloat = imageHeight * 3 + 10 * 2
    private var isScreenshot: Bool { entry.kind == .screenshot }
    private var screenshot: ScreenshotFeatureStrings { FeatureStrings.screenshot(l10n.language) }
    private var recorder: RecorderFeatureStrings { FeatureStrings.recorder(l10n.language) }

    var body: some View {
        artwork
            .frame(maxWidth: .infinity)
            .frame(height: Self.imageHeight)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                    .allowsHitTesting(false)
            }
            .overlay {
                hoverBadge
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .onHover { imageHovered = $0 }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
            .onTapGesture(perform: openQuickLook)
            // The dragged image is the artwork alone, never the hover HUD.
            .onDrag { history.dragItemProvider(for: entry) ?? NSItemProvider() } preview: {
                artwork
                    .frame(width: rowWidth, height: Self.imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            // On the image only: the toolbar above it shows each tool's own tip.
            .help(CaptureInterfaceStrings.localized(l10n.language).quickLook)
            .overlay(alignment: .topTrailing) { toolbar.padding(6) }
            .overlay(alignment: .topLeading) {
                Text(time)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(6)
                    .allowsHitTesting(false)
            }
    }

    @ViewBuilder private var artwork: some View {
        // The row's size comes from its frame, never from the image: a
        // filled wide, short capture would otherwise widen the row past the
        // panel and push the toolbar out of view.
        Color.black.opacity(0.13).overlay {
            if let image = history.thumbnail(for: entry) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                Image(systemName: isScreenshot ? "photo" : "film")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Drawn above the image and below the strip; it never takes clicks.
    @ViewBuilder private var hoverBadge: some View {
        if imageHovered {
            ZStack {
                Color.black.opacity(0.22)
                Image(systemName: isScreenshot ? "eye.fill" : "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(HUDBackdrop(cornerRadius: 22, contrast: .standard))
            }
            .transition(.opacity.animation(.easeOut(duration: 0.12)))
            .allowsHitTesting(false)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 3) {
            tool("doc.on.doc", isScreenshot ? screenshot.copyButton : recorder.copyButton) {
                history.perform(.copy, on: entry)
            }
            tool("square.and.arrow.down", isScreenshot ? screenshot.saveButton : recorder.saveButton) {
                history.perform(.save, on: entry)
            }
            if isScreenshot {
                tool("mappin", screenshot.pinButton) { history.perform(.pin, on: entry) }
                if featureRuntime.isAvailable(.screenOCR) {
                    tool("text.viewfinder", screenshot.copyTextButton) { history.perform(.copyText, on: entry) }
                }
            }
            separator
            tool("square.and.arrow.up", screenshot.shareButton, action: share)
                .background(ShelfSharePickerAnchor(anchor: shareAnchor))
            separator
            tool(isScreenshot ? "pencil" : "scissors", screenshot.editButton) { history.perform(.edit, on: entry) }
            CaptureDeleteConfirmationButton(presentation: .island, title: text.remove) {
                history.remove(entry)
            }
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

    private var separator: some View {
        Rectangle().fill(Color.white.opacity(0.18)).frame(width: 1, height: 16).padding(.horizontal, 2)
    }

    private func tool(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 8))
        .controlSize(.small)
        .focusable(false)
        .help(title)
        .accessibilityLabel(title)
    }

    /// A second click of a double click lands while Quick Look opens; it is
    /// ignored rather than closing and reopening the preview.
    private func openQuickLook() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastOpened > NSEvent.doubleClickInterval else { return }
        lastOpened = now
        history.quickLook(entry)
    }

    private func share() {
        let anchor = shareAnchor
        history.shareFile(for: entry) { url in
            guard let url, anchor.present([url]) else { NSSound.beep(); return }
        }
    }
}

private struct RecentCaptureTrashButton: View {
    let action: () -> Void
    let helpText: String

    var body: some View {
        CaptureDeleteConfirmationButton(presentation: .history, title: helpText,
                                        action: action)
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

/// Shared two-click deletion with a three-second minimum armed state.
struct CaptureDeleteConfirmationButton: View {
    enum Presentation { case floating, island, history }
    let presentation: Presentation
    let title: String
    let action: () -> Void
    @State private var armed = false
    @State private var hovered = false
    @State private var armedAt: Date?
    @State private var disarmWork: DispatchWorkItem?

    private let confirmAnimation = Animation.easeInOut(duration: 0.08)
    private let minimumArmedDuration: TimeInterval = 3

    private var width: CGFloat { presentation == .island ? 28 : 24 }
    private var height: CGFloat { presentation == .history ? 22 : width }
    private var radius: CGFloat { presentation == .island ? 8 : 5 }

    private var backdrop: Color {
        if armed { return .red }
        switch presentation {
        case .floating: return Color.black.opacity(0.65)
        case .island: return Color.white.opacity(0.07)
        case .history: return hovered ? Color.primary.opacity(0.10) : Color.primary.opacity(0.06)
        }
    }
    private var stroke: Color {
        if armed { return .red }
        switch presentation {
        case .floating: return Color.red.opacity(0.42)
        case .island: return Color.white.opacity(0.12)
        case .history: return Color.clear
        }
    }

    private var iconColor: Color {
        if armed { return .white }
        switch presentation {
        case .floating: return .red
        case .island: return .primary
        case .history: return hovered ? .primary : .secondary
        }
    }

    private func resetConfirmation() {
        disarmWork?.cancel()
        disarmWork = nil
        armedAt = nil
        withAnimation(confirmAnimation) { armed = false }
    }

    private func hoverChanged(_ inside: Bool) {
        hovered = inside
        disarmWork?.cancel()
        disarmWork = nil
        guard !inside, armed else { return }
        let elapsed = Date().timeIntervalSince(armedAt ?? Date())
        let remaining = max(0, minimumArmedDuration - elapsed)
        guard remaining > 0 else {
            resetConfirmation()
            return
        }
        let work = DispatchWorkItem {
            if !hovered && armed { resetConfirmation() }
        }
        disarmWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: work)
    }

    var body: some View {
        Button {
            guard armed else {
                disarmWork?.cancel()
                disarmWork = nil
                armedAt = Date()
                withAnimation(confirmAnimation) { armed = true }
                return
            }
            resetConfirmation()
            action()
        } label: {
            Image(systemName: armed ? "checkmark" : "trash")
                .font(.system(size: presentation == .island ? 14 : 11, weight: .semibold))
                .foregroundStyle(iconColor)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: width, height: height)
                .background {
                    if presentation == .floating {
                        Circle().fill(backdrop)
                    } else {
                        RoundedRectangle(cornerRadius: radius, style: .continuous).fill(backdrop)
                    }
                }
                .overlay {
                    if presentation == .floating {
                        Circle().strokeBorder(stroke, lineWidth: 0.8)
                    } else {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(stroke, lineWidth: 0.8)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover(perform: hoverChanged)
        .onDisappear {
            disarmWork?.cancel()
            disarmWork = nil
            armed = false
            armedAt = nil
        }
        .help(armed ? CaptureInterfaceStrings.localized(L10n.shared.language).clickAgain : title)
        .accessibilityLabel(armed ? CaptureInterfaceStrings.localized(L10n.shared.language).confirmDelete : title)
    }
}
