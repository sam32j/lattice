// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Darwin
import ImageIO
import UniformTypeIdentifiers
import Vision

struct MediaFailureBox: Error {
    let failure: MediaFailure

    init(_ failure: MediaFailure) {
        self.failure = failure
    }
}
