// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Darwin
import ImageIO
import UniformTypeIdentifiers
import Vision

struct MediaTextOptions: Equatable {
    var accurate: Bool
    var languageCorrection: Bool
    var recognitionLanguages: [String]
}
