// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// App volume slider featuring a 0–100% main bar and an attached 100–200% boost stub,
/// driven by macOS's genuine SwiftUI `Slider` so its resting pill and pressed Liquid
/// Glass lens match system sliders pixel-for-pixel.
struct AppVolumeBoostSlider: View {
    let title: String
    @Binding var value: Double
    var onEditingChanged: (Bool) -> Void = { _ in }

    @Environment(\.colorScheme) private var colorScheme

    @State private var isTracking = false
    @State private var isHovered = false
    @State private var dragSliderPos: Double?
    @State private var dragVolume: Double?
    @State private var usingPointerDrag = false
    @State private var canCatchUnityInDrag = false
    @State private var holdingAtUnityInDrag = false
    @State private var unityDragAccumulated: Double = 0
    @State private var lastEmitUptime: TimeInterval = 0
    @State private var knobFreed = false
    /// Knob position minus true position (slider units) while held. Grabbing a
    /// knob resting inset at 0% / 200% keeps it under the cursor; the gap closes
    /// as the drag continues, so the knob never jumps on press.
    @State private var grabOffset: Double = 0
    /// Pointer travel (slider units) past where the knob is pinned at 0% / 200%.
    /// Moving back first unwinds this, so the knob waits until the cursor is
    /// vertically back over it, like a standard slider.
    @State private var pointerOvershoot: Double = 0

    private static let stubWidth: CGFloat = AppVolumeSliderMetrics.stubWidth
    private static let gap: CGFloat = AppVolumeSliderMetrics.gap
    private static let trackHeight: CGFloat = AppVolumeSliderMetrics.trackHeight
    /// Matches macOS 26 regular SwiftUI `Slider` resting knob width (20 pt).
    private static let knobWidth: CGFloat = 20
    private static let knobHalfWidth: CGFloat = knobWidth / 2
    /// Light magnetic catch right at 100%: < 1 pt below unity so 98%–99% never
    /// get grabbed early, and 2 pt past unity so stopping at 100% feels natural.
    private static let snapBelowPoints: CGFloat = 0.8
    private static let snapAbovePoints: CGFloat = 2.0
    /// Dead-distance buffer (in points of pointer travel) when an active drag
    /// reaches or revisits 100%; starting a drag directly at 100% reacts immediately.
    private static let unityDragDeadPoints: CGFloat = 9.0

    private var displayedVolume: Double {
        min(max(dragVolume ?? value, 0.0), 2.0)
    }

    private var percent: Int {
        Int((displayedVolume * 100).rounded())
    }

