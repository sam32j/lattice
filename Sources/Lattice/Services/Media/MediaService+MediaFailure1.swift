// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Darwin
import ImageIO
import UniformTypeIdentifiers
import Vision

enum MediaFailure: Equatable {
    case noInput
    case noVideoTrack
    case sameOutput
    case unsupported
    case imageTooLarge
    case gifTooLong(maxSeconds: Int)
    case targetTooSmall
    case watermarkUnavailable
    case cancelled
    case failed(String)
}
