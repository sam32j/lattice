// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

// swiftc -parse-as-library Sources/Lattice/UI/Settings/SettingsExpansionAnimation.swift \
//   Tools/SettingsExpansionProbe.swift -o /tmp/lattice-settings-expansion-probe
// /tmp/lattice-settings-expansion-probe
import AppKit
import SwiftUI

private final class ExpansionMeasurements: @unchecked Sendable {
    private let lock = NSLock()
    private var cards: [CGFloat] = []
    private var controls: [CGFloat] = []
    var cardHeights: [CGFloat] { lock.withLock { cards } }
    var controlHeights: [CGFloat] { lock.withLock { controls } }
    func recordCard(_ height: CGFloat) { lock.withLock { cards.append(height) } }
    func recordControl(_ height: CGFloat) { lock.withLock { controls.append(height) } }
    func resetCards() { lock.withLock { cards = [] } }
}

private struct MeasuredShape: Shape {
    let record: @Sendable (CGFloat) -> Void
    func path(in rect: CGRect) -> Path {
        record(rect.height)
        return RoundedRectangle(cornerRadius: 16).path(in: rect)
    }
}

@MainActor
private final class ExpansionProbeState: ObservableObject {
    @Published var expanded = false
    @Published var nested = false
}

private struct ExpansionProbeView: View {
    @ObservedObject var state: ExpansionProbeState
    let measurements: ExpansionMeasurements

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Color.blue.frame(height: 40)
                if state.expanded {
                    VStack(spacing: 10) {
                        MeasuredShape { measurements.recordControl($0) }
                            .fill(.red).frame(height: 40)
                        Color.green.frame(height: 40)
                        if state.nested { Color.orange.frame(height: 40) }
                    }
                }
            }
            .padding(16)
            .background(MeasuredShape { measurements.recordCard($0) }.fill(.gray))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            Color.purple.frame(height: 40)
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 500, height: 600, alignment: .topLeading)
        #if !SETTINGS_EXPANSION_BASELINE
        .settingsExpansionAnimation(value: [state.expanded, state.nested])
        #endif
    }
}

@main
@MainActor
// Shape paths observe SwiftUI's animated drawing geometry. AppKit cacheDisplay
// can mix target-layer positions and presentation drawing during an animation,
// so pixel snapshots alone cannot establish synchronized animation geometry.
enum SettingsExpansionProbe {
    private static var checks = 0

    static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let state = ExpansionProbeState()
        let measurements = ExpansionMeasurements()
        let host = NSHostingView(rootView: ExpansionProbeView(state: state, measurements: measurements))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 500, height: 600),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        advance(0.1)
        expect(near(measurements.cardHeights.last, 72), "collapsed card contains only its header and padding")
        measurements.resetCards()
        state.expanded = true
        advance(0.25)
        expect(near(measurements.cardHeights.last, 174), "expansion adds the natural content height and gap")
        if !reduced {
            expect(measurements.cardHeights.contains { $0 > 77 && $0 < 169 },
                   "opening draws intermediate card heights")
        }
        expect(!measurements.controlHeights.isEmpty && measurements.controlHeights.allSatisfy { abs($0 - 40) < 0.1 },
               "revealed controls retain their natural height")
        state.nested = true
        advance(0.25)
        expect(near(measurements.cardHeights.last, 224), "nested follow-up grows its ancestor")
        state.nested = false
        advance(0.25)
        expect(near(measurements.cardHeights.last, 174), "nested collapse restores spacing")
        measurements.resetCards()
        state.expanded = false
        advance(0.25)
        if !reduced {
            expect(measurements.cardHeights.contains { $0 > 77 && $0 < 169 },
                   "collapse draws intermediate card heights")
        }
        expect(near(measurements.cardHeights.last, 72), "collapse leaves no hidden-row gap")
        state.expanded = true
        advance(0.04)
        state.expanded = false
        advance(0.04)
        state.expanded = true
        advance(0.25)
        expect(near(measurements.cardHeights.last, 174), "rapid reversal settles expanded")
        var immediate = Transaction()
        immediate.disablesAnimations = true
        measurements.resetCards()
        withTransaction(immediate) { state.expanded = false }
        advance(0.02)
        expect(near(measurements.cardHeights.last, 72), "disabled transactions remain immediate")
        print("SETTINGS_EXPANSION_OK (\(checks) checks; Reduce Motion=\(reduced))")
    }

    private static func near(_ actual: CGFloat?, _ expected: CGFloat) -> Bool {
        actual.map { abs($0 - expected) < 0.1 } ?? false
    }

    private static func advance(_ seconds: TimeInterval) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        guard condition() else {
            fputs("SETTINGS_EXPANSION_FAILED: \(message)\n", stderr)
            exit(1)
        }
    }
}