    private var showTooltip: Bool {
        isTracking || isHovered
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = max(geometry.size.width, 60)
            let currentPos = dragSliderPos ?? Self.sliderPosition(forVolume: displayedVolume, totalWidth: totalWidth)
            // True knob center: always exactly on the fill edge, reaching the
            // track's very ends at 0% and 200% (knob may poke half out while held).
            let thumbCenterX = CGFloat(currentPos) * Self.travelWidth(totalWidth)
            let knobCenterX = CGFloat(presentedPosition(currentPos, totalWidth: totalWidth))
                * Self.travelWidth(totalWidth)

            ZStack {
                trackLayer(totalWidth: totalWidth, thumbCenterX: thumbCenterX)
                    .allowsHitTesting(false)

                Slider(
                    value: sliderBinding(totalWidth: totalWidth),
                    in: 0...1,
                    onEditingChanged: { editing in
                        if editing {
                            beginTracking(totalWidth: totalWidth)
                        } else {
                            finishTracking()
                        }
                    }
                )
                .labelsHidden()
                .controlSize(.regular)
                .tint(.clear)
                .background(NativeSliderTrackMask(trigger: currentPos, isTracking: isTracking))
                // Extend the native slider half a knob past each end so its knob
                // center spans the full track (center = position × totalWidth).
                .padding(.horizontal, -Self.knobHalfWidth)

                AppVolumeAuxiliaryOverlay(
                    value: scrollAndResetBinding,
                    knobCenterX: knobCenterX,
                    knobHalfWidth: Self.knobHalfWidth,
                    onEditingChanged: onEditingChanged,
                    onResetToUnity: {
                        let wasTracking = isTracking
                        dragVolume = nil
                        dragSliderPos = nil
                        usingPointerDrag = false
                        canCatchUnityInDrag = false
                        holdingAtUnityInDrag = false
                        unityDragAccumulated = 0
                        isTracking = false
                        knobFreed = false
                        grabOffset = 0
                        pointerOvershoot = 0
                        if !wasTracking {
                            onEditingChanged(true)
                        }
                        value = 1.0
                        onEditingChanged(false)
                    },
                    onPointerDragStarted: {
                        usingPointerDrag = false
                    },
                    onPointerDragDeltaPoints: { dx in
                        usingPointerDrag = true
                        applyPointerDragDelta(points: dx, totalWidth: totalWidth)
                    },
                    onPointerDragEnded: {
                        usingPointerDrag = false
                        DispatchQueue.main.async {
                            finishTracking()
                        }
                    },
                    onHoverChanged: { hovering in
                        isHovered = hovering
                    }
                )
            }
            .overlay {
                if showTooltip {
                    Text("\(percent)%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(displayedVolume > 1.001 ? Color.orange : Color.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.14), radius: 3, y: 1)
                        .fixedSize()
                        .position(x: min(max(knobCenterX, 20), max(totalWidth - 20, 20)), y: -14)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .accessibilityValue(displayedVolume > 1.001 ? "\(percent) percent, boosted" : "\(percent) percent")
            .accessibilityAdjustableAction { direction in
                let step = 0.05
                let oldVal = min(max(value, 0.0), 2.0)
                let nextVal: Double
                switch direction {
                case .increment: nextVal = min(2.0, oldVal + step)
                case .decrement: nextVal = max(0.0, oldVal - step)
                @unknown default: return
                }
                Self.checkUnityHaptic(oldValue: oldVal, newValue: nextVal)
                onEditingChanged(true)
                value = nextVal
                onEditingChanged(false)
            }
        }
        .frame(height: 22)
    }

    @ViewBuilder
    private func trackLayer(totalWidth: CGFloat, thumbCenterX: CGFloat) -> some View {
        let mainTrackWidth = max(totalWidth - Self.stubWidth - Self.gap, 20)
        let stubStart = mainTrackWidth + Self.gap
        let isDark = colorScheme == .dark
        let vol = displayedVolume
        let isBoosted = vol > 1.001

        // 100% centers the knob right on the 4pt gap between the main bar and
        // the boost stub, so `thumbCenterX` naturally reaches `mainTrackWidth`
        // right as volume hits 100% and enters `stubStart` right above 100%.
        let mainFillWidth: CGFloat = {
            if vol <= 0.001 { return 0 }
            if vol >= 0.999 { return mainTrackWidth }
            return min(max(thumbCenterX, Self.trackHeight), mainTrackWidth)
        }()

        let boostFillWidth: CGFloat = {
            guard isBoosted else { return 0 }
            if vol >= 1.999 { return Self.stubWidth }
            // Solid orange stays locked to the knob's true center all the way
            // into the right end cap at 200%.
            let localCenter = thumbCenterX - stubStart
            guard localCenter > 0.5 else { return 0 }
            return min(localCenter, Self.stubWidth)
        }()

        HStack(spacing: Self.gap) {
            // 1. Main bar (0–100%)
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.secondary.opacity(isDark ? 0.25 : 0.16))
                    .frame(width: mainTrackWidth, height: Self.trackHeight)

                if mainFillWidth > 0 {
                    Capsule(style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: mainFillWidth, height: Self.trackHeight)
                }
            }
            .frame(width: mainTrackWidth, height: Self.trackHeight)

            // 2. Boost stub (100–200%)
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.orange.opacity(isBoosted ? (isDark ? 0.42 : 0.34) : (isDark ? 0.22 : 0.16)))
                    .frame(width: Self.stubWidth, height: Self.trackHeight)

                if boostFillWidth > 0 {
                    RoundedRectangle(
                        cornerRadius: min(boostFillWidth / 2, Self.trackHeight / 2),
                        style: .continuous
                    )
                    .fill(Color.orange)
                    .frame(width: boostFillWidth, height: Self.trackHeight)
                }
            }
            .frame(width: Self.stubWidth, height: Self.trackHeight)
        }
    }

    private func sliderBinding(totalWidth: CGFloat) -> Binding<Double> {
        Binding(
            get: {
                presentedPosition(
                    dragSliderPos ?? Self.sliderPosition(forVolume: displayedVolume, totalWidth: totalWidth),
                    totalWidth: totalWidth
                )
            },
            set: { rawPos in
                // Continuous pointer drags are driven directly from true unclamped
                // window coordinates in `applyPointerDragDelta` so tracking continues
                // smoothly all the way to 200% / 0% even when the cursor crosses
                // outside the slider container after pausing in the 100% buffer.
                guard !usingPointerDrag else { return }

                let clampedPos = min(max(rawPos, 0.0), 1.0)
                let usable = Self.travelWidth(totalWidth)
                let unity = Self.unityPosition(totalWidth: totalWidth)
                let rearmBelow = Double(4.0 / usable)
                let rearmAbove = Double(1.5 / usable)
                let previousVol = dragVolume ?? value

                if isTracking {
                    let currentEffective = dragSliderPos
                        ?? Self.sliderPosition(forVolume: displayedVolume, totalWidth: totalWidth)
                    let clickJumpThreshold = Double(14.0 / usable)
                    // Only jump on initial press if the user clicked on the track
                    // away from the knob; pressing on the knob itself keeps its exact spot.
                    guard abs(clampedPos - currentEffective) > clickJumpThreshold else { return }

                    let mapped = Self.volumeAndSnappedPosition(forSliderPosition: clampedPos, totalWidth: totalWidth)
                    dragSliderPos = mapped.snappedPosition
                    dragVolume = mapped.volume
                    grabOffset = 0
                    canCatchUnityInDrag = mapped.snappedPosition < unity - rearmBelow
                        || mapped.snappedPosition > unity + rearmAbove
                    holdingAtUnityInDrag = mapped.volume == 1.0
                    unityDragAccumulated = 0

                    Self.checkUnityHaptic(oldValue: previousVol, newValue: mapped.volume)
                    if abs(mapped.volume - value) > 0.000_5
                        || mapped.volume == 0.0 || mapped.volume == 1.0 || mapped.volume == 2.0 {
                        value = mapped.volume
                    }
                } else {
                    let mapped = Self.volumeAndSnappedPosition(forSliderPosition: clampedPos, totalWidth: totalWidth)
                    Self.checkUnityHaptic(oldValue: previousVol, newValue: mapped.volume)
                    if abs(mapped.volume - value) > 0.000_5
                        || mapped.volume == 0.0 || mapped.volume == 1.0 || mapped.volume == 2.0 {
                        value = mapped.volume
                    }
                }
            }
        )
    }

    private func beginTracking(totalWidth: CGFloat) {
        guard !isTracking else { return }
        isTracking = true
        let startVol = min(max(value, 0.0), 2.0)
        dragVolume = startVol
        dragSliderPos = Self.sliderPosition(forVolume: startVol, totalWidth: totalWidth)
        let truePos = Self.sliderPosition(forVolume: startVol, totalWidth: totalWidth)
        grabOffset = presentedPosition(truePos, totalWidth: totalWidth) - truePos
        pointerOvershoot = 0
        knobFreed = true
        // Starting at 100% reacts immediately; starting elsewhere
        // (or revisiting 100% after moving away) engages the buffer.
        canCatchUnityInDrag = abs(startVol - 1.0) > 0.005
        holdingAtUnityInDrag = false
        unityDragAccumulated = 0
        onEditingChanged(true)
    }

    private func finishTracking() {
        guard isTracking else { return }
        isTracking = false
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            knobFreed = false
            grabOffset = 0
        }
        pointerOvershoot = 0
        if let finalVol = dragVolume, abs(finalVol - value) > 0.000_01 {
            value = finalVol
        }
        dragVolume = nil
        dragSliderPos = nil
        usingPointerDrag = false
        canCatchUnityInDrag = false
        holdingAtUnityInDrag = false
        unityDragAccumulated = 0
        onEditingChanged(false)
    }

    /// Advances the slider from true unclamped pointer movement in window coordinates,
    /// preserving the 100% revisit buffer while guaranteeing smooth 1:1 tracking all
    /// the way to 0% and 200% even if the cursor leaves the slider's frame.
    private func applyPointerDragDelta(points dx: CGFloat, totalWidth: CGFloat) {
        guard dx != 0 else { return }
        if !isTracking {
            beginTracking(totalWidth: totalWidth)
        }

        let usable = Self.travelWidth(totalWidth)
        let unity = Self.unityPosition(totalWidth: totalWidth)
        let deadPos = Double(Self.unityDragDeadPoints / usable)
        var knobDelta = Double(dx / usable)
        // Cursor went past the pinned knob: moving back unwinds that first.
        if pointerOvershoot != 0 {
            if (pointerOvershoot > 0) == (knobDelta > 0) {
                pointerOvershoot += knobDelta
                return
            }
            let unwind = min(abs(pointerOvershoot), abs(knobDelta))
            if pointerOvershoot > 0 {
                pointerOvershoot -= unwind
                knobDelta += unwind
            } else {
                pointerOvershoot += unwind
                knobDelta -= unwind
            }
            if abs(pointerOvershoot) < 1e-9 { pointerOvershoot = 0 }
            guard knobDelta != 0 else { return }
        }
        // Moving inward from a grabbed end: the value runs 1.5× until it meets
        // the knob (fill edge stays hidden under the knob the whole time).
        var deltaPos = knobDelta
        if grabOffset != 0, (grabOffset < 0) == (knobDelta < 0) {
            let catchUp = min(abs(grabOffset), 0.5 * abs(knobDelta))
            deltaPos += grabOffset < 0 ? -catchUp : catchUp
        }
        let previousVol = dragVolume ?? value
        let currentEffective = dragSliderPos
            ?? Self.sliderPosition(forVolume: displayedVolume, totalWidth: totalWidth)

        let effectivePos: Double
        let nextVolume: Double

        if holdingAtUnityInDrag {
            unityDragAccumulated += deltaPos
            if abs(unityDragAccumulated) <= deadPos {
                effectivePos = unity
                nextVolume = 1.0
            } else {
                let excess = unityDragAccumulated > 0
                    ? (unityDragAccumulated - deadPos)
                    : (unityDragAccumulated + deadPos)
                holdingAtUnityInDrag = false
                unityDragAccumulated = 0
                canCatchUnityInDrag = false
                let exitedPos = min(max(unity + excess, 0.0), 1.0)
                effectivePos = exitedPos
                nextVolume = Self.continuousVolume(forSliderPosition: exitedPos, totalWidth: totalWidth)
            }
        } else {
            // The unity crossing and its excess come from the pointer's full
            // travel; only the resulting thumb position is clamped, so a fast
            // drag past 100% still reaches the far end.
            let rawCandidatePos = currentEffective + deltaPos
            let candidatePos = min(max(rawCandidatePos, 0.0), 1.0)
            let crossedUnity = (currentEffective < unity && rawCandidatePos >= unity)
                || (currentEffective > unity && rawCandidatePos <= unity)
            let movingTowardUnity = (currentEffective < unity && deltaPos > 0)
                || (currentEffective > unity && deltaPos < 0)
            let snapBelowRadius = Double(Self.snapBelowPoints / usable)
            let snapAboveRadius = Double(1.6 / usable)
            let enteredSnapPocket = movingTowardUnity && (
                (currentEffective < unity && unity - candidatePos <= snapBelowRadius)
                || (currentEffective > unity && candidatePos - unity <= snapAboveRadius)
            )
            let rearmBelow = Double(4.0 / usable)
            let rearmAbove = Double(1.5 / usable)

            if canCatchUnityInDrag && (crossedUnity || enteredSnapPocket) {
                let overshoot = crossedUnity ? (rawCandidatePos - unity) : 0
                if abs(overshoot) <= deadPos {
                    holdingAtUnityInDrag = true
                    unityDragAccumulated = overshoot
                    effectivePos = unity
                    nextVolume = 1.0
                } else {
                    let excess = overshoot > 0 ? (overshoot - deadPos) : (overshoot + deadPos)
                    canCatchUnityInDrag = false
                    let exitedPos = min(max(unity + excess, 0.0), 1.0)
                    effectivePos = exitedPos
                    nextVolume = Self.continuousVolume(forSliderPosition: exitedPos, totalWidth: totalWidth)
                }
            } else {
                effectivePos = candidatePos
                nextVolume = Self.continuousVolume(forSliderPosition: candidatePos, totalWidth: totalWidth)
                if candidatePos < unity - rearmBelow || candidatePos > unity + rearmAbove {
                    canCatchUnityInDrag = true
                }
            }
        }

        let knobBefore = currentEffective + grabOffset
        if grabOffset != 0 {
            // Whatever the knob moved that the true position didn't (catch-up,
            // or pushing outward past the end) changes the remaining gap.
            let next = grabOffset + knobDelta - (effectivePos - currentEffective)
            grabOffset = grabOffset < 0 ? min(next, 0) : max(next, 0)
        }
        // Knob pinned at an end: bank the pointer travel it couldn't follow.
        let knobAfter = effectivePos + grabOffset
        let unfollowed = knobDelta - (knobAfter - knobBefore)
        if (knobAfter >= 1.0 - 1e-9 && unfollowed > 0) || (knobAfter <= 1e-9 && unfollowed < 0) {
            pointerOvershoot += unfollowed
        }
        dragSliderPos = effectivePos
        dragVolume = nextVolume
        Self.checkUnityHaptic(oldValue: previousVol, newValue: nextVolume)

        let isKeyPoint = nextVolume == 0.0 || nextVolume == 1.0 || nextVolume == 2.0
        if !isKeyPoint {
            let now = ProcessInfo.processInfo.systemUptime
            guard now - lastEmitUptime >= (1.0 / 60.0) else { return }
            lastEmitUptime = now
        }
        if abs(nextVolume - value) > 0.000_5 || isKeyPoint {
            value = nextVolume
        }
    }

    private var scrollAndResetBinding: Binding<Double> {
        Binding(
            get: { dragVolume ?? value },
            set: { nextVol in
                let clamped = min(max(nextVol, 0.0), 2.0)
                let oldVal = dragVolume ?? value
                guard abs(clamped - oldVal) > 0.000_01 else { return }
                Self.checkUnityHaptic(oldValue: oldVal, newValue: clamped)
                value = clamped
            }
        )
    }

    // MARK: - Non-linear Boost Mapping

    /// Places 100% right at the center of the 4pt gap between the 0–100% bar
    /// and the 100–200% boost stub.
    private static func unityPosition(totalWidth: CGFloat) -> Double {
        let usable = travelWidth(totalWidth)
        let mainTrack = max(totalWidth - stubWidth - gap, 20)
        let unityCenterX = mainTrack + gap * 0.5
        return min(max(Double(unityCenterX / usable), 0.1), 0.95)
    }

    /// Knob-center travel: the native slider is extended half a knob past each
    /// track end, so position 0…1 maps the knob center onto 0…totalWidth.
    private static func travelWidth(_ totalWidth: CGFloat) -> CGFloat {
        max(totalWidth, 20)
    }

    /// While held, the knob sits on its true center (poking half out at 0% /
    /// 200%). At rest it eases back inside the track ends; mid-range is unaffected.
    private func presentedPosition(_ pos: Double, totalWidth: CGFloat) -> Double {
        guard !knobFreed else { return min(max(pos + grabOffset, 0.0), 1.0) }
        let inset = Double(Self.knobHalfWidth / Self.travelWidth(totalWidth))
        return min(max(pos, inset), 1.0 - inset)
    }

    private static func boostStartPosition(totalWidth: CGFloat) -> Double {
        let usable = travelWidth(totalWidth)
        let unity = unityPosition(totalWidth: totalWidth)
        return min(unity + Double(snapAbovePoints / usable), 0.97)
    }

    private static func sliderPosition(forVolume volume: Double, totalWidth: CGFloat) -> Double {
        let v = min(max(volume, 0.0), 2.0)
        let unity = unityPosition(totalWidth: totalWidth)
        if v <= 1.0 {
            return v * unity
        }
        let span = max(1.0 - unity, 0.01)
        return min(1.0, unity + (v - 1.0) * span)
    }

    private static func continuousVolume(forSliderPosition pos: Double, totalWidth: CGFloat) -> Double {
        let unity = unityPosition(totalWidth: totalWidth)
        if pos <= unity {
            return min(max(pos / max(unity, 0.01), 0.0), 1.0)
        }
        let span = max(1.0 - unity, 0.01)
        return min(max(1.0 + (pos - unity) / span, 1.0), 2.0)
    }

    private static func volumeAndSnappedPosition(
        forSliderPosition pos: Double,
        totalWidth: CGFloat
    ) -> (volume: Double, snappedPosition: Double) {
        let usable = travelWidth(totalWidth)
        let unity = unityPosition(totalWidth: totalWidth)
        let boostStart = boostStartPosition(totalWidth: totalWidth)
        let snapBelow = Double(snapBelowPoints / usable)

        if pos >= unity - snapBelow && pos <= boostStart {
            return (1.0, unity)
        }
        return (continuousVolume(forSliderPosition: pos, totalWidth: totalWidth), pos)
    }

    private static func checkUnityHaptic(oldValue: Double, newValue: Double) {
        if (oldValue < 1.0 && newValue >= 1.0) || (oldValue > 1.0 && newValue <= 1.0) {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
        }
    }
}

