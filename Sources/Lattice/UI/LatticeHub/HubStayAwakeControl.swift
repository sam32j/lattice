// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// The icon and the countdown share a horizontal centerline. The toggle's
/// height never depends on session state, so the bolt cannot jump vertically.
struct HubStayAwakeControl: View {
    var height: CGFloat
    var iconSize: CGFloat
    var isEditing: Bool
    var onHide: () -> Void
    @ObservedObject private var awake = KeepAwakeManager.shared
    @ObservedObject private var hub = LatticeHubService.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var showingOptions = false
    private func toggleLabel(now: Date, textSize: CGFloat) -> some View {
        HStack(spacing: 3) {
            Image(systemName: awake.isActive ? "bolt.fill" : "bolt")
                .font(.system(size: iconSize, weight: .semibold))
            if awake.isActive {
                Text(HubStayAwakeSupport.compact(end: awake.endDate, now: now))
                    .font(.system(size: textSize, weight: .medium)).monospacedDigit()
                    .lineLimit(1)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let status = HubStayAwakePopover.status(awake, now: context.date, l10n: l10n)
            HStack(spacing: 0) {
                Button {
                    if !isEditing {
                        awake.toggleFromHub()
                        HubStayAwakePopover.announce(awake, l10n: l10n)
                    }
                } label: {
                    ViewThatFits(in: .horizontal) {
                        toggleLabel(now: context.date, textSize: height < 30 ? 8 : 9)
                        toggleLabel(now: context.date, textSize: 7)
                    }
                    .padding(.horizontal, 4)
                    .foregroundStyle(awake.isActive ? Color.orange : Color.primary.opacity(0.85))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(awake.isActive ? "Stop Stay Awake" : "Start Stay Awake for 1 hour")
                .accessibilityValue(status)

                Rectangle().fill(Color.primary.opacity(0.12)).frame(width: 1, height: height * 0.45)
                Button {
                    if !isEditing { showingOptions.toggle() }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: height < 30 ? 13 : 16, height: height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stay Awake options")
                .accessibilityValue(showingOptions ? "Open" : "Closed")
                .popover(isPresented: $showingOptions, arrowEdge: .bottom) {
                    HubStayAwakePopover()
                }
            }
            .frame(minWidth: height < 30 ? 58 : 66, maxWidth: .infinity)
            .frame(height: height)
            .background(awake.isActive ? Color.orange.opacity(0.15) : Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: max(7, height * 0.28)))
            .overlay(alignment: .topTrailing) {
                if isEditing {
                    Button(action: onHide) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: max(10, iconSize), weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Hide Stay Awake")
                    .offset(x: 3, y: -3)
                }
            }
        }
        .background(WindowVisibilityReader { visible in
            if !visible { showingOptions = false }
        })
        .help(l10n.s.keepAwakeTitle)
        .onChange(of: showingOptions) { _, shown in
            hub.stayAwakeOptionsPresented = shown
        }
        .onChange(of: hub.stayAwakeOptionsPresented) { _, shown in
            if !shown { showingOptions = false }
        }
        .onChange(of: isEditing) { _, editing in
            if editing { showingOptions = false }
        }
        .onDisappear {
            showingOptions = false
            hub.stayAwakeOptionsPresented = false
        }
    }
}
