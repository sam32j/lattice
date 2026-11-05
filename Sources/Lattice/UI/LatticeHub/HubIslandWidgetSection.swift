// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// Exclusive Dynamic Island widget section showing at most three tiles:
/// Now Playing, Calendar, and Timer, each with tinted icon and no text label.
struct HubIslandWidgetSection: View {
    @ObservedObject private var service = NotchService.shared
    @ObservedObject private var l10n = L10n.shared
    let isEditing: Bool

    struct WidgetItem: Identifiable {
        let id: NotchModule
        let symbol: String
        let tint: Color
        let title: String
    }

    private var items: [WidgetItem] {
        var result: [WidgetItem] = []
        if service.modules.contains(.music) {
            result.append(WidgetItem(
                id: .music,
                symbol: "waveform.mid",
                tint: .pink,
                title: "Now Playing"
            ))
        }
        if service.modules.contains(.calendar) {
            result.append(WidgetItem(
                id: .calendar,
                symbol: "calendar",
                tint: Color(red: 1, green: 0.36, blue: 0.39),
                title: NotchModule.calendar.title(l10n.language)
            ))
        }
        if service.modules.contains(.timer) {
            result.append(WidgetItem(
                id: .timer,
                symbol: "timer",
                tint: .orange,
                title: NotchModule.timer.title(l10n.language)
            ))
        }
        return result
    }

    var body: some View {
        let widgets = items
        if !widgets.isEmpty {
            HStack(spacing: 6) {
                ForEach(widgets) { item in
                    HubIslandWidgetTile(item: item, isEditing: isEditing) {
                        guard !isEditing else { return }
                        NotchService.shared.open(item.id)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: NotchLayout.hubWidgetTileHeight)
        }
    }
}

struct HubIslandWidgetTile: View {
    let item: HubIslandWidgetSection.WidgetItem
    let isEditing: Bool
    let onTap: () -> Void
    @State private var isHovered = false
    @ObservedObject private var music = NotchMusicService.shared
    @ObservedObject private var timer = NotchTimerService.shared

    @ViewBuilder private var iconView: some View {
        if item.id == .music {
            if music.playback?.isPlaying == true {
                NotchEqualizerBars(isPlaying: true, bars: 4, barWidth: 2.4, height: 16, tint: item.tint)
            } else {
                Image(systemName: item.symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(item.tint)
            }
        } else if item.id == .timer {
            if timer.session.isRunning {
                HubTimerWidgetIcon(tint: item.tint)
            } else {
                Image(systemName: item.symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(item.tint)
            }
        } else {
            Image(systemName: item.symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(item.tint)
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isHovered && !isEditing ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
                iconView
            }
            .frame(maxWidth: .infinity)
            .frame(height: NotchLayout.hubWidgetTileHeight)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(item.title)
        .accessibilityLabel(item.title)
        .onHover { hovering in
            if isHovered != hovering { isHovered = hovering }
        }
    }
}

private final class HubTimerDialCache {
    static let shared = HubTimerDialCache()
    let dialImage: NSImage

    init() {
        let config = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let baseImg = (NSImage(systemSymbolName: "timer", accessibilityDescription: nil) ?? NSImage())
            .withSymbolConfiguration(config) ?? NSImage()
        let rep = NSBitmapImageRep(data: baseImg.tiffRepresentation ?? Data())
        let w = CGFloat(rep?.pixelsWide ?? 24)
        let h = CGFloat(rep?.pixelsHigh ?? 24)
        let img = NSImage(size: NSSize(width: w, height: h), flipped: true) { rect in
            baseImg.draw(in: rect)
            guard let ctx = NSGraphicsContext.current?.cgContext else { return true }
            ctx.saveGState()
            ctx.setBlendMode(.clear)
            ctx.fillEllipse(in: CGRect(x: 11.0 - 6.8, y: 14.0 - 6.8, width: 13.6, height: 13.6))
            ctx.restoreGState()
            return true
        }
        img.isTemplate = true
        self.dialImage = img
    }
}

struct HubTimerWidgetIcon: View {
    let tint: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSpinning = false

    var body: some View {
        ZStack {
            Image(nsImage: HubTimerDialCache.shared.dialImage)
                .renderingMode(.template)
                .foregroundColor(tint)

            // Second hand needle pivoted at center (11, 14) of 24x24 symbol
            VStack(spacing: 0) {
                Capsule()
                    .fill(tint)
                    .frame(width: 1.6, height: 5.2)
                Color.clear
                    .frame(width: 1.6, height: 5.2)
            }
            .position(x: 11.0, y: 14.0)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))

            Circle()
                .fill(tint)
                .frame(width: 2.6, height: 2.6)
                .position(x: 11.0, y: 14.0)
        }
        .frame(width: 24, height: 24)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                isSpinning = true
            }
        }
        .onDisappear {
            isSpinning = false
        }
    }
}