/// Hides the native `Slider`'s built-in 6pt track sublayers so the 4pt gap
/// between the 0–100% bar and 100–200% boost stub stays completely clear while
/// keeping the genuine system knob untouched.
private struct NativeSliderTrackMask: NSViewRepresentable {
    var trigger: Double
    var isTracking: Bool

    func makeNSView(context: Context) -> MaskProbeView { MaskProbeView() }
    func updateNSView(_ nsView: MaskProbeView, context: Context) { nsView.maskBuiltInTrack() }

    static func dismantleNSView(_ nsView: MaskProbeView, coordinator: ()) {
        nsView.stopCommitObserver()
    }

    final class MaskProbeView: NSView {
        private var runLoopObserver: CFRunLoopObserver?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            wantsLayer = true
        }

        deinit {
            if let observer = runLoopObserver {
                CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                startCommitObserverIfNeeded()
                maskBuiltInTrack()
            } else {
                stopCommitObserver()
            }
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if newWindow == nil {
                stopCommitObserver()
            }
        }

        override func layout() {
            super.layout()
            maskBuiltInTrack()
        }

        /// Runs right after SwiftUI flushes its ViewGraph layer updates and right
        /// before CoreAnimation commits `CATransaction` (order 2_000_000), catching
        /// asynchronous Liquid Glass release morph completions and hover state swaps
        /// when the pointer rests stationary on the knob after dragging.
        private func startCommitObserverIfNeeded() {
            guard runLoopObserver == nil else { return }
            let activities: CFRunLoopActivity = [.beforeWaiting, .exit]
            let observer = CFRunLoopObserverCreateWithHandler(
                kCFAllocatorDefault,
                activities.rawValue,
                true,
                1_999_900
            ) { [weak self] _, _ in
                guard let self, self.window != nil, !self.isHiddenOrHasHiddenAncestor else { return }
                self.maskBuiltInTrack()
            }
            if let observer {
                CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
                runLoopObserver = observer
            }
        }

