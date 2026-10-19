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
            if notchSize == nil { header }
            content
        }
        .onAppear { history.reload() }
        .confirmationDialog(text.clear,
                            isPresented: $confirmingClear,
                            titleVisibility: .visible) {
            Button(text.clear, role: .destructive) {
                history.clear()
            }
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label(text.title, systemImage: "clock.arrow.circlepath")
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
            .help(text.clear)
            .accessibilityLabel(text.clear)
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

    /// The dialog would hang from the island as a sheet; there it asks on its own.
    static func confirmClearAboveIsland() {
        DispatchQueue.main.async {
            let l10n = L10n.shared
            let text = FeatureStrings.recentCaptures(l10n.language)
            guard NSAlert.confirmAboveIsland(text.clear, message: "", action: text.clear, destructive: true,
                                             cancel: l10n.s.uninstallerCancel) else { return }
            RecentCaptureService.shared.clear()
        }
    }

    private static let captureTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let captureDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    static func formattedCaptureTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return captureTimeFormatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            let timeStr = captureTimeFormatter.string(from: date)
            return "Yesterday, \(timeStr)"
        } else {
            return captureDateTimeFormatter.string(from: date)
        }
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
        VStack(alignment: .leading, spacing: 6) {
            Button {
                history.open(entry)
            } label: {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.black.opacity(0.2))
                        if let image = history.thumbnail(for: entry) {
                            Image(nsImage: image)
                                .resizable()
                                .interpolation(.high)
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else {
                            Image(systemName: entry.kind == .screenshot ? "photo" : "film")
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(.tertiary)
                        }
                        if entry.kind == .recording {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.85))
                                .shadow(radius: 2)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

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
                .contentShape(Rectangle())
            }
            .buttonStyle(NotchButtonStyle(cornerRadius: 8, lifts: false))

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

                Button {
                    history.open(entry)
                } label: {
                    Text(entry.kind == .screenshot ? text.restore : text.open)
                        .font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)

                Button {
                    history.remove(entry)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9.5))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help(text.remove)
                .accessibilityLabel(text.remove)
            }
            .padding(.horizontal, 2)
        }
        .padding(8)
        .frame(width: 165)
        .frame(maxHeight: .infinity)
        .modifier(NotchControlSurface(cornerRadius: 12))
    }

    private func row(_ entry: RecentCaptureEntry) -> some View {
        HStack(spacing: 10) {
            preview(entry)
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
                HStack(spacing: 6) {
                    Button(entry.kind == .screenshot ? text.restore : text.open) {
                        history.open(entry)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    Button {
                        history.remove(entry)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .help(text.remove)
                    .accessibilityLabel(text.remove)
                }
            }
            Spacer(minLength: 0)
        }
        .panelCard()
    }

    @ViewBuilder
    private func preview(_ entry: RecentCaptureEntry) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.black.opacity(0.13))
            if let image = history.thumbnail(for: entry) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            } else {
                Image(systemName: entry.kind == .screenshot ? "photo" : "film")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 104, height: 68)
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
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
