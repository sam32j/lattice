// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Darwin
import ImageIO
import UniformTypeIdentifiers
import Vision

enum MediaServiceState: Equatable {
    case idle
    case ready
    case running(progress: Double, message: String)
    case completed(MediaResult)
    case failed(MediaFailure)
    case cancelled
}