        func stopCommitObserver() {
            if let observer = runLoopObserver {
                CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
                runLoopObserver = nil
            }
        }

        private static func suppressTrackBars(in sliderContainer: CALayer) -> Bool {
            var found = false
            for sub in sliderContainer.sublayers ?? [] where sub.bounds.height > 1.5 && sub.bounds.height < 10 {
                found = true
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                if sub.opacity != 0 { sub.opacity = 0 }
                if !sub.isHidden { sub.isHidden = true }
                if sub.backgroundColor != nil { sub.backgroundColor = nil }
                if sub.mask == nil {
                    let zeroMask = CALayer()
                    zeroMask.frame = .zero
                    sub.mask = zeroMask
                }
                CATransaction.commit()
            }
            return found
        }

        func maskBuiltInTrack() {
            guard bounds.width > 30 else { return }

            // Direct O(1) sibling scan (~5 layers): `AppKitPlatformViewHost` and
            // SwiftUI's `Slider` container share the same parent layer and bounds,
            // even when SwiftUI swaps container layers after a Liquid Glass morph.
            if let hostLayer = superview?.layer, let parentLayer = hostLayer.superlayer {
                var matchedAny = false
                for sibling in parentLayer.sublayers ?? [] where sibling !== hostLayer {
                    if abs(sibling.bounds.width - hostLayer.bounds.width) < 4,
                       sibling.bounds.height >= 13, sibling.bounds.height <= 26,
                       abs(sibling.position.x - hostLayer.position.x) < 4,
                       abs(sibling.position.y - hostLayer.position.y) < 8 {
                        if Self.suppressTrackBars(in: sibling) {
                            matchedAny = true
                        }
                    }
                }
                if matchedAny { return }
            }

            // Fallback geometry-flipped-safe CALayer coordinate search.
            guard let ownLayer = layer else { return }
            var ancestor: NSView? = superview
            while let current = ancestor {
                if let rootLayer = current.layer {
                    let targetRect = ownLayer.convert(ownLayer.bounds, to: rootLayer)
                    if findAndMask(in: rootLayer, rootLayer: rootLayer, targetRect: targetRect) {
                        return
                    }
                    if String(describing: type(of: current)).contains("Hosting") {
                        break
                    }
                }
                ancestor = current.superview
            }
        }

