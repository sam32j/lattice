// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import Combine

final class NotchMusicSwipeState: ObservableObject {
    static let shared = NotchMusicSwipeState()
    struct Frame: Equatable {
        var direction: NotchMusicTrackSwipe.Direction?
        var progress = 0.0
        var expanded = false
    }
    @Published private(set) var frame = Frame()
    private var expiry: DispatchWorkItem?

    func show(_ frame: Frame, completed: Bool = false, held: Bool = false) {
        expiry?.cancel()
        expiry = nil
        self.frame = frame
        guard frame.progress > 0, !held else { return }
        let work = DispatchWorkItem { [weak self] in self?.clear() }
        expiry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (completed ? 0.22 : 0.5), execute: work)
    }

    func clear() {
        expiry?.cancel()
        expiry = nil
        frame = Frame()
    }
    deinit { expiry?.cancel() }
}

