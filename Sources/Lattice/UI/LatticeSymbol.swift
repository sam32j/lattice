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
    static let mediaSymbol = "lattice.media"
    static let cleanerSymbol = "lattice.cleaner"

    static func isCustom(_ name: String) -> Bool {
        [bluetoothSymbol, appManagerSymbol, videoDownloaderSymbol, mediaSymbol, cleanerSymbol].contains(name)
    }

    var body: some View {
        switch name {
        case Self.bluetoothSymbol:
            glyph { BluetoothGlyph() }
        case Self.appManagerSymbol:
            glyph { AppManagerGlyph() }
        case Self.videoDownloaderSymbol:
            glyph { VideoDownloaderGlyph() }
        case Self.mediaSymbol:
            glyph { MediaCompressionGlyph() }
        case Self.cleanerSymbol:
            glyph { CleanerGlyph() }
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
    /// Stroke widths on the 100-point grid, a touch heavier than the source
    /// drawing so it reads at the weight of the SF Symbols beside it.
    static let frameWidth: CGFloat = 8.0
    static let arrowWidth: CGFloat = 4.4

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let scale = side / 100
            ZStack {
                VideoDownloaderFrame()
                    .stroke(.foreground, style: StrokeStyle(lineWidth: Self.frameWidth * scale,
                                                            lineCap: .butt, lineJoin: .round))
                VideoDownloaderPlay()
                    .fill(.foreground)
                    // The play mark sits a little small in the source.
                    .scaleEffect(1.18, anchor: UnitPoint(x: 0.47, y: 0.46))
                ZStack {
                    Circle()
                        .fill(.foreground)
                        .frame(width: 38 * scale, height: 38 * scale)
                        .position(x: 73 * scale, y: 66 * scale)
                    VideoDownloaderArrow()
                        .stroke(.black, style: StrokeStyle(lineWidth: Self.arrowWidth * scale,
                                                           lineCap: .round, lineJoin: .round))
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            }
            .frame(width: side, height: side)
            // The drawing spans x 10 to 92 and y 18 to 85; centre it.
            .offset(x: -1 * scale, y: -1.5 * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        // Wide like play.rectangle, it fills the symbol's width.
        .scaleEffect(1.3)
    }
}

/// Media Compression's mark: a frame drawn in at its middle between two caps,
/// on a 100-point grid.
struct MediaCompressionGlyph: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                MediaCompressionCaps().fill(.foreground)
                MediaCompressionOutline()
                    .stroke(.foreground, style: StrokeStyle(lineWidth: 7 * side / 100, lineCap: .round, lineJoin: .round))
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .scaleEffect(1.12)
    }
}

struct MediaCompressionCaps: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { gridPoint(x, y, in: rect) }
        var path = Path()
        for (edge, inner, curve) in [(CGFloat(11), CGFloat(29.5), CGFloat(1)), (89, 70.5, -1)] {
            let d = curve
            path.move(to: p(35, edge))
            path.addLine(to: p(65, edge))
            path.addCurve(to: p(68.5, edge + 6.5 * d), control1: p(68.5, edge), control2: p(70.5, edge + 2.5 * d))
            path.addCurve(to: p(50, inner), control1: p(65, edge + 13.5 * d), control2: p(58.5, inner))
            path.addCurve(to: p(31.5, edge + 6.5 * d), control1: p(41.5, inner), control2: p(35, edge + 13.5 * d))
            path.addCurve(to: p(35, edge), control1: p(29.5, edge + 2.5 * d), control2: p(31.5, edge))
            path.closeSubpath()
        }
        return path
    }
}

struct MediaCompressionOutline: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { gridPoint(x, y, in: rect) }
        var path = Path()
        path.move(to: p(14, 69))
        path.addLine(to: p(14, 31))
        path.addCurve(to: p(23, 28.5), control1: p(14, 24.5), control2: p(19, 24.5))
        path.addCurve(to: p(50, 41), control1: p(33, 38.5), control2: p(41, 41))
        path.addCurve(to: p(77, 28.5), control1: p(59, 41), control2: p(67, 38.5))
        path.addCurve(to: p(86, 31), control1: p(81, 24.5), control2: p(86, 24.5))
        path.addLine(to: p(86, 69))
        path.addCurve(to: p(77, 71.5), control1: p(86, 75.5), control2: p(81, 75.5))
        path.addCurve(to: p(50, 59), control1: p(67, 61.5), control2: p(59, 59))
        path.addCurve(to: p(23, 71.5), control1: p(41, 59), control2: p(33, 61.5))
        path.addCurve(to: p(14, 69), control1: p(19, 75.5), control2: p(14, 75.5))
        path.closeSubpath()
        return path
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

/// The Cleaner utility's mark: a diagonal broom with two four-point sparkles,
/// drawn on a 100-point grid in the current foreground style.
struct CleanerGlyph: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let scale = side / 100
            ZStack {
                CleanerBroomBody()
                    .stroke(.foreground, style: StrokeStyle(lineWidth: 6.4 * scale, lineCap: .round, lineJoin: .round))
                CleanerCollar()
                    .stroke(.foreground, style: StrokeStyle(lineWidth: 11.0 * scale, lineCap: .round, lineJoin: .round))
                CleanerSparkles()
                    .fill(.foreground)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .scaleEffect(1.22)
    }
}

struct CleanerBroomBody: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { gridPoint(x, y, in: rect) }
        var path = Path()
        // Handle
        path.move(to: p(77.5, 22.5))
        path.addLine(to: p(55.5, 44.5))
        // Flared broom head outline
        path.move(to: p(44.5, 40.0))
        path.addQuadCurve(to: p(13.0, 56.5), control: p(31.5, 49.5))
        path.addQuadCurve(to: p(12.5, 61.5), control: p(9.5, 58.5))
        path.addLine(to: p(38.5, 87.5))
        path.addQuadCurve(to: p(43.5, 87.0), control: p(41.5, 90.5))
        path.addQuadCurve(to: p(60.0, 55.5), control: p(50.5, 68.5))
        // Inner bristle strokes
        path.move(to: p(21.5, 70.5))
        path.addLine(to: p(33.5, 59.5))
        path.move(to: p(29.5, 78.5))
        path.addLine(to: p(39.0, 69.0))
        return path
    }
}

struct CleanerCollar: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { gridPoint(x, y, in: rect) }
        var path = Path()
        path.move(to: p(45.5, 40.5))
        path.addLine(to: p(59.5, 54.5))
        return path
    }
}

struct CleanerSparkles: Shape {
    func path(in rect: CGRect) -> Path {
        func addStar(cx: CGFloat, cy: CGFloat, r: CGFloat, to path: inout Path) {
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { gridPoint(x, y, in: rect) }
            let c = p(cx, cy)
            path.move(to: p(cx, cy - r))
            path.addQuadCurve(to: p(cx + r, cy), control: c)
            path.addQuadCurve(to: p(cx, cy + r), control: c)
            path.addQuadCurve(to: p(cx - r, cy), control: c)
            path.addQuadCurve(to: p(cx, cy - r), control: c)
            path.closeSubpath()
        }
        var path = Path()
        addStar(cx: 25.0, cy: 25.0, r: 9.0, to: &path)
        addStar(cx: 77.0, cy: 74.5, r: 7.5, to: &path)
        return path
    }
}
