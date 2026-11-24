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

    /// Lattice's own glyphs, named like symbols so every surface that takes a
    /// symbol name can show them.
    static let appManagerSymbol = "lattice.app.manager"
    static let videoDownloaderSymbol = "lattice.video.downloader"

    static func isCustom(_ name: String) -> Bool {
        name == bluetoothSymbol || name == appManagerSymbol || name == videoDownloaderSymbol
    }

    var body: some View {
        switch name {
        case Self.bluetoothSymbol:
            glyph { BluetoothGlyph() }
        case Self.appManagerSymbol:
            glyph { AppManagerGlyph() }
        case Self.videoDownloaderSymbol:
            glyph { VideoDownloaderGlyph() }
        default:
            Image(systemName: name)
        }
    }

    /// Sized like the symbol it stands in for, in the current font.
    private func glyph<Glyph: View>(@ViewBuilder _ content: () -> Glyph) -> some View {
        Image(systemName: "square")
            .opacity(0)
            .overlay { content() }
            .accessibilityHidden(true)
    }
}

/// The App Manager's mark: an "A" of rounded strokes, drawn on a 100-point
/// grid and filled in the current foreground style.
struct AppManagerGlyph: View {
    var body: some View {
        AppManagerMark()
            .fill(.foreground)
            .aspectRatio(1, contentMode: .fit)
            .scaleEffect(1.12)
    }
}

struct AppManagerMark: Shape {
    /// Each stroke: its outline's corners, with `cap` marking the pair whose
    /// edge is a round cap (a half circle swept clockwise from the first).
    private static let strokes: [(points: [CGPoint], cap: Int)] = [
        ([CGPoint(x: 27.48, y: 60.00), CGPoint(x: 45.80, y: 19.12), CGPoint(x: 54.20, y: 22.88),
          CGPoint(x: 37.56, y: 60.00)], 1),
        ([CGPoint(x: 23.53, y: 68.80), CGPoint(x: 33.61, y: 68.80), CGPoint(x: 28.20, y: 80.88),
          CGPoint(x: 19.80, y: 77.12)], 2),
        ([CGPoint(x: 52.30, y: 37.38), CGPoint(x: 57.34, y: 26.13), CGPoint(x: 80.20, y: 77.12),
          CGPoint(x: 71.80, y: 80.88)], 2),
        ([CGPoint(x: 55.78, y: 55.40), CGPoint(x: 59.90, y: 64.60), CGPoint(x: 18.00, y: 64.60),
          CGPoint(x: 18.00, y: 55.40)], 2),
        ([CGPoint(x: 65.42, y: 55.40), CGPoint(x: 82.00, y: 55.40), CGPoint(x: 82.00, y: 64.60),
          CGPoint(x: 69.54, y: 64.60)], 1),
    ]

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 100
        func point(_ p: CGPoint) -> CGPoint {
            CGPoint(x: rect.midX + (p.x - 50) * scale, y: rect.midY + (p.y - 50) * scale)
        }
        var path = Path()
        for stroke in Self.strokes {
            let points = stroke.points.map(point)
            path.move(to: points[0])
            for index in 1..<points.count {
                if index == stroke.cap + 1 {
                    Self.addCap(to: &path, from: points[index - 1], to: points[index])
                } else {
                    path.addLine(to: points[index])
                }
            }
            if stroke.cap == points.count - 1 {
                Self.addCap(to: &path, from: points[points.count - 1], to: points[0])
            }
            path.closeSubpath()
        }
        return path
    }

    /// A half circle from `start` to `end`, swept clockwise on screen, as two
    /// quarter arcs through the point opposite the chord.
    private static func addCap(to path: inout Path, from start: CGPoint, to end: CGPoint) {
        let center = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let radius = hypot(start.x - center.x, start.y - center.y)
        let out = CGPoint(x: -(start.y - center.y), y: start.x - center.x)
        let apex = CGPoint(x: center.x + out.x, y: center.y + out.y)
        path.addArc(tangent1End: CGPoint(x: start.x + out.x, y: start.y + out.y), tangent2End: apex, radius: radius)
        path.addArc(tangent1End: CGPoint(x: end.x + out.x, y: end.y + out.y), tangent2End: end, radius: radius)
    }
}

/// The Video Downloader's mark: a player window with a play button and a
/// download badge at its corner, on a 100-point grid.
struct VideoDownloaderGlyph: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let scale = side / 100
            ZStack {
                VideoDownloaderFrame()
                    .stroke(.foreground, style: StrokeStyle(lineWidth: 6 * scale, lineCap: .butt, lineJoin: .round))
                VideoDownloaderPlay().fill(.foreground)
                ZStack {
                    Circle()
                        .fill(.foreground)
                        .frame(width: 36 * scale, height: 36 * scale)
                        .position(x: 73 * scale, y: 66 * scale)
                    VideoDownloaderArrow()
                        .stroke(.black, style: StrokeStyle(lineWidth: 3.8 * scale, lineCap: .round, lineJoin: .round))
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .scaleEffect(1.1)
    }
}

private func gridPoint(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
    let scale = min(rect.width, rect.height) / 100
    return CGPoint(x: rect.minX + x * scale, y: rect.minY + y * scale)
}

struct VideoDownloaderFrame: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 100
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { gridPoint(x, y, in: rect) }
        var path = Path()
        path.move(to: p(51, 70))
        path.addLine(to: p(24, 70))
        path.addArc(tangent1End: p(14, 70), tangent2End: p(14, 60), radius: 10 * scale)
        path.addLine(to: p(14, 32))
        path.addArc(tangent1End: p(14, 22), tangent2End: p(24, 22), radius: 10 * scale)
        path.addLine(to: p(70, 22))
        path.addArc(tangent1End: p(80, 22), tangent2End: p(80, 32), radius: 10 * scale)
        path.addLine(to: p(80, 45))
        return path
    }
}

struct VideoDownloaderPlay: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { gridPoint(x, y, in: rect) }
        var path = Path()
        path.move(to: p(43.2, 37.3))
        path.addLine(to: p(55.4, 44.4))
        path.addCurve(to: p(55.4, 47.6), control1: p(56.8, 45.2), control2: p(56.8, 46.8))
        path.addLine(to: p(43.2, 54.7))
        path.addCurve(to: p(40.2, 52.9), control1: p(41.8, 55.5), control2: p(40.2, 54.5))
        path.addLine(to: p(40.2, 39.1))
        path.addCurve(to: p(43.2, 37.3), control1: p(40.2, 37.5), control2: p(41.8, 36.5))
        path.closeSubpath()
        return path
    }
}

struct VideoDownloaderArrow: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { gridPoint(x, y, in: rect) }
        var path = Path()
        path.move(to: p(73, 56.5))
        path.addLine(to: p(73, 74.5))
        path.move(to: p(65.5, 67.5))
        path.addLine(to: p(73, 75))
        path.addLine(to: p(80.5, 67.5))
        return path
    }
}

/// The Bluetooth rune: a vertical stroke with two closed arrowheads to the
/// right, crossed by the two diagonals. Drawn in the current foreground style.
struct BluetoothGlyph: View {
    var body: some View {
        BluetoothRune()
            .stroke(.foreground, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            .aspectRatio(1, contentMode: .fit)
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
