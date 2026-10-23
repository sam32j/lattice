import CoreGraphics
import ImageIO
import Foundation

enum ImageFileSupport {
    static let maxImageRenderDimension = 20_000
    static let maxImageRenderPixels = 8_192 * 8_192
    static func imageDisplaySize(at url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any] else { return nil }
        return imageDisplaySize(properties: properties)
    }


    static func imageThumbnail(at url: URL, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixel),
        ] as CFDictionary)
    }


    static func imageDisplaySize(properties: [CFString: Any]) -> CGSize? {
        guard let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
              width.isFinite, height.isFinite, width > 0, height > 0,
              width < Double(Int.max), height < Double(Int.max) else { return nil }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        if 5...8 ~= orientation {
            return integralImageSize(width: CGFloat(height), height: CGFloat(width))
        }
        return integralImageSize(width: CGFloat(width), height: CGFloat(height))
    }


    static func imageRenderSizeIsSafe(_ size: CGSize,
                                      maxDimension: Int = maxImageRenderDimension,
                                      maxPixels: Int = maxImageRenderPixels) -> Bool {
        let width = abs(size.width)
        let height = abs(size.height)
        guard width.isFinite, height.isFinite, width >= 1, height >= 1,
              width <= CGFloat(maxDimension), height <= CGFloat(maxDimension) else { return false }
        return width * height <= CGFloat(maxPixels)
    }


    static func integralImageSize(width: CGFloat, height: CGFloat) -> CGSize {
        CGSize(width: max(1, width.rounded()),
               height: max(1, height.rounded()))
    }


}
