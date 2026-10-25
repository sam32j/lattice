// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics
import Vision

/// Watches a selected region while the person scrolls it, then joins overlaps
/// detected via Apple Vision translational image registration with sticky header
/// and footer protection. Pixel polling handles scrollbar drags and keyboard
/// scrolling without global event permissions.
enum ScreenshotScrollingCapture {
    final class FinishSignal: @unchecked Sendable {
        private let lock = NSLock()
        private var requested = false

        func request() {
            lock.lock()
            requested = true
            lock.unlock()
        }

        var isRequested: Bool {
            lock.lock()
            defer { lock.unlock() }
            return requested
        }
    }

    enum Result {
        case success(ScreenshotSelectionController.Capture)
        case partial(ScreenshotSelectionController.Capture)
        case limited(ScreenshotSelectionController.Capture)
        case cancelled
        case failed
    }

    private static let sampleInterval: TimeInterval = 0.08
    private static let settleInterval: TimeInterval = 0.22
    private static let finishGraceInterval: TimeInterval = 0.85

    // MARK: - Header & Footer Detection

    enum HeaderDetector {
        private static let maxScanPercent = 0.20
        private static let sampleColumns = 20
        private static let tolerance: Int = 2

        static func detectHeaderHeight(frame1: CGImage, frame2: CGImage) -> Int {
            unchangedRowCount(frame1: frame1, frame2: frame2, fromBottom: false)
        }

        static func detectFooterHeight(frame1: CGImage, frame2: CGImage) -> Int {
            unchangedRowCount(frame1: frame1, frame2: frame2, fromBottom: true)
        }

        private static func unchangedRowCount(frame1: CGImage, frame2: CGImage, fromBottom: Bool) -> Int {
            let width = min(frame1.width, frame2.width)
            let height = min(frame1.height, frame2.height)
            let maxScanRows = Int(Double(height) * maxScanPercent)
            guard width > 0, maxScanRows > 0 else { return 0 }

            guard let data1 = frame1.dataProvider?.data,
                  let data2 = frame2.dataProvider?.data else { return 0 }

            guard let ptr1 = CFDataGetBytePtr(data1),
                  let ptr2 = CFDataGetBytePtr(data2) else { return 0 }

            let bpr1 = frame1.bytesPerRow
            let bpr2 = frame2.bytesPerRow
            let bpp1 = max(1, frame1.bitsPerPixel / 8)
            let bpp2 = max(1, frame2.bitsPerPixel / 8)

            let colStep = max(1, width / min(sampleColumns, width))
            var unchangedRows = 0

            for scanned in 0..<maxScanRows {
                let row = fromBottom ? height - 1 - scanned : scanned
                var rowMatches = true
                var minVal = 255, maxVal = 0
                var col = 0
                while col < width {
                    let offset1 = row * bpr1 + col * bpp1
                    let offset2 = row * bpr2 + col * bpp2

                    if bpp1 == 1 && bpp2 == 1 {
                        let v = Int(ptr1[offset1])
                        minVal = min(minVal, v)
                        maxVal = max(maxVal, v)
                        let d = abs(v - Int(ptr2[offset2]))
                        if d > tolerance {
                            rowMatches = false
                            break
                        }
                    } else {
                        let r1 = Int(ptr1[offset1]), g1 = Int(ptr1[offset1 + 1]), b1 = Int(ptr1[offset1 + 2])
                        let lum = (r1 + g1 + b1) / 3
                        minVal = min(minVal, lum)
                        maxVal = max(maxVal, lum)
                        let dr = abs(r1 - Int(ptr2[offset2]))
                        let dg = abs(g1 - Int(ptr2[offset2 + 1]))
                        let db = abs(b1 - Int(ptr2[offset2 + 2]))
                        if dr > tolerance || dg > tolerance || db > tolerance {
                            rowMatches = false
                            break
                        }
                    }
                    col += colStep
                }

                // If row has no content variation across columns, it is a solid margin, not UI
                if maxVal - minVal <= tolerance {
                    break
                }

                if rowMatches {
                    unchangedRows = scanned + 1
                } else {
                    break
                }
            }
            return unchangedRows
        }
    }

    struct FixedRegions: Equatable {
        var header = 0
        var footer = 0

        static func detect(frame1: CGImage, frame2: CGImage) -> FixedRegions {
            FixedRegions(
                header: HeaderDetector.detectHeaderHeight(frame1: frame1, frame2: frame2),
                footer: HeaderDetector.detectFooterHeight(frame1: frame1, frame2: frame2)
            )
        }

