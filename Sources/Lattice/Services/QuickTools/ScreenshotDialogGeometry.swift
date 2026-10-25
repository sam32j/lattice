import CoreGraphics

/// A system prompt may have a large transparent server-side window around its
/// visible card. Use only captured alpha, never OCR or a guessed fixed inset.
enum ScreenshotDialogGeometry {
    static func content(in image: CGImage, windowFrame: CGRect) -> (image: CGImage, frame: CGRect)? {
        let width = image.width, height = image.height
        guard width > 0, height > 0, width <= 4096, height <= 4096,
              width * height <= 16_000_000, windowFrame.width > 0, windowFrame.height > 0 else { return nil }
        let stride = width * 4
        var pixels = [UInt8](repeating: 0, count: stride * height)
        let bounds: CGRect? = pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: stride, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)
            else { return nil }
            // Drawing into the normalized buffer gives the image-space rows
            // used by CGImage.cropping and the window server's top-left frame.
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            var minX = width, minY = height, maxX = -1, maxY = -1
            let data = bytes.bindMemory(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width where data[y * stride + x * 4 + 3] >= 192 {
                    minX = min(minX, x); minY = min(minY, y)
                    maxX = max(maxX, x); maxY = max(maxY, y)
                }
            }
            guard maxX >= minX, maxY >= minY else { return nil }
            return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        }
        guard let bounds, let cropped = image.cropping(to: bounds) else { return nil }
        let xScale = windowFrame.width / CGFloat(width), yScale = windowFrame.height / CGFloat(height)
        let frame = CGRect(x: windowFrame.minX + bounds.minX * xScale,
            y: windowFrame.minY + bounds.minY * yScale, width: bounds.width * xScale, height: bounds.height * yScale)
        guard frame.width >= 40, frame.height >= 40 else { return nil }
        return (cropped, frame)
    }
}
