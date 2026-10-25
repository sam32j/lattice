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
    private(set) var completionPending = false
    private var expiry: DispatchWorkItem?
    private let scheduleExpiry: (TimeInterval, DispatchWorkItem) -> Void

    init(scheduleExpiry: @escaping (TimeInterval, DispatchWorkItem) -> Void = {
        DispatchQueue.main.asyncAfter(deadline: .now() + $0, execute: $1)
    }) {
        self.scheduleExpiry = scheduleExpiry
    }

    func show(_ frame: Frame, completed: Bool = false, held: Bool = false) {
        expiry?.cancel()
        expiry = nil
        completionPending = completed && frame.progress > 0
        if self.frame != frame { self.frame = frame }
        guard frame.progress > 0, !held else { return }
        let work = DispatchWorkItem { [weak self] in self?.clear() }
        expiry = work
        scheduleExpiry(completed ? 0.22 : 0.5, work)
    }

    func clear() {
        expiry?.cancel()
        expiry = nil
        completionPending = false
        if frame != Frame() { frame = Frame() }
    }
    deinit { expiry?.cancel() }
}

