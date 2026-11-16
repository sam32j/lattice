// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// An SF Symbol, or one of Lattice's own glyphs where SF Symbols has none.
///
/// SF Symbols has no Bluetooth mark. Everything Bluetooth in Lattice names
/// `bluetoothSymbol`, a real SF Symbol, so any view still drawing it with
/// `Image(systemName:)` shows radio waves; this view draws the Bluetooth
/// rune in its place. The rune is sized by an invisible SF Symbol of the same
/// font, so `.font`, `.imageScale` and `.foregroundStyle` work as they do on
/// a symbol.
struct LatticeSymbol: View {
    /// The SF Symbol every Bluetooth surface names. Nothing else uses it.
    static let bluetoothSymbol = "dot.radiowaves.left.and.right"

    let name: String

    init(_ name: String) { self.name = name }

    var body: some View {
        if name == Self.bluetoothSymbol {
            Image(systemName: "square")
                .hidden()
                .overlay { BluetoothGlyph() }
                .accessibilityHidden(true)
        } else {
            Image(systemName: name)
        }
    }
}

/// The Bluetooth rune: a vertical stroke with two closed arrowheads to the
/// right, crossed by the two diagonals. Drawn in the current foreground style.
struct BluetoothGlyph: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            BluetoothRune()
                .stroke(style: StrokeStyle(lineWidth: max(1, side * 0.11), lineCap: .round, lineJoin: .round))
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct BluetoothRune: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        path.move(to: point(0.27, 0.30))
        path.addLine(to: point(0.73, 0.70))
        path.addLine(to: point(0.50, 0.92))
        path.addLine(to: point(0.50, 0.08))
        path.addLine(to: point(0.73, 0.30))
        path.addLine(to: point(0.27, 0.70))
        return path
    }
}
