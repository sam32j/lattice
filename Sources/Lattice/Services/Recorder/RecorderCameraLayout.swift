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
            switch self { case .circle, .square: 1; case .rectangle: 1.52; case .vertical: 1 / 1.52 }
        }
    }
    var size: Size = .medium
    var shape: Shape = .circle
    var isFlipped = false
    var isFullArea = false
    var pixelsPerPoint: CGFloat = 1
    var edgePadding: CGFloat = 5.0
    private var position = CGPoint(x: 1, y: 0)

    func cornerRadius(in frame: CGRect) -> CGFloat {
        if isFullArea { return 0 }
        let halfSide = min(frame.width, frame.height) / 2
        return shape == .circle ? halfSide : min(20 * pixelsPerPoint, halfSide)
    }

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
        let x = min(max(origin.x, bounds.minX), bounds.maxX - current.width)
        let y = min(max(origin.y, bounds.minY), bounds.maxY - current.height)
        position = CGPoint(x: bounds.width > current.width ? (x - bounds.minX) / (bounds.width - current.width) : 0,
                           y: bounds.height > current.height ? (y - bounds.minY) / (bounds.height - current.height) : 0)
    }

    mutating func snapToNearestEdge(in canvas: CGSize) {
        guard !isFullArea else { return }
        let bounds = usableBounds(canvas)
        let current = frame(in: canvas)
        guard bounds.width > current.width || bounds.height > current.height else { return }

        let distLeft = current.minX - bounds.minX
        let distRight = bounds.maxX - current.maxX
        let distBottom = current.minY - bounds.minY
        let distTop = bounds.maxY - current.maxY

        let minDist = min(distLeft, distRight, distBottom, distTop)
        if minDist == distLeft {
            position.x = 0
        } else if minDist == distRight {
            position.x = 1
        } else if minDist == distBottom {
            position.y = 0
        } else {
            position.y = 1
        }
    }

    private func usableBounds(_ canvas: CGSize) -> CGRect {
        let padding = edgePadding * max(1, pixelsPerPoint)
        let target = dimensions(.small)
        guard canvas.width >= target.width + padding * 2, canvas.height >= target.height + padding * 2 else {
            return CGRect(origin: .zero, size: canvas)
        }
        return CGRect(origin: .zero, size: canvas).insetBy(dx: padding, dy: padding)
    }
    private func dimensions(_ size: Size) -> CGSize {
        let longest = min(500, size.longestSide)
        return shape.aspect >= 1 ? CGSize(width: longest, height: longest / shape.aspect)
            : CGSize(width: longest * shape.aspect, height: longest)
    }
}
