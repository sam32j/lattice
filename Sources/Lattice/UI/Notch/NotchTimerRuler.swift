
 // SPDX-License-Identifier: GPL-3.0-or-later
 // Copyright (C) 2026 Lattice

 import AppKit
 import SwiftUI

 /// A native, horizontally scrollable duration ruler.
 ///
 /// The selected minute is always under the center pointer.
 /// Supports mouse dragging, clicking, trackpad scrolling,
 /// keyboard control and accessibility.
 struct NotchTimerRuler: NSViewRepresentable {
     @Binding var minutes: Int

     let label: String
     let locale: Locale
     let range: ClosedRange<Int>

     init(
         minutes: Binding<Int>,
         label: String,
         locale: Locale,
         range: ClosedRange<Int> = 1...180
     ) {
         self._minutes = minutes
         self.label = label
         self.locale = locale
         self.range = range
     }

     func makeCoordinator() -> Coordinator {
         Coordinator(self)
     }

     func sizeThatFits(
         _ proposal: ProposedViewSize,
         nsView: NotchTimerRulerControl,
         context: Context
     ) -> CGSize? {
         CGSize(
             width: proposal.width ?? 300,
             height: proposal.height ?? NotchLayout.timerRulerHeight
         )
     }

     func makeNSView(
         context: Context
     ) -> NotchTimerRulerControl {
         let control = NotchTimerRulerControl()

         control.focusRingType = .none
         control.minValue = Double(range.lowerBound)
         control.maxValue = Double(range.upperBound)
         control.altIncrementValue = 1

         control.target = context.coordinator
         control.action = #selector(Coordinator.changed(_:))

         return control
     }

     func updateNSView(
         _ control: NotchTimerRulerControl,
         context: Context
     ) {
         context.coordinator.parent = self

         control.minValue = Double(range.lowerBound)
         control.maxValue = Double(range.upperBound)

         control.durationLocale = locale
         control.increasedContrast =
             context.environment.colorSchemeContrast == .increased

         control.isEnabled = context.environment.isEnabled
         control.synchronize(minutes: minutes)

         control.setAccessibilityLabel(label)
         control.setAccessibilityValueDescription(
             NotchTimerSupport.compactText(
                 Double(control.integerValue) * 60,
                 locale: locale
             )
         )

         control.needsDisplay = true
     }

     final class Coordinator: NSObject {
         var parent: NotchTimerRuler

         init(_ parent: NotchTimerRuler) {
             self.parent = parent
         }

         @objc func changed(_ sender: NSSlider) {
             guard parent.minutes != sender.integerValue else {
                 return
             }

             parent.minutes = sender.integerValue

             if (sender as? NotchTimerRulerControl)?
                 .feedbackOnChange == true {
                 NotchService.shared.provideHapticFeedback()
             }
         }
     }
 }

 // MARK: - AppKit ruler

 final class NotchTimerRulerControl: NSSlider {
     private(set) var feedbackOnChange = true

     var increasedContrast = false
     var durationLocale = Locale.current

     private var drag: (x: CGFloat, value: Double)?
     private var didDrag = false

     private var scrollValue: Double?
     private var lastScrollTimestamp: TimeInterval?

     private var showsKeyboardFocus = false

     override var isFlipped: Bool { true }
     override var acceptsFirstResponder: Bool { isEnabled }

     private var minuteRange: ClosedRange<Int> {
         Int(minValue)...Int(maxValue)
     }

     // MARK: - Synchronization

     func synchronize(minutes: Int) {
         let bounded = min(
             minuteRange.upperBound,
             max(minuteRange.lowerBound, minutes)
         )

         guard integerValue != bounded else { return }

         integerValue = bounded

         // A change from SwiftUI is authoritative.
         drag = nil
         scrollValue = nil
         lastScrollTimestamp = nil

         needsDisplay = true
     }

     // MARK: - Mouse interaction

     override func mouseDown(with event: NSEvent) {
         guard isEnabled else { return }

         window?.makeFirstResponder(self)

         showsKeyboardFocus = false
         needsDisplay = true

         drag = (
             x: convert(event.locationInWindow, from: nil).x,
             value: doubleValue
         )

         didDrag = false
         scrollValue = nil
         lastScrollTimestamp = nil
     }

     override func mouseDragged(with event: NSEvent) {
         guard isEnabled, let previous = drag else {
             return
         }

         let x = convert(
             event.locationInWindow,
             from: nil
         ).x

         let value = NotchTimerRulerScale.moving(
             previous.value,
             by: Double(x - previous.x)
         )

         // Discard overscroll beyond the configured duration bounds while
         // retaining fractional minutes inside them.
         let clamped = min(Double(minuteRange.upperBound),
                           max(Double(minuteRange.lowerBound), value))
         drag = (x: x, value: clamped)

         didDrag = true
         select(clamped)
     }

     override func mouseUp(with event: NSEvent) {
         guard isEnabled, drag != nil else {
             drag = nil
             return
         }

         if !didDrag {
             // Clicking selects the tick nearest the pointer.
             // The centered pointer remains stationary.
             feedbackOnChange = false
             defer { feedbackOnChange = true }

             let x = convert(
                 event.locationInWindow,
                 from: nil
             ).x

             let offset = x - bounds.midX

             select(
                 NotchTimerRulerScale.moving(
                     doubleValue,
                     by: -Double(offset)
                 )
             )
         }

         drag = nil
     }

     // MARK: - Trackpad / wheel interaction

     override func scrollWheel(with event: NSEvent) {
         guard isEnabled, drag == nil else { return }

         // This gesture adjusts duration only.
         // Mode switching is handled independently
         // by NotchTimerModeRail.
         if event.phase.contains(.began) {
             scrollValue = nil
         }

         // A phase-less mouse wheel starts a new accumulation
         // after a quiet interval.
         if event.phase.isEmpty,
            let last = lastScrollTimestamp,
            event.timestamp - last > 0.45 {
             scrollValue = nil
         }

         lastScrollTimestamp = event.timestamp

         // Select the dominant scrolling direction.
         let delta = abs(event.scrollingDeltaX)
             > abs(event.scrollingDeltaY)
             ? event.scrollingDeltaX
             : event.scrollingDeltaY

         guard delta != 0 else { return }

         let points = Double(delta) * (
             event.hasPreciseScrollingDeltas
                 ? 1
                 : NotchTimerRulerScale.spacing
         )

         let value = NotchTimerRulerScale.moving(
             scrollValue ?? doubleValue,
             by: points
         )

         // Discard excess wheel delta at the range boundary. Otherwise a
         // reverse swipe appears frozen until it undoes all overscroll.
         let clamped = min(Double(minuteRange.upperBound),
                           max(Double(minuteRange.lowerBound), value))
         scrollValue = clamped

         select(clamped)

         if !event.hasPreciseScrollingDeltas
             || event.phase.contains(.ended)
             || event.phase.contains(.cancelled)
             || event.momentumPhase.contains(.ended) {
             scrollValue = nil
         }
     }

     // MARK: - Keyboard

     override func keyDown(with event: NSEvent) {
         guard isEnabled,
               event.modifierFlags
                 .intersection([.command, .control]).isEmpty
         else {
             super.keyDown(with: event)
             return
         }

         scrollValue = nil
         lastScrollTimestamp = nil

         showsKeyboardFocus = true
         needsDisplay = true

         switch event.keyCode {
         case 123, 125: // Left / Down
             select(doubleValue - 1)

         case 124, 126: // Right / Up
             select(doubleValue + 1)

         case 115: // Home
             select(minValue)

         case 119: // End
             select(maxValue)

         default:
             super.keyDown(with: event)
         }
     }

     // MARK: - Accessibility

     override func setAccessibilityValue(_ value: Any?) {
         guard let number = value as? NSNumber,
               number.doubleValue.isFinite else {
             return
         }

         scrollValue = nil
         select(number.doubleValue)
     }

     override func accessibilityPerformIncrement() -> Bool {
         guard isEnabled else { return false }

         scrollValue = nil
         select(doubleValue + 1)
         return true
     }

     override func accessibilityPerformDecrement() -> Bool {
         guard isEnabled else { return false }

         scrollValue = nil
         select(doubleValue - 1)
         return true
     }

     // MARK: - Selection

     private func select(_ value: Double) {
         guard isEnabled, value.isFinite else { return }

         // Bound the floating-point value before converting to Int. VoiceOver
         // can provide a finite number far outside Int's representable range.
         let clamped = min(Double(minuteRange.upperBound),
                           max(Double(minuteRange.lowerBound), value.rounded()))
         let bounded = Int(clamped)

         guard integerValue != bounded else { return }

         integerValue = bounded

         setAccessibilityValueDescription(
             NotchTimerSupport.compactText(
                 Double(bounded) * 60,
                 locale: durationLocale
             )
         )

         needsDisplay = true
         sendAction(action, to: target)
     }

     // MARK: - Rendering

     override func draw(_ dirtyRect: NSRect) {
         guard bounds.width > 0, bounds.height > 0 else {
             return
         }

         let scale = bounds.height
             / NotchLayout.timerRulerHeight

         let edgeFade = max(1, bounds.width * 0.12)

         let selected = integerValue
         let center = bounds.midX

         let minimum = minuteRange.lowerBound
         let maximum = minuteRange.upperBound

         let tickSpacing = CGFloat(
             NotchTimerRulerScale.spacing
         )

         // Draw only ticks near the visible portion.
         let visibleRadius = Int(
             ceil(bounds.width / (2 * tickSpacing))
         ) + 2

         let first = max(minimum, selected - visibleRadius)
         let last = min(maximum, selected + visibleRadius)

         guard first <= last else { return }

         for minute in first...last {
             let x = center + CGFloat(
                 NotchTimerRulerScale.offset(
                     of: minute,
                     selected: selected
                 )
             )

             guard x >= bounds.minX - 16,
                   x <= bounds.maxX + 16 else {
                 continue
             }

             let distanceToEdge = min(
                 x - bounds.minX,
                 bounds.maxX - x
             )

             let fade = min(
                 1,
                 max(0, distanceToEdge / edgeFade)
             )

             let strength: CGFloat

             if minute == selected {
                 strength = 1
             } else if abs(minute - selected) <= 4 {
                 strength = 0.8
             } else if minute < selected {
                 strength = 0.6
             } else {
                 strength = increasedContrast ? 0.65 : 0.35
             }

             let alpha = fade
                 * strength
                 * (isEnabled ? 1 : 0.4)

             let color = NSColor.systemOrange
                 .withAlphaComponent(alpha)

             color.setFill()

             // Tick marks: fixed spacing, slightly taller
             // at labeled intervals.
             let major = minute.isMultiple(of: 5)
                 || minute == minimum

             let height: CGFloat = major ? 38 : 33

             let tick = NSRect(
                 x: x - 2,
                 y: (65 - height) * scale,
                 width: 4,
                 height: height * scale
             )

             NSBezierPath(
                 roundedRect: tick,
                 xRadius: 2,
                 yRadius: 2
             ).fill()

             if major {
                 let title = NSAttributedString(
                     string: NotchTimerRulerScale.label(
                         for: minute
                     ),
                     attributes: [
                         .font: NSFont.monospacedDigitSystemFont(
                             ofSize: 14,
                             weight: .medium
                         ),
                         .foregroundColor: color
                     ]
                 )

                 title.draw(
                     at: NSPoint(
                         x: x - title.size().width / 2,
                         y: 0
                     )
                 )
             }
         }

         // The selection marker stays fixed while ticks move.
         let pointer = NSBezierPath()

         pointer.move(
             to: NSPoint(x: center, y: 70 * scale)
         )
         pointer.line(
             to: NSPoint(x: center + 7, y: 80 * scale)
         )
         pointer.line(
             to: NSPoint(x: center - 7, y: 80 * scale)
         )
         pointer.close()

         NSColor.systemOrange
             .withAlphaComponent(isEnabled ? 1 : 0.4)
             .setFill()

         pointer.fill()

         if window?.firstResponder === self,
            showsKeyboardFocus {
             NSColor.systemOrange.setStroke()

             let focus = NSBezierPath(
                 roundedRect: bounds.insetBy(dx: 1, dy: 1),
                 xRadius: 7,
                 yRadius: 7
             )

             focus.lineWidth = 1
             focus.stroke()
         }
     }

     // MARK: - Focus

     override func becomeFirstResponder() -> Bool {
         let accepted = super.becomeFirstResponder()

         showsKeyboardFocus = accepted
         needsDisplay = true

         return accepted
     }

     override func resignFirstResponder() -> Bool {
         let accepted = super.resignFirstResponder()

         showsKeyboardFocus = false
         needsDisplay = true

         return accepted
     }
 }
