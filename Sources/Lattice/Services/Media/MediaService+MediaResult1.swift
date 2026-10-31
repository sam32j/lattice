// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Darwin
import ImageIO
import UniformTypeIdentifiers
import Vision

struct MediaResult: Identifiable, Equatable {
    let id = UUID()
    let tool: MediaTool
    let inputURL: URL
    let outputURL: URL?
    let outputURLs: [URL]
    let originalBytes: Int64
    let outputBytes: Int64
    let elapsed: TimeInterval
    let text: String?
    let imageBatchItems: [MediaImageBatchItemResult]

    init(tool: MediaTool,
         inputURL: URL,
         outputURL: URL?,
         outputURLs: [URL]? = nil,
         originalBytes: Int64,
         outputBytes: Int64,
         elapsed: TimeInterval,
         text: String?,
         imageBatchItems: [MediaImageBatchItemResult] = []) {
        self.tool = tool
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.outputURLs = outputURLs ?? outputURL.map { [$0] } ?? []
        self.originalBytes = originalBytes
        self.outputBytes = outputBytes
        self.elapsed = elapsed
        self.text = text
        self.imageBatchItems = imageBatchItems
    }

    var processedCount: Int {
        imageBatchItems.isEmpty ? (outputURL == nil && text == nil ? 0 : 1) : imageBatchItems.filter { $0.outputURL != nil }.count
    }

    var failedCount: Int {
        imageBatchItems.filter { $0.failure != nil }.count
    }
}