        func scrollingArea(in frame: CGImage) -> CGRect? {
            let rect = CGRect(
                x: 0, y: header,
                width: frame.width, height: frame.height - header - footer
            )
            return rect.height > 0 ? rect : nil
        }
    }

    // MARK: - Incremental Stitcher

    final class ScrollStitcher: @unchecked Sendable {
        private(set) var body: CGImage?
        private var lastFrame: CGImage?
        private(set) var footerHeight = 0
        private(set) var totalHeight: Int = 0

        var mergedImage: CGImage? {
            guard let body else { return nil }
            guard footerHeight > 0, let lastFrame,
                  let footer = lastFrame.cropping(to: CGRect(
                      x: 0, y: lastFrame.height - footerHeight,
                      width: lastFrame.width, height: footerHeight
                  )) else { return body }
            return Self.stack(top: body, bottom: footer)
        }

        func setInitialFrame(_ frame: CGImage) {
            body = frame
            lastFrame = frame
            footerHeight = 0
            totalHeight = frame.height
        }

        func setFooterHeight(_ height: Int) {
            guard let body, height > 0, height < body.height else { return }
            footerHeight = height
            self.body = body.cropping(to: CGRect(x: 0, y: 0, width: body.width, height: body.height - height))
        }

        enum StitchResult {
            case stitched(yOffset: Int)
            case noChange
            case reversedScroll
            case alignmentFailed
        }

        func stitch(newFrame: CGImage, detectedOffset: Int) -> StitchResult {
            guard let body else {
                setInitialFrame(newFrame)
                return .stitched(yOffset: 0)
            }
            guard detectedOffset > 0 else {
                return detectedOffset < 0 ? .reversedScroll : .noChange
            }

            let contentBottom = newFrame.height - footerHeight
            guard detectedOffset < contentBottom,
                  let newRows = newFrame.cropping(to: CGRect(
                      x: 0, y: contentBottom - detectedOffset,
                      width: newFrame.width, height: detectedOffset
                  )),
                  let stacked = Self.stack(top: body, bottom: newRows) else {
                return .alignmentFailed
            }

            self.body = stacked
            lastFrame = newFrame
            totalHeight = stacked.height + footerHeight
            return .stitched(yOffset: detectedOffset)
        }

        static func stack(top: CGImage, bottom: CGImage) -> CGImage? {
            let width = min(top.width, bottom.width)
            let height = top.height + bottom.height
            let colorSpace = top.colorSpace ?? CGColorSpaceCreateDeviceRGB()
            let isGray = (colorSpace.model == .monochrome)
            let hasAlpha = !([.none, .noneSkipFirst, .noneSkipLast].contains(top.alphaInfo))
            let bitmapInfo: UInt32 = isGray
                ? CGImageAlphaInfo.none.rawValue
                : (hasAlpha
                    ? (CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
                    : (CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue))

            guard let ctx = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else { return nil }

            ctx.interpolationQuality = .none
            ctx.draw(top, in: CGRect(x: 0, y: bottom.height, width: width, height: top.height))
            ctx.draw(bottom, in: CGRect(x: 0, y: 0, width: width, height: bottom.height))
            return ctx.makeImage()
        }
    }

    // MARK: - Offset Detection & Matching

    static func verticalOffset(from earlier: CGImage, to later: CGImage, ignoring fixed: FixedRegions) -> Int? {
        guard let area = fixed.scrollingArea(in: earlier),
              let a = earlier.cropping(to: area),
              let b = later.cropping(to: area) else { return nil }

        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: a)
        do {
            try VNImageRequestHandler(cgImage: b, options: [:]).perform([request])
        } catch {
            return nil
        }
        guard let observation = request.results?.first as? VNImageTranslationAlignmentObservation else {
            return nil
        }
        return Int(observation.alignmentTransform.ty.rounded())
    }

