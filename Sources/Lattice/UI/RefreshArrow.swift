// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// A refresh arrow that turns while work is running, in place of a spinner.
///
/// The arrow is drawn here, centered on its own circle, so it turns about its
/// true center; the SF Symbol's circle sits off its bounds' center, and the
/// SF Symbols rotate effect eases each turn in and out. Turns run at a steady
/// pace, one whole turn at a time: when the work ends, the turn in progress
/// completes and the arrow stops at rest. It is sized by an invisible SF
/// Symbol, so `.font` and `.foregroundStyle` work as on a symbol. Reduce
/// Motion keeps it still.
struct RefreshArrow: View {
    let isSpinning: Bool

    /// One turn, at a steady pace.
    static let turnDuration: TimeInterval = 0.8

    @State private var angle = 0.0
    @State private var isTurning = false
    /// The live value of `isSpinning`. A scheduled closure reads state, which
    /// is current; a captured `let` keeps the value from when it was made.
    @State private var wantsToSpin = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "arrow.clockwise")
            .hidden()
            .overlay { RefreshGlyph().rotationEffect(.degrees(angle)) }
            .onChange(of: isSpinning, initial: true) { _, spinning in
                wantsToSpin = spinning
                if spinning { turn() }
            }
            .accessibilityHidden(true)
    }

    private func turn() {
        guard !reduceMotion, !isTurning else { return }
        isTurning = true
        withAnimation(.linear(duration: Self.turnDuration)) { angle += 360 }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.turnDuration) {
            isTurning = false
            if wantsToSpin { turn() }
        }
    }
}

/// A circular arrow: an open arc with an arrowhead at its upper end, centered
/// in its square so it can turn without wobbling.
private struct RefreshGlyph: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let line = max(1, side * 0.1)
            ZStack {
                // Like arrow.clockwise: open at the upper right, running
                // clockwise from about half past two round to the arrowhead
                // just past twelve.
                Circle()
                    .trim(from: 0, to: RefreshArrowHead.sweep)
                    .stroke(style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(RefreshArrowHead.tailAngle - 90))
                    .padding(side * 0.14)
                RefreshArrowHead()
                    .fill()
                    .frame(width: side, height: side)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// The arrowhead at the arc's end, just past twelve o'clock, pointing clockwise.
private struct RefreshArrowHead: Shape {
    /// Where the open tail starts, in degrees clockwise from twelve o'clock.
    static let tailAngle = 75.0
    /// How much of the circle the arc covers.
    static let sweep = 300.0 / 360

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = side / 2 - side * 0.14
        let end = Angle.degrees(Self.tailAngle + Self.sweep * 360 - 90)
        let tip = CGPoint(x: center.x + radius * cos(end.radians), y: center.y + radius * sin(end.radians))
        // Tangent pointing clockwise along the circle at the end.
        let tangent = CGVector(dx: -sin(end.radians), dy: cos(end.radians))
        let normal = CGVector(dx: cos(end.radians), dy: sin(end.radians))
        let length = side * 0.26, width = side * 0.2
        var path = Path()
        path.move(to: CGPoint(x: tip.x + tangent.dx * length * 0.55, y: tip.y + tangent.dy * length * 0.55))
        path.addLine(to: CGPoint(x: tip.x - tangent.dx * length * 0.45 + normal.dx * width,
                                 y: tip.y - tangent.dy * length * 0.45 + normal.dy * width))
        path.addLine(to: CGPoint(x: tip.x - tangent.dx * length * 0.45 - normal.dx * width,
                                 y: tip.y - tangent.dy * length * 0.45 - normal.dy * width))
        path.closeSubpath()
        return path
    }
}
