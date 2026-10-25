// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import CoreGraphics
import Foundation

/// Thumbnail work belongs to one presentation, even when a loader ignores cancellation.
final class RecorderQuickPreviewModel: ObservableObject {
    @Published private(set) var thumbnail: CGImage?
    private let loadThumbnail: (URL) async -> CGImage?
    private var task: Task<Void, Never>?
    private var generation = UUID()

    init(loadThumbnail: @escaping (URL) async -> CGImage?) { self.loadThumbnail = loadThumbnail }

    func show(url: URL, initialThumbnail: CGImage? = nil) {
        close()
        thumbnail = initialThumbnail
        guard initialThumbnail == nil else { return }
        let expected = generation
        let load = loadThumbnail
        task = Task { @MainActor [weak self] in
            guard !Task.isCancelled else { return }
            let image = await load(url)
            guard !Task.isCancelled, let self, self.generation == expected else { return }
            self.thumbnail = image
            self.task = nil
        }
    }

    func close() {
        generation = UUID()
        task?.cancel()
        task = nil
        thumbnail = nil
    }

    deinit { task?.cancel() }
}