    static func validateOffset(earlier: CGImage, later: CGImage, offset: Int, header: Int = 0) -> Bool {
        guard offset > 0, offset < earlier.height else { return false }
        let startRow = header
        let overlap = earlier.height - offset
        let width = min(earlier.width, later.width)
        guard overlap > startRow, width > 0 else { return true }

        guard let d1 = earlier.dataProvider?.data,
              let d2 = later.dataProvider?.data else { return false }
        guard let p1 = CFDataGetBytePtr(d1),
              let p2 = CFDataGetBytePtr(d2) else { return false }
        let bpr1 = earlier.bytesPerRow
        let bpr2 = later.bytesPerRow
        let bpp1 = max(1, earlier.bitsPerPixel / 8)
        let bpp2 = max(1, later.bitsPerPixel / 8)

        let sampleRows = min(20, overlap - startRow)
        let sampleCols = min(20, width)
        let rowStep = max(1, (overlap - startRow) / sampleRows)
        let colStep = max(1, width / sampleCols)

        var diffTotal: Double = 0
        var count = 0

        for r in stride(from: startRow, to: overlap, by: rowStep) {
            let r1 = r + offset
            let r2 = r
            for c in stride(from: 0, to: width, by: colStep) {
                let o1 = r1 * bpr1 + c * bpp1
                let o2 = r2 * bpr2 + c * bpp2
                if bpp1 == 1 && bpp2 == 1 {
                    diffTotal += Double(abs(Int(p1[o1]) - Int(p2[o2])))
                } else {
                    let dr = abs(Int(p1[o1]) - Int(p2[o2]))
                    let dg = abs(Int(p1[o1 + 1]) - Int(p2[o2 + 1]))
                    let db = abs(Int(p1[o1 + 2]) - Int(p2[o2 + 2]))
                    diffTotal += Double(dr + dg + db) / 3.0
                }
                count += 1
            }
        }
        let avg = count > 0 ? (diffTotal / Double(count)) : 999.0
        return avg <= 50.0
    }

    static func areFramesIdentical(_ a: CGImage, _ b: CGImage) -> Bool {
        guard a.width == b.width, a.height == b.height,
              let dataA = a.dataProvider?.data,
              let dataB = b.dataProvider?.data else { return false }
        let lenA = CFDataGetLength(dataA)
        let lenB = CFDataGetLength(dataB)
        guard lenA == lenB,
              let ptrA = CFDataGetBytePtr(dataA),
              let ptrB = CFDataGetBytePtr(dataB) else { return false }
        return memcmp(ptrA, ptrB, lenA) == 0
    }

    // MARK: - Capture Loop

    static func capture(region: RecorderSupport.Region,
                        includePointer: Bool,
                        excludingAppWindows: Bool = false,
                        protectedWindowIDs: Set<CGWindowID>,
                        finishSignal: FinishSignal,
                        onProgress: @escaping @MainActor (Int) -> Void = { _ in },
                        onFrame: (@MainActor (CGImage, Int) -> Void)? = nil) async -> Result {
        do {
            guard let source = await ScreenshotCaptureEngine.prepareDisplayRegion(
                displayID: region.displayID, pixelRect: region.pixelRect,
                includePointer: includePointer, excludingAppWindows: excludingAppWindows,
                protectedWindowIDs: protectedWindowIDs),
                  let firstFrame = await source.image(),
                  let first = contentFrame(firstFrame)
            else { return Task.isCancelled ? .cancelled : .failed }
            try Task.checkCancellation()

            let startedAt = ProcessInfo.processInfo.systemUptime
            let stitcher = ScrollStitcher()
            stitcher.setInitialFrame(first)
            var shotA = first
            var lastObservedFrame = first
            var fixedRegions: FixedRegions?
            var hasUnmatchedContent = false
            var finishRequestedAt: TimeInterval?
            var lastCaptureAt = ProcessInfo.processInfo.systemUptime
            var scrollPending = false
            var frameCount = 1

            await onProgress(stitcher.totalHeight)
            await onFrame?(stitcher.mergedImage ?? first, stitcher.totalHeight)

            while true {
                try Task.checkCancellation()

                let now = ProcessInfo.processInfo.systemUptime
                if finishSignal.isRequested, finishRequestedAt == nil {
                    finishRequestedAt = now
                    scrollPending = true
                }
                if let finishRequestedAt,
                   !scrollPending || now - finishRequestedAt >= finishGraceInterval {
                    return completedByUser(
                        stitcher: stitcher,
                        region: region,
                        hasUnmatchedContent: hasUnmatchedContent)
                }
                if now - startedAt >= ScreenshotSupport.scrollingCaptureMaximumDuration
                    || frameCount >= ScreenshotSupport.scrollingCaptureMaximumFrames
                    || stitcher.totalHeight * first.width >= ScreenshotSupport.scrollingCaptureMaximumPixels {
                    return completed(
                        image: stitcher.mergedImage,
                        region: region,
                        result: .limited)
                }

                let sinceLastCapture = now - lastCaptureAt
                if sinceLastCapture < sampleInterval {
                    try await Task.sleep(nanoseconds: UInt64((sampleInterval - sinceLastCapture) * 1_000_000_000))
                    continue
                }

                guard let rawFrame = await source.image(),
                      let current = contentFrame(rawFrame)
                else {
                    return completed(
                        image: stitcher.mergedImage,
                        region: region,
                        result: .partial)
                }
                try Task.checkCancellation()
                lastCaptureAt = ProcessInfo.processInfo.systemUptime

                if areFramesIdentical(lastObservedFrame, current) {
                    scrollPending = false
                    continue
                }
                lastObservedFrame = current
                scrollPending = true

                if fixedRegions == nil {
                    let detected = FixedRegions.detect(frame1: shotA, frame2: current)
                    fixedRegions = detected
                    stitcher.setFooterHeight(detected.footer)
                }

                let regions = fixedRegions ?? FixedRegions()
                if let offset = verticalOffset(from: shotA, to: current, ignoring: regions) {
                    if offset >= 3 {
                        if validateOffset(earlier: shotA, later: current, offset: offset, header: regions.header) {
                            if case .stitched = stitcher.stitch(newFrame: current, detectedOffset: offset) {
                                shotA = current
                                frameCount += 1
                                hasUnmatchedContent = false
                                await onProgress(stitcher.totalHeight)
                                await onFrame?(stitcher.mergedImage ?? current, stitcher.totalHeight)
                            }
                        } else {
                            hasUnmatchedContent = true
                        }
                    } else if offset < 0 {
                        // Backwards scroll: preserve furthest forward frame without duplicating pixels
                        hasUnmatchedContent = false
                    }
                } else {
                    hasUnmatchedContent = true
                }
            }
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed
        }
    }

