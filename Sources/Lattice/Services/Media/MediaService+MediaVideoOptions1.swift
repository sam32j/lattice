// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Darwin
import ImageIO
import UniformTypeIdentifiers
import Vision

struct MediaVideoOptions: Equatable {
    var start: Double
    var end: Double
    var quality: Double
    var maxDimension: Int
    var fps: Double
    var keepAudio: Bool
    var codec: MediaVideoCodec
    var sizing: MediaSizingMode = .resolution
    var targetBytes: Int64 = 0
}
