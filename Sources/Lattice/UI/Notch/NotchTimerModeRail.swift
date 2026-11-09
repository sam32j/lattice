
 // SPDX-License-Identifier: GPL-3.0-or-later
 // Copyright (C) 2026 Lattice

 import AppKit
 import SwiftUI

 /// Vertical mode selector for the expanded timer.
 ///
 /// Order:
 ///   Stopwatch
 ///   Timer
 ///   Pomodoro
 ///
 /// A physical scroll gesture can advance at most one mode.
 /// Momentum never advances the selection.
 struct NotchTimerModeRail: NSViewRepresentable {
     let mode: NotchTimerMode
     let onSelect: (NotchTimerMode) -> Void

     static let width: CGFloat = 25
     static let height: CGFloat = 68

     func makeNSView(context: Context) -> NotchTimerModeRailControl {
         let view = NotchTimerModeRailControl()
         view.focusRingType = .none
         view.mode = mode
         view.onSelect = onSelect
         view.setAccessibilityLabel(FeatureStrings.notchTimerUI(L10n.shared.language).modePicker)
         view.configureAccessibility()
         return view
     }

     func updateNSView(
         _ view: NotchTimerModeRailControl,
         context: Context
     ) {
         // Do not recreate the view or reset its gesture state.
         view.mode = mode
         view.onSelect = onSelect
         view.setAccessibilityLabel(FeatureStrings.notchTimerUI(L10n.shared.language).modePicker)
         view.configureAccessibility()
     }

     func sizeThatFits(
         _ proposal: ProposedViewSize,
         nsView: NotchTimerModeRailControl,
         context: Context
     ) -> CGSize? {
         CGSize(width: Self.width, height: Self.height)
     }
 }

 final class NotchTimerModeRailControl: NSView {
     static let orderedModes: [NotchTimerMode] = [
         .stopwatch,
         .timer,
         .pomodoro
     ]

     var mode: NotchTimerMode = .timer {
         didSet {
             needsDisplay = true
             setAccessibilityValueDescription(
                 accessibilityModeName(mode)
             )
         }
     }

     var onSelect: ((NotchTimerMode) -> Void)?

     func configureAccessibility() {
         setAccessibilityRole(.group)
         setAccessibilityValueDescription(accessibilityModeName(mode))
         setAccessibilityCustomActions(Self.orderedModes.map { selection in
             NSAccessibilityCustomAction(name: accessibilityModeName(selection)) { [weak self] in
                 guard let self else { return false }
                 self.select(selection)
                 return true
             }
         })
     }

     private let threshold: CGFloat = 40
     private let wheelQuietPeriod: TimeInterval = 0.45

     private var accumulatedScroll: CGFloat = 0
     private var gestureConsumed = false
     private var lastScrollTimestamp: TimeInterval?

     override var isFlipped: Bool { true }
     override var acceptsFirstResponder: Bool { true }

     override var intrinsicContentSize: NSSize {
         NSSize(
             width: NotchTimerModeRail.width,
             height: NotchTimerModeRail.height
         )
     }

     // MARK: - Scroll handling

     override func scrollWheel(with event: NSEvent) {
         guard event.type == .scrollWheel else { return }

         // Ignore momentum completely, including its end event.
         // Momentum must never reset the gesture lock.
         guard event.momentumPhase.isEmpty else { return }

         let phase = event.phase

         // A new physical trackpad gesture.
         if phase.contains(.began) ||
             phase.contains(.mayBegin) {
             resetGesture()
         }

         // Ending a gesture does not unlock it.
         // The next gesture must explicitly begin.
         if phase.contains(.ended) ||
             phase.contains(.cancelled) {
             return
         }

         // Mouse wheels generally do not report gesture phases.
         // Treat their events as one burst until input goes quiet.
         if phase.isEmpty {
             if let previous = lastScrollTimestamp,
                event.timestamp - previous > wheelQuietPeriod {
                 resetGesture()
             } else if lastScrollTimestamp == nil {
                 resetGesture()
             }
         }

         lastScrollTimestamp = event.timestamp

         // One selection maximum until another gesture begins.
         guard !gestureConsumed else { return }

         let dx = event.scrollingDeltaX
         let dy = event.scrollingDeltaY

         guard abs(dy) > abs(dx) else { return }

         // Normalize non-precise wheel input to approximate points.
         // Never use velocity or acceleration to calculate steps.
         let displacement: CGFloat = event.hasPreciseScrollingDeltas
             ? dy
             : dy * 16

         // Reversing direction cancels the previous accumulation.
         if accumulatedScroll * displacement < 0 {
             accumulatedScroll = 0
         }

         accumulatedScroll += displacement

         guard abs(accumulatedScroll) >= threshold else {
             return
         }

         // Set the latch BEFORE emitting the selection.
         // A large delta cannot generate multiple steps.
         gestureConsumed = true

         let direction = accumulatedScroll < 0 ? 1 : -1
         move(by: direction)
     }

     private func resetGesture() {
         accumulatedScroll = 0
         gestureConsumed = false
     }

     // MARK: - Selection

     private func move(by direction: Int) {
         guard let index = Self.orderedModes.firstIndex(of: mode)
         else { return }

         let next = min(
             max(index + direction, 0),
             Self.orderedModes.count - 1
         )

         select(Self.orderedModes[next])
     }

     private func select(_ selection: NotchTimerMode) {
         guard selection != mode else { return }

         // Update immediately for visual responsiveness.
         // The parent remains the source of truth.
         mode = selection
         onSelect?(selection)
     }

     // MARK: - Mouse

     override func mouseDown(with event: NSEvent) {
         window?.makeFirstResponder(self)

         let point = convert(event.locationInWindow, from: nil)

         guard bounds.contains(point) else { return }

         let centers = dotCenters()

         guard let index = centers.indices.min(by: {
             abs(centers[$0] - point.y) <
                 abs(centers[$1] - point.y)
         }) else { return }

         select(Self.orderedModes[index])
     }

     // MARK: - Keyboard

     override func keyDown(with event: NSEvent) {
         switch event.keyCode {
         case 126: // Up
             move(by: -1)

         case 125: // Down
             move(by: 1)

         case 115: // Home
             select(.stopwatch)

         case 119: // End
             select(.pomodoro)

         default:
             super.keyDown(with: event)
         }
     }

     // MARK: - Drawing

     private func dotCenters() -> [CGFloat] {
         [
             bounds.midY - 20,
             bounds.midY,
             bounds.midY + 20
         ]
     }

     override func draw(_ dirtyRect: NSRect) {
         super.draw(dirtyRect)

         guard bounds.width > 0, bounds.height > 0 else {
             return
         }

         let divider = NSBezierPath()
         divider.move(to: NSPoint(x: 0.5, y: 1))
         divider.line(
             to: NSPoint(x: 0.5, y: bounds.maxY - 1)
         )

         NSColor.white
             .withAlphaComponent(0.07)
             .setStroke()

         divider.lineWidth = 1
         divider.stroke()

         let centers = dotCenters()

         for (index, candidate) in Self.orderedModes.enumerated() {
             let selected = candidate == mode

             let width: CGFloat = 5
             let height: CGFloat = selected ? 13 : 5

             let rect = NSRect(
                 x: bounds.midX - width / 2,
                 y: centers[index] - height / 2,
                 width: width,
                 height: height
             )

             let color = selected
                 ? NSColor.systemOrange
                 : NSColor.white.withAlphaComponent(0.35)

             color.setFill()

             NSBezierPath(
                 roundedRect: rect,
                 xRadius: width / 2,
                 yRadius: width / 2
             ).fill()
         }
     }

     // MARK: - Accessibility

     private func accessibilityModeName(
         _ mode: NotchTimerMode
     ) -> String {
         switch mode {
         case .stopwatch: return FeatureStrings.notchActivities(L10n.shared.language).stopwatch
         case .timer: return FeatureStrings.notchActivities(L10n.shared.language).timer
         case .pomodoro: return FeatureStrings.notchActivities(L10n.shared.language).pomodoro
         }
     }
 }
