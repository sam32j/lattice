// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
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
    private var text: KeepAwakeHubStrings { FeatureStrings.keepAwakeHub(l10n.language) }
    private var locale: Locale { l10n.language.formattingLocale() }
    @State private var showingOptions = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    /// Width of the toggle's left half, the stage the bolt and countdown share;
    /// its right edge is the separator, which the countdown emerges from.
    @State private var stageWidth: CGFloat = 0
    /// What the toggle draws once settled.
    @State private var shownActive = KeepAwakeManager.shared.isActive
    /// The end the countdown reads. Stopping clears the session's end before
    /// it clears isActive, so the fading number keeps the last real end
    /// instead of turning into an infinity sign; nil only for a genuinely
    /// open-ended session.
    @State private var shownEnd = KeepAwakeManager.shared.endDate
    /// When the running start or stop motion began; nil once it settles.
    @State private var motionStart: Date?
    @State private var motionGeneration = 0
    private static let gap: CGFloat = 3
    private static let inset: CGFloat = 4

    private enum Glyph: Hashable { case outline, filled }

    private func countdownWidth(_ string: String, size: CGFloat) -> CGFloat {
        let font = HubStayAwakeCountdownPath.font(size: size)
        return ceil((string as NSString).size(withAttributes: [.font: font]).width)
    }

    private var boltWidth: CGFloat {
        let config = NSImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold)
        return NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)?.size.width ?? iconSize
    }

    /// The larger countdown when the bolt, the gap and it fit inside the stage.
    private func countdownSize(for string: String) -> CGFloat {
        let large: CGFloat = height < 30 ? 8 : 9
        let room = stageWidth - Self.inset * 2 - boltWidth - Self.gap
        return stageWidth == 0 || countdownWidth(string, size: large) <= room ? large : 7
    }

    private func startMotion() {
        motionGeneration += 1
        let generation = motionGeneration
        motionStart = Date()
        // The session's own follow-up work (the lid-sleep flag, for one)
        // writes preferences mid-slide; their island resync waits it out.
        InterfaceMotionHold.hold(for: HubStayAwakeMotion.duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + HubStayAwakeMotion.duration) {
            if motionGeneration == generation { motionStart = nil }
        }
    }

    private func pixel(_ value: CGFloat) -> CGFloat {
        let scale = max(1, displayScale)
        return (value * scale).rounded() / scale
    }

    /// The bolt and countdown, drawn into one canvas. Separate views were
    /// snapped to whole pixels each frame, so the slow end of the slide moved
    /// in visible steps, and the crossfading bolts were composited as extra
    /// layers; a canvas draws both at fractional positions in one pass.
    private func stage(now: Date) -> some View {
        let countdown = HubStayAwakeSupport.compact(end: shownEnd, now: now, locale: locale)
        let size = countdownSize(for: countdown)
        let active = shownActive
        // The countdown stays drawn while it fades away on a stop.
        let showsCountdown = active || motionStart != nil
        let start = motionStart
        let shape = showsCountdown ? HubStayAwakeCountdownPath.shape(countdown, pointSize: size) : nil
        return TimelineView(.animation(minimumInterval: nil, paused: start == nil)) { context in
            Canvas { graphics, canvasSize in
                guard let outline = graphics.resolveSymbol(id: Glyph.outline),
                      let filled = graphics.resolveSymbol(id: Glyph.filled) else { return }
                let number = shape
                let boltSize = filled.size
                let numberWidth = number?.size.width ?? 0
                let frame = start.map {
                    HubStayAwakeMotion.frame(starting: active, elapsed: context.date.timeIntervalSince($0),
                                             stageWidth: canvasSize.width, boltWidth: boltSize.width,
                                             countdownWidth: numberWidth, gap: Self.gap)
                } ?? HubStayAwakeMotion.resting(active: active)
                // The settled layout, aligned to whole pixels so the resting
                // toggle is as sharp as before; motion offsets end at zero.
                let content = number == nil ? boltSize.width : boltSize.width + Self.gap + numberWidth
                let left = pixel((canvasSize.width - content) / 2)
                let boltX = left + (number == nil ? 0 : frame.boltOffset)
                let boltY = pixel((canvasSize.height - boltSize.height) / 2)
                if frame.boltFill < 1 {
                    var layer = graphics
                    layer.opacity = 1 - frame.boltFill
                    layer.draw(outline, at: CGPoint(x: boltX, y: boltY), anchor: .topLeading)
                }
                if frame.boltFill > 0 {
                    var layer = graphics
                    layer.opacity = frame.boltFill
                    layer.draw(filled, at: CGPoint(x: boltX, y: boltY), anchor: .topLeading)
                }
                if let number, frame.countdownOpacity > 0 {
                    var layer = graphics
                    layer.opacity = frame.countdownOpacity
                    // Settled on whole pixels like the bolt; while it moves the
                    // outlines are filled at the exact position, every digit
                    // travelling together with even edges.
                    let x = pixel(left + boltSize.width + Self.gap) + frame.countdownOffset
                    let y = pixel((canvasSize.height - number.size.height) / 2)
                    // On a stop it shrinks about its own centre as it fades.
                    let centre = CGPoint(x: x + number.size.width / 2, y: y + number.size.height / 2)
                    let placed = number.path.offsetBy(dx: x, dy: y).applying(
                        CGAffineTransform(translationX: centre.x, y: centre.y)
                            .scaledBy(x: frame.countdownScale, y: frame.countdownScale)
                            .translatedBy(x: -centre.x, y: -centre.y))
                    layer.fill(placed, with: .color(KeepAwakeAppearance.indicatorColor))
                }
            } symbols: {
                Image(systemName: "bolt")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(Color.primary.opacity(0.85))
                    .tag(Glyph.outline)
                Image(systemName: "bolt.fill")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(KeepAwakeAppearance.indicatorColor)
                    .tag(Glyph.filled)
            }
        }
    }

    /// The toggle's tint, following the same motion as the bolt.
    private var tintBackground: some View {
        let start = motionStart
        let active = shownActive
        return TimelineView(.animation(minimumInterval: nil, paused: start == nil)) { context in
            let tint = start.map {
                HubStayAwakeMotion.frame(starting: active, elapsed: context.date.timeIntervalSince($0),
                                         stageWidth: 0, boltWidth: 0, countdownWidth: 0, gap: 0).tint
            } ?? (active ? 1 : 0)
            ZStack {
                Color.primary.opacity(0.06 * (1 - tint))
                KeepAwakeAppearance.indicatorColor.opacity(0.15 * tint)
            }
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let status = HubStayAwakePopover.status(awake, now: context.date, l10n: l10n)
            HStack(spacing: 0) {
                Button {
                    if isEditing {
                        onHide()
                    } else {
                        awake.toggleFromHub()
                        HubStayAwakePopover.announce(awake, l10n: l10n)
                    }
                } label: {
                    stage(now: context.date)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        // The separator is a wall: nothing shows to its right.
                        .clipped()
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { stageWidth = $0 }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityLabel(awake.isActive ? text.stop : text.startHour)
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
                .focusable(false)
                .accessibilityLabel(text.options)
                .accessibilityValue(showingOptions ? text.open : text.closed)
                .popover(isPresented: $showingOptions, arrowEdge: .bottom) {
                    HubStayAwakePopover()
                }
            }
            .frame(minWidth: height < 30 ? 58 : 66, maxWidth: .infinity)
            .frame(height: height)
            .background { tintBackground }
            .clipShape(RoundedRectangle(cornerRadius: max(7, height * 0.28)))
            // Each frame is placed exactly; an animation handed down by a
            // parent would chase those positions and make the motion lag.
            .transaction { $0.animation = nil }
            .contextMenu {
                Button(FeatureStrings.hubCustomization(l10n.language).hideFromHub) { onHide() }
            }
        }
        .background(WindowVisibilityReader { visible in
            if !visible { showingOptions = false }
        })
        .help(l10n.s.keepAwakeTitle)
        .onChange(of: awake.endDate) { _, end in
            // Only a running session moves the end; the stop keeps the last one.
            if awake.isActive { shownEnd = end }
        }
        .onChange(of: awake.isActive) { _, active in
            if active { shownEnd = awake.endDate }
            guard active != shownActive else { return }
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                shownActive = active
                if reduceMotion {
                    motionStart = nil
                } else {
                    startMotion()
                }
            }
        }
        .onAppear {
            shownActive = awake.isActive
            shownEnd = awake.endDate
        }
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
