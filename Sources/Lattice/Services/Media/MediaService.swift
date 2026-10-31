// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Darwin
import ImageIO
import UniformTypeIdentifiers
import Vision

final class MediaService: ObservableObject {
    static let shared = MediaService()

    @Published var state: MediaServiceState = .idle

    let queue = DispatchQueue(label: "io.github.sam32j.lattice.media", qos: .userInitiated)
    let lock = NSLock()
    var operationID: UUID?
    var token: MediaCancellationToken?
    var activeProcess: Process?
    var activeVisionRequest: VNRequest?

    let replacesExistingOutputs: Bool

    init(replacesExistingOutputs: Bool = true) {
        self.replacesExistingOutputs = replacesExistingOutputs
    }

    struct PreparedImage {
        let image: CGImage
        let properties: [CFString: Any]
        let size: CGSize
    }

    struct VideoGeometry {
        let videoTrack: AVAssetTrack
        let audioTracks: [AVAssetTrack]
        let naturalSize: CGSize
        let preferredTransform: CGAffineTransform
        let frameRate: Double
    }

    struct VideoMetadata {
        let duration: Double
        let displaySize: CGSize
        let geometry: VideoGeometry?
    }
}