        private func findAndMask(in candidate: CALayer, rootLayer: CALayer, targetRect: CGRect) -> Bool {
            if abs(candidate.bounds.width - targetRect.width) < 4,
               candidate.bounds.height >= 13, candidate.bounds.height <= 26 {
                let frameInRoot = candidate.convert(candidate.bounds, to: rootLayer)
                if abs(frameInRoot.minX - targetRect.minX) < 6,
                   abs(frameInRoot.midY - targetRect.midY) < 10,
                   Self.suppressTrackBars(in: candidate) {
                    return true
                }
            }
            for sub in candidate.sublayers ?? [] {
                if findAndMask(in: sub, rootLayer: rootLayer, targetRect: targetRect) {
                    return true
                }
            }
            return false
        }
    }
}

/// Pass-through overlay handling hover state, double-click-to-100% reset (on
/// the knob only), and 1:1 scroll-to-slide while letting single clicks and
/// drags go straight to the native SwiftUI `Slider`.
private struct AppVolumeAuxiliaryOverlay: NSViewRepresentable {
    @Binding var value: Double
    /// Visible knob center in this overlay's coordinates.
    let knobCenterX: CGFloat
    let knobHalfWidth: CGFloat
    let onEditingChanged: (Bool) -> Void
    let onResetToUnity: () -> Void
    let onPointerDragStarted: () -> Void
    let onPointerDragDeltaPoints: (CGFloat) -> Void
    let onPointerDragEnded: () -> Void
    let onHoverChanged: (Bool) -> Void
    @Environment(\.isEnabled) private var isEnabled

