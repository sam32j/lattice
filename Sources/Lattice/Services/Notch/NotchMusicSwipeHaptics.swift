// SPDX-License-Identifier: GPL-3.0-or-later
import AppKit

/// Hardware is selected by AppKit; unsupported input devices simply do not tap.
/// Gesture stages decide when to tap. There is no delayed pulse to outlive them.
final class NotchMusicSwipeHaptics {
    static let shared = NotchMusicSwipeHaptics {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
    private let perform: () -> Void
    init(perform: @escaping () -> Void) { self.perform = perform }
    func tap() { perform() }
}
