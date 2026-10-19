// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

/// All geometry is in output pixels, independent of the display's scale.
struct RecorderCameraLayout: Equatable {
    enum Size: String, CaseIterable { case small, medium, big
        var longestSide: CGFloat {
            switch self { case .small: 192; case .medium: 320; case .big: 480 }
        }
    }
    enum Shape: String, CaseIterable { case circle, square, rectangle, vertical
        var aspect: CGFloat {
            switch self { case .circle, .square: 1; case .rectangle: 1.47; case .vertical: 1 / 1.47 }
        }
    }
    var size: Size = .medium
    var shape: Shape = .circle
    var isFlipped = false
    var isFullArea = false
    private var position = CGPoint(x: 1, y: 0)

    func isAvailable(_ size: Size, in canvas: CGSize) -> Bool {
        guard canvas.width.isFinite, canvas.height.isFinite, canvas.width > 0, canvas.height > 0 else { return false }
        if size == .small { return true }
        let bounds = usableBounds(canvas)
        let target = dimensions(size)
        return target.width <= bounds.width && target.height <= bounds.height
    }

    func frame(in canvas: CGSize) -> CGRect {
        guard canvas.width.isFinite, canvas.height.isFinite, canvas.width > 0, canvas.height > 0 else { return .zero }
        if isFullArea { return CGRect(origin: .zero, size: canvas) }
        let bounds = usableBounds(canvas)
        let target = dimensions(isAvailable(size, in: canvas) ? size : .small)
        let scale = min(1, bounds.width / target.width, bounds.height / target.height)
        let fitted = CGSize(width: target.width * scale, height: target.height * scale)
        return CGRect(x: bounds.minX + position.x * (bounds.width - fitted.width),
                      y: bounds.minY + position.y * (bounds.height - fitted.height),
                      width: fitted.width, height: fitted.height)
    }

    mutating func place(origin: CGPoint, in canvas: CGSize) {
        guard !isFullArea, origin.x.isFinite, origin.y.isFinite else { return }
        let bounds = usableBounds(canvas)
        let current = frame(in: canvas)
        func snapped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
            let clamped = min(max(value, lower), upper)
            if clamped - lower < 18 {
                let distance = clamped - lower
                return distance < 2 ? lower : lower + distance * distance / 18
            }
            if upper - clamped < 18 {
                let distance = upper - clamped
                return distance < 2 ? upper : upper - distance * distance / 18
            }
            return clamped
        }
        let x = snapped(origin.x, lower: bounds.minX, upper: bounds.maxX - current.width)
        let y = snapped(origin.y, lower: bounds.minY, upper: bounds.maxY - current.height)
        position = CGPoint(x: bounds.width > current.width ? (x - bounds.minX) / (bounds.width - current.width) : 0,
                           y: bounds.height > current.height ? (y - bounds.minY) / (bounds.height - current.height) : 0)
    }

    private func usableBounds(_ canvas: CGSize) -> CGRect {
        let margin = min(12, canvas.width * 0.04, canvas.height * 0.04)
        return CGRect(origin: .zero, size: canvas).insetBy(dx: margin, dy: margin)
    }
    private func dimensions(_ size: Size) -> CGSize {
        let longest = min(500, size.longestSide)
        return shape.aspect >= 1 ? CGSize(width: longest, height: longest / shape.aspect)
            : CGSize(width: longest * shape.aspect, height: longest)
    }
}
