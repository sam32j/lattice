// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Observes system-wide Focus / Do Not Disturb (DND) state.
final class DoNotDisturbState: ObservableObject {
    static let shared = DoNotDisturbState()

    @Published private(set) var isActive: Bool = false

    private var dndEnabledObserver: NSObjectProtocol?
    private var dndDisabledObserver: NSObjectProtocol?

    private init() {
        refresh()
        let distributed = DistributedNotificationCenter.default()
        dndEnabledObserver = distributed.addObserver(
            forName: Notification.Name("_NSDoNotDisturbEnabledNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
        dndDisabledObserver = distributed.addObserver(
            forName: Notification.Name("_NSDoNotDisturbDisabledNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        if let dndEnabledObserver {
            DistributedNotificationCenter.default().removeObserver(dndEnabledObserver)
        }
        if let dndDisabledObserver {
            DistributedNotificationCenter.default().removeObserver(dndDisabledObserver)
        }
    }

    func refresh() {
        let active = checkDNDActive()
        if isActive != active {
            isActive = active
        }
    }

    private func checkDNDActive() -> Bool {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/DoNotDisturb/DB/Assertions.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArr = json["data"] as? [[String: Any]],
              let first = dataArr.first,
              let records = first["storeAssertionRecords"] as? [[String: Any]] else {
            return false
        }
        return !records.isEmpty
    }
}
