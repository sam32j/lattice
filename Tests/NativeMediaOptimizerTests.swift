import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

enum NativeMediaOptimizerTests {
    static func run(_ suite: TestSuite) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("com.vorssaint.tests.native-media-\(UUID())")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            defer { try? FileManager.default.removeItem(at: folder) }
            let input = folder.appendingPathComponent("photo.jpg")
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256,
                bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            memset(bitmap.bitmapData!, 160, bitmap.bytesPerRow * bitmap.pixelsHigh)
            try bitmap.representation(using: .jpeg, properties: [.compressionFactor: 1])!.write(to: input)
            let original = try Data(contentsOf: input)
            let encoder = NativeMediaOptimizer(toolsDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("build/media-tools"))
            let output = try encoder.optimize(input, aggressive: false, directory: folder)
            let decoded = CGImageSourceCreateWithURL(output as CFURL, nil)
            suite.expect(decoded != nil && CGImageSourceGetCount(decoded!) == 1,
                         "native JPEG compression produces a decodable single-frame image without Clop")
            suite.expect(try Data(contentsOf: output).count < original.count,
                         "native JPEG compression reduces the size of the high-quality fixture")
            suite.expect(try Data(contentsOf: input) == original, "native encoder never modifies its input")
            let png = try encoder.optimize(input, aggressive: false, directory: folder, format: .png)
            let pngSource = CGImageSourceCreateWithURL(png as CFURL, nil)!
            suite.expect(CGImageSourceGetType(pngSource) as String? == UTType.png.identifier,
                         "requesting PNG produces actual PNG bytes, not a renamed JPEG")
            try verifyConversionGeometry(suite, encoder: encoder, folder: folder)
            for type in [UTType.png, .gif, .heic] {
                let file = folder.appendingPathComponent("fixture.\(type.preferredFilenameExtension!)")
                let frames = type == .gif ? 2 : 1
                guard let target = CGImageDestinationCreateWithURL(file as CFURL, type.identifier as CFString, frames, nil) else {
                    suite.expect(false, "fixture encoder available for \(type)"); continue
                }
                if type == .gif { CGImageDestinationSetProperties(target, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary) }
                for frame in 0..<frames {
                    memset(bitmap.bitmapData!, frame == 0 ? 160 : 40, bitmap.bytesPerRow * bitmap.pixelsHigh)
                    let props: [CFString: Any] = type == .gif
                        ? [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.2]] : [:]
                    CGImageDestinationAddImage(target, bitmap.cgImage!, props as CFDictionary)
                }
                guard CGImageDestinationFinalize(target) else { suite.expect(false, "image fixture writes"); continue }
                let bytes = try Data(contentsOf: file)
                let encoded = try encoder.optimize(file, aggressive: true, directory: folder)
                let image = CGImageSourceCreateWithURL(encoded as CFURL, nil)
                suite.expect(image != nil && CGImageSourceGetCount(image!) == frames,
                             "\(type.preferredFilenameExtension!) optimization preserves readable frames, including animation")
                suite.expect(try Data(contentsOf: file) == bytes, "\(type) optimization preserves its source")
            }
            let corrupt = folder.appendingPathComponent("corrupt.mp4")
            try Data("not a video".utf8).write(to: corrupt)
            suite.expect((try? encoder.optimize(corrupt, aggressive: false, directory: folder)) == nil,
                         "an unreadable native video is an observable failure, never a successful output")
            let stopped = NativeMediaOptimizer()
            stopped.cancel()
            suite.expect((try? stopped.optimize(input, aggressive: false, directory: folder)) == nil,
                         "pre-cancelled jobs cannot start encoding")
            do {
                _ = try NativeMediaOptimizer(toolsDirectory: folder.appendingPathComponent("absent"))
                    .optimize(folder.appendingPathComponent("fixture.gif"), aggressive: false, directory: folder)
                suite.expect(false, "missing bundled GIF tool must fail")
            } catch {
                suite.expect(error.localizedDescription.contains("Reinstall Lattice"),
                             "real missing-helper failure gives an actionable repair without an app dependency")
            }
            try NativeVideoOptimizerTests.run(suite, folder: folder)
        } catch { suite.expect(false, "native image optimization: \(error)") }
    }
    private static func verifyConversionGeometry(_ suite: TestSuite, encoder: NativeMediaOptimizer, folder: URL) throws {
        let pixels = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 32,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        memset(pixels.bitmapData!, 0, pixels.bytesPerRow * pixels.pixelsHigh)
        let transparent = folder.appendingPathComponent("transparent.png")
        try pixels.representation(using: .png, properties: [:])!.write(to: transparent)
        let jpeg = try encoder.optimize(transparent, aggressive: false, directory: folder, format: .jpeg)
        let opaque = NSBitmapImageRep(data: try Data(contentsOf: jpeg))!
        let color = opaque.colorAt(x: 16, y: 16)!.usingColorSpace(.deviceRGB)!
        suite.expect(color.redComponent > 0.95 && color.greenComponent > 0.95 && color.blueComponent > 0.95,
                     "transparent image conversion uses a white JPEG background rather than black")
        memset(pixels.bitmapData!, 160, pixels.bytesPerRow * pixels.pixelsHigh)
        let oriented = folder.appendingPathComponent("rotated.jpg")
        let target = CGImageDestinationCreateWithURL(oriented as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(target, pixels.cgImage!, [kCGImagePropertyOrientation: 6] as CFDictionary)
        guard CGImageDestinationFinalize(target) else { throw NativeMediaError.invalidOutput }
        let converted = try encoder.optimize(oriented, aggressive: false, directory: folder, format: .png)
        let source = CGImageSourceCreateWithURL(converted as CFURL, nil)!
        let result = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        suite.expect(result.width == 32 && result.height == 64,
                     "format conversion bakes EXIF orientation into upright pixels without changing display size")
    }
}
