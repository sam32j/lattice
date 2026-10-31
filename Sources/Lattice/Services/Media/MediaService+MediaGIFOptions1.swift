// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Darwin
import ImageIO
import UniformTypeIdentifiers
import Vision

struct MediaGIFOptions: Equatable {
    var start: Double
    var end: Double
    var quality: Double
    var width: Int
    var fps: Double
    var loops: Bool
    var sizing: MediaSizingMode = .resolution
    var targetBytes: Int64 = 0
}
