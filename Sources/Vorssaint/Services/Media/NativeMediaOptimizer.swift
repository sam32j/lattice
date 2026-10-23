import AppKit
import Darwin
import ImageIO
import UniformTypeIdentifiers

/// One encoder instance belongs to one batch. Cancel never affects another job.
final class NativeMediaOptimizer: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var process: Process?
    private let video = NativeVideoOptimizer()
    private let toolsDirectory: URL
    init(toolsDirectory: URL = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/MediaTools")) {
        self.toolsDirectory = toolsDirectory
    }
    func cancel() {
        lock.lock(); cancelled = true; let active = process; lock.unlock()
        if let active, active.isRunning { active.terminate() }
        video.cancel()
    }
    private func checkCancellation() throws {
        lock.lock(); let value = cancelled; lock.unlock()
        if value { throw CancellationError() }
    }
    func optimize(_ input: URL, aggressive: Bool, directory: URL, format: MediaOutputFormat = .original) throws -> URL {
        try checkCancellation()
        let type = (try input.resourceValues(forKeys: [.contentTypeKey])).contentType
        guard let type else { throw NativeMediaError.unsupported }
        let result: URL
        if type.conforms(to: .movie) || type.conforms(to: .video) {
            result = try video.optimize(input, aggressive: aggressive, directory: directory, format: format)
        } else { result = try image(input, aggressive: aggressive, directory: directory, format: format) }
        try checkCancellation()
        return result
    }
    private func image(_ input: URL, aggressive: Bool, directory: URL, format: MediaOutputFormat) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              let identifier = CGImageSourceGetType(source), let type = UTType(identifier as String),
              CGImageSourceGetCount(source) > 0 else { throw NativeMediaError.unsupported }
        let count = CGImageSourceGetCount(source)
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let size = ImageFileSupport.imageDisplaySize(properties: properties),
              ImageFileSupport.imageRenderSizeIsSafe(size),
              count <= 2000, Double(count) * size.width * size.height <= 128_000_000 else {
            throw NativeMediaError.imageTooLarge
        }
        guard format == .original || MediaOutputFormat.choices(for: [input]).contains(format) else { throw NativeMediaError.unsupported }
        let ext: String
        if format == .jpeg { ext = "jpg" }
        else if format == .png { ext = "png" }
        else if format == .heic { ext = "heic" }
        else if type == .gif { ext = "gif" }
        else if type == .png { ext = "png" }
        else if type == .jpeg { ext = "jpg" }
        else if type.conforms(to: .heic) || type.conforms(to: .heif) { ext = "heic" }
        else { throw NativeMediaError.unsupported }
        guard count == 1 || type == .gif else { throw NativeMediaError.unsupported }
        let output = directory.appendingPathComponent("encoded-\(UUID()).\(ext)")
        if type == .gif {
            try runTool("gifsicle", arguments: [aggressive ? "-O3" : "-O2",
                "--lossy=\(aggressive ? 80 : 30)", "--output", output.path, "--", input.path])
        } else if ext == "png" {
            // pngquant is built without a non-system color library. Normalize
            // wide-gamut pixels with ColorSync/ImageIO before palette reduction.
            let normalized = directory.appendingPathComponent("srgb-\(UUID()).png")
            guard let pixels = Self.orientedPixels(source, size: size),
                  let color = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: nil, width: pixels.width, height: pixels.height,
                    bitsPerComponent: 8, bytesPerRow: 0, space: color,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                  let destination = CGImageDestinationCreateWithURL(normalized as CFURL, UTType.png.identifier as CFString, 1, nil)
            else { throw NativeMediaError.invalidOutput }
            context.draw(pixels, in: CGRect(x: 0, y: 0, width: pixels.width, height: pixels.height))
            guard let converted = context.makeImage() else { throw NativeMediaError.invalidOutput }
            CGImageDestinationAddImage(destination, converted, nil)
            guard CGImageDestinationFinalize(destination) else { throw NativeMediaError.invalidOutput }
            defer { try? FileManager.default.removeItem(at: normalized) }
            try runTool("pngquant", arguments: ["--quality", aggressive ? "0-65" : "0-85",
                "--speed", "3", "--force", "--output", output.path, "--", normalized.path])
        } else {
            guard var pixels = Self.orientedPixels(source, size: size),
                  let destination = CGImageDestinationCreateWithURL(output as CFURL,
                    (ext == "jpg" ? UTType.jpeg : UTType.heic).identifier as CFString, 1, nil) else {
                throw NativeMediaError.unsupported
            }
            var properties = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
            properties[kCGImagePropertyOrientation] = 1
            if ext == "jpg" {
                // JPEG has no alpha; use a predictable white background.
                guard let context = CGContext(data: nil, width: pixels.width, height: pixels.height,
                    bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw NativeMediaError.invalidOutput }
                context.setFillColor(CGColor(gray: 1, alpha: 1))
                let rect = CGRect(x: 0, y: 0, width: pixels.width, height: pixels.height)
                context.fill(rect); context.draw(pixels, in: rect)
                guard let opaque = context.makeImage() else { throw NativeMediaError.invalidOutput }
                pixels = opaque
            }
            properties[kCGImageDestinationLossyCompressionQuality] = aggressive ? 0.6 : 0.82
            CGImageDestinationAddImage(destination, pixels, properties as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw NativeMediaError.invalidOutput }
        }
        guard let decoded = CGImageSourceCreateWithURL(output as CFURL, nil),
              let first = CGImageSourceCreateImageAtIndex(decoded, 0, nil),
              first.width == Int(size.width), first.height == Int(size.height) else { throw NativeMediaError.invalidOutput }
        if type == .gif {
            guard abs(Self.gifDuration(source) - Self.gifDuration(decoded)) < 0.02,
                  Self.gifLoop(source) == Self.gifLoop(decoded) else { throw NativeMediaError.invalidOutput }
        }
        return output
    }
    private static func orientedPixels(_ source: CGImageSource, size: CGSize) -> CGImage? {
        CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(max(size.width, size.height))
        ] as CFDictionary)
    }
    private static func gifDuration(_ source: CGImageSource) -> Double {
        (0..<CGImageSourceGetCount(source)).reduce(0) { total, index in
            let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            return total + ((gif?[kCGImagePropertyGIFUnclampedDelayTime] ?? gif?[kCGImagePropertyGIFDelayTime]) as? Double ?? 0)
        }
    }
    private static func gifLoop(_ source: CGImageSource) -> Int {
        let props = CGImageSourceCopyProperties(source, nil) as? [CFString: Any]
        return (props?[kCGImagePropertyGIFDictionary] as? [CFString: Any])?[kCGImagePropertyGIFLoopCount] as? Int ?? 1
    }
    private func runTool(_ name: String, arguments: [String]) throws {
        let executable = toolsDirectory.appendingPathComponent(name)
        guard FileManager.default.isExecutableFile(atPath: executable.path) else { throw NativeMediaError.missingTool(name) }
        let child = Process()
        child.executableURL = executable; child.arguments = arguments
        child.standardInput = FileHandle.nullDevice
        child.standardOutput = FileHandle.nullDevice; child.standardError = FileHandle.nullDevice
        let exited = DispatchSemaphore(value: 0)
        child.terminationHandler = { _ in exited.signal() }
        lock.lock()
        guard !cancelled else { lock.unlock(); throw CancellationError() }
        do { try child.run(); process = child; lock.unlock() }
        catch { lock.unlock(); throw error }
        let timeout = exited.wait(timeout: .now() + 300) == .timedOut
        if timeout, child.isRunning { kill(child.processIdentifier, SIGKILL); _ = exited.wait(timeout: .now() + 3) }
        lock.lock(); process = nil; lock.unlock()
        try checkCancellation()
        if timeout { throw NativeMediaError.timedOut }
        guard child.terminationStatus == 0 else { throw NativeMediaError.toolFailed(name) }
    }
}