    func makeNSView(context: Context) -> AuxiliaryView {
        let view = AuxiliaryView()
        view.owner = self
        return view
    }

    func updateNSView(_ nsView: AuxiliaryView, context: Context) {
        nsView.owner = self
        nsView.isEnabled = isEnabled
        if !isEnabled {
            nsView.resetDragSample()
            nsView.endScrollEditing()
        }
    }

    static func dismantleNSView(_ nsView: AuxiliaryView, coordinator: ()) {
        nsView.tearDownMonitor()
        nsView.endScrollEditing()
    }

    final class AuxiliaryView: NSView, SliderScrollTarget {
        var owner: AppVolumeAuxiliaryOverlay?
        var isEnabled = true
        private var hoverArea: NSTrackingArea?
        private var eventMonitor: Any?
        private var pointerDownInside = false
        /// Knob center when a click sequence began. A first click on the strip
        /// jumps the knob under the cursor, so the second click of a double-click
        /// must be judged against where the knob was before that jump.
        private var knobCenterAtFirstClick: CGFloat?
        private var lastDragWindowX: CGFloat?
        private var scroll = SliderScroll()
        private var scrolling = false
        private var scrollCurrentVolume: Double = 1.0
        private var canCatchUnityInScroll = false
        private var holdingAtUnityInScroll = false
        private var unityScrollAccumulated: Double = 0
        private var unityScrollHoldStart: TimeInterval = 0
        /// Dead distance (~10.5% volume / ~21 pt of two-finger trackpad slide) when
        /// an active scroll gesture reaches or revisits 100%, while initiating a
        /// scroll directly from 100% reacts immediately without delay.
        private static let unityScrollDeadDistance: Double = 0.105
        /// A scroll that reaches 100% stops there however fast it was going: the
        /// overshoot is dropped and leaving also needs this long at 100%, so an
        /// accelerated flick can't burst through, while scrolling on still does.
        private static let unityScrollMinimumHold: TimeInterval = 0.2

