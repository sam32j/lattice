// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import Darwin
import ImageIO
import UniformTypeIdentifiers
import Vision

final class MediaWorkspaceSelection: ObservableObject {
    @Published var inputURLs: [URL] = []
    @Published var inputImageSize: CGSize?
    @Published var outputURL: URL?
    @Published var outputWasChosenManually = false
    @Published var tool: MediaTool?
    var loadedInitialInputs = false
    var durationLoading = MediaDurationLoading()
}
