import AVFoundation
import Foundation

enum NativeMediaError: LocalizedError {
    case unsupported, imageTooLarge, invalidOutput, missingTool(String), toolFailed(String), timedOut
    var errorDescription: String? {
        switch self {
        case .unsupported: return "macOS cannot optimize this format. Try a JPEG, PNG, GIF, HEIC, or a video playable by macOS. MKV and WebM may need another converter."
        case .imageTooLarge: return "This image is too large to optimize safely. Resize it or shorten the animation, then try again."
        case .invalidOutput: return "The encoder did not produce a complete, readable file. Your original is unchanged."
        case .missingTool(let name): return "The bundled \(name) encoder is missing. Reinstall Lattice and try again."
        case .toolFailed(let name): return "\(name) could not optimize this file. Your original is unchanged."
        case .timedOut: return "Optimization took too long and was stopped. Try a shorter or smaller file."
        }
    }
}

final class NativeVideoOptimizer: @unchecked Sendable {
    private let lock = NSLock()
    private var session: AVAssetExportSession?
    private var cancelled = false
    func cancel() {
        lock.lock(); cancelled = true; let active = session; lock.unlock()
        active?.cancelExport()
    }
    func optimize(_ input: URL, aggressive: Bool, directory: URL) throws -> URL {
        let asset = AVURLAsset(url: input)
        guard asset.isReadable, asset.isPlayable, !asset.tracks(withMediaType: .video).isEmpty,
              asset.duration.seconds.isFinite, asset.duration.seconds > 0 else { throw NativeMediaError.unsupported }
        let preset = AVAssetExportPresetHEVC1920x1080
        guard AVAssetExportSession.exportPresets(compatibleWith: asset).contains(preset),
              let export = AVAssetExportSession(asset: asset, presetName: preset),
              export.supportedFileTypes.contains(.mp4) else { throw NativeMediaError.unsupported }
        let output = directory.appendingPathComponent("encoded-\(UUID()).mp4")
        export.outputURL = output; export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true
        export.metadata = asset.metadata
        if aggressive { export.videoComposition = try Self.smallerComposition(asset) }
        let done = DispatchSemaphore(value: 0)
        lock.lock()
        guard !cancelled else { lock.unlock(); throw CancellationError() }
        session = export
        export.exportAsynchronously { done.signal() }
        lock.unlock()
        let timedOut = done.wait(timeout: .now() + 1800) == .timedOut
        if timedOut { export.cancelExport(); _ = done.wait(timeout: .now() + 5) }
        lock.lock(); session = nil; let wasCancelled = cancelled; lock.unlock()
        if wasCancelled || export.status == .cancelled { throw CancellationError() }
        if timedOut { throw NativeMediaError.timedOut }
        guard export.status == .completed else { throw export.error ?? NativeMediaError.invalidOutput }
        let result = AVURLAsset(url: output)
        guard result.isPlayable, !result.tracks(withMediaType: .video).isEmpty,
              result.duration.seconds.isFinite,
              abs(result.duration.seconds - asset.duration.seconds) < 0.25,
              asset.tracks(withMediaType: .audio).isEmpty || !result.tracks(withMediaType: .audio).isEmpty else {
            throw NativeMediaError.invalidOutput
        }
        return output
    }
    private static func smallerComposition(_ asset: AVAsset) throws -> AVVideoComposition {
        guard let track = asset.tracks(withMediaType: .video).first else { throw NativeMediaError.unsupported }
        let bounds = CGRect(origin: .zero, size: track.naturalSize).applying(track.preferredTransform).standardized
        guard bounds.width > 0, bounds.height > 0 else { throw NativeMediaError.unsupported }
        let portrait = bounds.height > bounds.width
        let scale = min(1, (portrait ? 720 : 1280) / bounds.width, (portrait ? 1280 : 720) / bounds.height)
        let size = CGSize(width: max(2, floor(bounds.width * scale / 2) * 2),
                          height: max(2, floor(bounds.height * scale / 2) * 2))
        let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        let transform = track.preferredTransform.concatenating(CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
            .concatenating(CGAffineTransform(scaleX: size.width / bounds.width, y: size.height / bounds.height))
        layer.setTransform(transform, at: .zero)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
        instruction.layerInstructions = [layer]
        let composition = AVMutableVideoComposition()
        composition.renderSize = size
        composition.frameDuration = track.minFrameDuration.isValid && track.minFrameDuration.seconds > 0
            ? track.minFrameDuration : CMTime(value: 1, timescale: 30)
        composition.instructions = [instruction]
        return composition
    }
}