        var acceptsSliderScroll: Bool { isEnabled && owner != nil }

        deinit {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        func resetDragSample() {
            pointerDownInside = false
            lastDragWindowX = nil
        }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if hoverArea == nil {
                let area = NSTrackingArea(
                    rect: .zero,
                    options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                    owner: self,
                    userInfo: nil
                )
                addTrackingArea(area)
                hoverArea = area
            }
        }

        override func mouseEntered(with event: NSEvent) {
            super.mouseEntered(with: event)
            owner?.onHoverChanged(true)
        }

        override func mouseExited(with event: NSEvent) {
            super.mouseExited(with: event)
            owner?.onHoverChanged(false)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                installMonitorIfNeeded()
            } else {
                tearDownMonitor()
            }
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if newWindow == nil {
                tearDownMonitor()
                endScrollEditing()
                owner?.onHoverChanged(false)
            }
        }

        private func installMonitorIfNeeded() {
            guard eventMonitor == nil else { return }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
                guard let self,
                      self.isEnabled,
                      !self.isHiddenOrHasHiddenAncestor,
                      let win = self.window,
                      event.window === win,
                      let owner = self.owner
                else {
                    return event
                }

                switch event.type {
                case .leftMouseDown:
                    let localPoint = self.convert(event.locationInWindow, from: nil)
                    let inside = self.bounds.insetBy(dx: -4, dy: -4).contains(localPoint)
                    if event.clickCount <= 1 {
                        self.knobCenterAtFirstClick = inside ? owner.knobCenterX : nil
                    }
                    // Only a double-click on the knob resets to 100%; on the strip
                    // the first click already moved the knob there.
                    let onKnob = self.knobCenterAtFirstClick.map {
                        abs(localPoint.x - $0) <= owner.knobHalfWidth + 2
                    } ?? false
                    if inside && event.clickCount == 2 && onKnob {
                        self.pointerDownInside = false
                        self.lastDragWindowX = nil
                        self.endScrollEditing()
                        owner.onResetToUnity()
                        return nil
                    }
                    self.pointerDownInside = inside
                    self.lastDragWindowX = inside ? event.locationInWindow.x : nil
                    if inside {
                        owner.onPointerDragStarted()
                    }
                    return event

                case .leftMouseDragged:
                    guard self.pointerDownInside else { return event }
                    let currentX = event.locationInWindow.x
                    let prevX = self.lastDragWindowX ?? currentX
                    self.lastDragWindowX = currentX
                    let dx = currentX - prevX
                    if dx != 0 {
                        owner.onPointerDragDeltaPoints(dx)
                    }
                    return event

                case .leftMouseUp:
                    if self.pointerDownInside {
                        self.pointerDownInside = false
                        self.lastDragWindowX = nil
                        owner.onPointerDragEnded()
                    }
                    return event

                default:
                    return event
                }
            }
        }

        func tearDownMonitor() {
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
            lastDragWindowX = nil
        }

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard isEnabled, NSApp.currentEvent?.type == .scrollWheel else { return nil }
            return super.hitTest(point)
        }

        func endScrollEditing() {
            if scrolling {
                scrolling = false
                owner?.onEditingChanged(false)
            }
            scroll = SliderScroll()
            canCatchUnityInScroll = false
            holdingAtUnityInScroll = false
            unityScrollAccumulated = 0
        }

        override func scrollWheel(with event: NSEvent) {
            guard acceptsSliderScroll, let owner else {
                endScrollEditing()
                return SliderScroll.pass(event, from: self)
            }
            let finishes = event.phase.contains(.ended) || event.phase.contains(.cancelled)
                || !event.momentumPhase.isEmpty
            let phase: SliderScroll.Phase
            if !event.momentumPhase.isEmpty { phase = .momentum }
            else if event.phase.contains(.began) { phase = .began }
            else if !event.phase.intersection([.changed, .stationary]).isEmpty { phase = .changed }
            else if event.phase.isEmpty { phase = .none }
            else { phase = .ended }

            if phase == .began || (phase == .none && !scrolling) {
                let startVol = min(max(owner.value, 0.0), 2.0)
                scrollCurrentVolume = startVol
                // Starting at 100% reacts immediately; starting elsewhere (or
                // revisiting 100% after moving away) engages the dead-distance buffer.
                canCatchUnityInScroll = abs(startVol - 1.0) > 0.005
                holdingAtUnityInScroll = false
                unityScrollAccumulated = 0
            }

            switch scroll.handle(
                phase,
                dx: Double(event.scrollingDeltaX) * 0.5,
                dy: Double(event.scrollingDeltaY) * 0.5,
                precise: event.hasPreciseScrollingDeltas,
                inverted: event.isDirectionInvertedFromDevice,
                timestamp: event.timestamp,
                current: scrollCurrentVolume,
                range: 0.0...2.0
            ) {
            case .pass:
                endScrollEditing()
                SliderScroll.pass(event, from: self)
            case .hold:
                if finishes { endScrollEditing() }
            case .move:
                let stepDelta = SliderScroll.step(
                    dx: Double(event.scrollingDeltaX),
                    dy: Double(event.scrollingDeltaY),
                    precise: event.hasPreciseScrollingDeltas,
                    inverted: event.isDirectionInvertedFromDevice
                )
                guard stepDelta != 0 else {
                    if finishes { endScrollEditing() }
                    return
                }
                if !scrolling {
                    scrolling = true
                    owner.onEditingChanged(true)
                }

                let deadDistance = Self.unityScrollDeadDistance
                let nextVol: Double

                if holdingAtUnityInScroll {
                    unityScrollAccumulated += stepDelta
                    let heldLongEnough = event.timestamp - unityScrollHoldStart >= Self.unityScrollMinimumHold
                    if !heldLongEnough {
                        // Cap what builds up during the minimum hold so a fast
                        // flick can't bank enough to jump out the moment it ends.
                        unityScrollAccumulated = max(-deadDistance, min(deadDistance, unityScrollAccumulated))
                        nextVol = 1.0
                    } else if abs(unityScrollAccumulated) <= deadDistance {
                        nextVol = 1.0
                    } else {
                        let excess = unityScrollAccumulated > 0
                            ? (unityScrollAccumulated - deadDistance)
                            : (unityScrollAccumulated + deadDistance)
                        holdingAtUnityInScroll = false
                        unityScrollAccumulated = 0
                        canCatchUnityInScroll = false
                        nextVol = min(max(1.0 + excess, 0.0), 2.0)
                    }
                } else {
                    let prev = scrollCurrentVolume
                    let rawProposed = min(max(prev + stepDelta, 0.0), 2.0)
                    let crossedUnity = (prev < 1.0 && rawProposed >= 1.0)
                        || (prev > 1.0 && rawProposed <= 1.005)

                    if canCatchUnityInScroll && crossedUnity {
                        // Always stop at 100%, dropping the overshoot. A wheel
                        // notch lands here and the next notch moves on (each notch
                        // ends editing), so a ticked wheel never gets stuck.
                        holdingAtUnityInScroll = true
                        unityScrollAccumulated = 0
                        unityScrollHoldStart = event.timestamp
                        nextVol = 1.0
                    } else {
                        nextVol = rawProposed
                        if abs(nextVol - 1.0) > 0.02 {
                            canCatchUnityInScroll = true
                        }
                    }
                }

                scrollCurrentVolume = nextVol
                owner.value = nextVol

                if !event.hasPreciseScrollingDeltas || finishes {
                    endScrollEditing()
                }
            }
        }
    }
}
