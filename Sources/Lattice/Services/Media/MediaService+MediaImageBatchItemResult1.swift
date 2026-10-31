// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Darwin
import ImageIO
import UniformTypeIdentifiers
import Vision

struct MediaImageBatchItemResult: Identifiable, Equatable {
    let id = UUID()
    let inputURL: URL
    let outputURL: URL?
    let originalBytes: Int64
    let outputBytes: Int64
    let failure: MediaFailure?
}