    private static func completedByUser(stitcher: ScrollStitcher,
                                        region: RecorderSupport.Region,
                                        hasUnmatchedContent: Bool) -> Result {
        completed(image: stitcher.mergedImage,
                  region: region,
                  result: hasUnmatchedContent ? .partial : .success)
    }

    private enum CompletedResult {
        case success
        case partial
        case limited
    }

    private static func completed(image: CGImage?,
                                  region: RecorderSupport.Region,
                                  result: CompletedResult) -> Result {
        guard !Task.isCancelled else { return .cancelled }
        guard let image else { return Task.isCancelled ? .cancelled : .failed }
        let capture = ScreenshotSelectionController.Capture(
            image: image,
            scale: region.scale,
            anchorRect: region.anchorRect)
        switch result {
        case .success: return .success(capture)
        case .partial: return .partial(capture)
        case .limited: return .limited(capture)
        }
    }

    // MARK: - Frame Helpers

    private static func contentFrame(_ image: CGImage) -> CGImage? {
        if [.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo) { return image }
        let width = image.width, height = image.height
        guard width > 0, height > 0 else { return nil }
        var alpha = [UInt8](repeating: 0, count: width * height)
        let drawn = alpha.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width,
                                          space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue)
            else { return false }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        var top = 0, bottom = height, left = 0, right = width
        while top < bottom && alpha[(top * width)..<((top + 1) * width)].allSatisfy({ $0 == 0 }) {
            top += 1
        }
        while bottom > top && alpha[((bottom - 1) * width)..<(bottom * width)].allSatisfy({ $0 == 0 }) {
            bottom -= 1
        }
        guard top < bottom else { return nil }
        while left < right && (top..<bottom).allSatisfy({ alpha[$0 * width + left] == 0 }) {
            left += 1
        }
        while right > left && (top..<bottom).allSatisfy({ alpha[$0 * width + right - 1] == 0 }) {
            right -= 1
        }
        guard left < right else { return nil }
        if top == 0 && bottom == height && left == 0 && right == width { return image }
        return image.cropping(to: CGRect(x: left, y: top, width: right - left, height: bottom - top))
    }

    static func stitch(_ slices: [CGImage]) -> CGImage? {
        guard !Task.isCancelled else { return nil }
        guard let first = slices.first else { return nil }
        guard slices.count > 1 else { return first }
        let width = slices.map(\.width).min() ?? first.width
        let height = slices.reduce(0) { $0 + $1.height }
        guard let context = CGContext(data: nil,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: first.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.interpolationQuality = .none

        var destinationY = height
        for slice in slices {
            guard !Task.isCancelled else { return nil }
            destinationY -= slice.height
            guard let piece = slice.cropping(to: CGRect(x: 0,
                                                        y: 0,
                                                        width: width,
                                                        height: slice.height))
            else { return nil }
            context.draw(piece, in: CGRect(x: 0, y: destinationY,
                                           width: piece.width, height: piece.height))
        }
        guard !Task.isCancelled, destinationY == 0 else { return nil }
        return context.makeImage()
    }
}
