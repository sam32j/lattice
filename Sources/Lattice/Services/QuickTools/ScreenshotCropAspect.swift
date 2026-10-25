// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics

enum ScreenshotCropAspect: String, CaseIterable {
    case free, original, square = "1:1", photo = "4:3", classic = "3:2", wide = "16:9", portrait = "9:16"

    func ratio(imageSize: CGSize) -> CGFloat? {
        switch self {
        case .free: nil
        case .original: imageSize.height > 0 ? imageSize.width / imageSize.height : nil
        case .square: 1
        case .photo: 4 / 3
        case .classic: 3 / 2
        case .wide: 16 / 9
        case .portrait: 9 / 16
        }
    }

    func fitted(_ rect: CGRect, within bounds: CGRect, imageSize: CGSize) -> CGRect {
        guard let ratio = ratio(imageSize: imageSize), ratio > 0 else { return ScreenshotSupport.clamp(rect, to: bounds) }
        let width = min(rect.width, rect.height * ratio, bounds.width, bounds.height * ratio)
        let height = width / ratio
        return CGRect(x: min(max(rect.midX - width / 2, bounds.minX), bounds.maxX - width),
                      y: min(max(rect.midY - height / 2, bounds.minY), bounds.maxY - height),
                      width: width, height: height)
    }

    func resized(_ rect: CGRect, handle: ScreenshotSupport.Handle, to point: CGPoint,
                 within bounds: CGRect, imageSize: CGSize) -> CGRect {
        let free = ScreenshotSupport.resizedRect(rect, dragging: handle, to: point)
        guard let ratio = ratio(imageSize: imageSize) else { return ScreenshotSupport.clamp(free, to: bounds) }
        switch handle {
        case .left, .right:
            let anchorX = handle == .left ? rect.maxX : rect.minX
            let extendsLeft = point.x < anchorX
            let availableWidth = extendsLeft ? anchorX - bounds.minX : bounds.maxX - anchorX
            let availableHeight = 2 * min(rect.midY - bounds.minY, bounds.maxY - rect.midY)
            let width = max(0, min(abs(point.x - anchorX), availableWidth, availableHeight * ratio))
            return CGRect(x: extendsLeft ? anchorX - width : anchorX, y: rect.midY - width / ratio / 2,
                          width: width, height: width / ratio)
        case .top, .bottom:
            let anchorY = handle == .top ? rect.maxY : rect.minY
            let extendsUp = point.y < anchorY
            let availableHeight = extendsUp ? anchorY - bounds.minY : bounds.maxY - anchorY
            let availableWidth = 2 * min(rect.midX - bounds.minX, bounds.maxX - rect.midX)
            let height = max(0, min(abs(point.y - anchorY), availableHeight, availableWidth / ratio))
            return CGRect(x: rect.midX - height * ratio / 2, y: extendsUp ? anchorY - height : anchorY,
                          width: height * ratio, height: height)
        default:
            let opposite: CGPoint
            switch handle {
            case .topLeft: opposite = CGPoint(x: rect.maxX, y: rect.maxY)
            case .topRight: opposite = CGPoint(x: rect.minX, y: rect.maxY)
            case .bottomLeft: opposite = CGPoint(x: rect.maxX, y: rect.minY)
            default: opposite = rect.origin
            }
            let desired = ScreenshotEditorGeometry.aspectRect(from: opposite, to: point, aspect: ratio)
            let left = point.x < opposite.x, up = point.y < opposite.y
            let availableWidth = left ? opposite.x - bounds.minX : bounds.maxX - opposite.x
            let availableHeight = up ? opposite.y - bounds.minY : bounds.maxY - opposite.y
            let width = max(0, min(desired.width, availableWidth, availableHeight * ratio))
            return CGRect(x: left ? opposite.x - width : opposite.x, y: up ? opposite.y - width / ratio : opposite.y,
                          width: width, height: width / ratio)
        }
    }
}
