// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum RecentCaptureRetention {
    static func entries(_ entries: [RecentCaptureEntry], screenshotCutoff: Date?,
                        recordingLimit: Int) -> [RecentCaptureEntry] {
        let limit = [5, 10].contains(recordingLimit) ? recordingLimit : 0
        var recordings = 0
        return entries.sorted { $0.createdAt > $1.createdAt }.filter { entry in
            switch entry.kind {
            case .screenshot:
                return screenshotCutoff.map { entry.createdAt >= $0 } ?? true
            case .recording:
                recordings += 1
                return limit == 0 || recordings <= limit
            }
        }
    }
}
