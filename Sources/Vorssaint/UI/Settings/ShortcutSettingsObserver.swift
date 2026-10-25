// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Combine
import Foundation

/// Shortcut badges read several preference keys, not just the currently edited row.
final class ShortcutSettingsObserver: ObservableObject {
    static let shared = ShortcutSettingsObserver()
    private var observer: NSObjectProtocol?
    private var refreshPending = false
    private let center: NotificationCenter

    init(center: NotificationCenter = .default) {
        self.center = center
        observer = center.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, !self.refreshPending else { return }
            self.refreshPending = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.refreshPending = false
                self.objectWillChange.send()
            }
        }
    }

    deinit { if let observer { center.removeObserver(observer) } }
}
