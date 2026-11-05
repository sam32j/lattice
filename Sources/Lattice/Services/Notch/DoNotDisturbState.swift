// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Observes system-wide Focus / Do Not Disturb (DND) state.
final class DoNotDisturbState: ObservableObject {
    static let shared = DoNotDisturbState()

    @Published private(set) var isActive: Bool = false

    private var dndEnabledObserver: NSObjectProtocol?
    private var dndDisabledObserver: NSObjectProtocol?
    private var dirSource: DispatchSourceFileSystemObject?
    private var dirFD: Int32 = -1
    private var pollTimer: Timer?

    private init() {
        refresh()
        setupNotificationObservers()
        setupFileSystemWatcher()
        setupPollTimer()
    }

    deinit {
        cleanup()
    }

    private func setupNotificationObservers() {
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

    private func setupFileSystemWatcher() {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/DoNotDisturb/DB")
        let fd = open((url as NSURL).fileSystemRepresentation, O_EVTONLY)
        guard fd >= 0 else { return }
        dirFD = fd
        let queue = DispatchQueue(label: "com.lattice.dnd-monitor", qos: .utility)
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .rename, .link],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.refresh()
        }
        source.setCancelHandler {
            close(fd)
        }
        dirSource = source
        source.resume()
    }

    private func setupPollTimer() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func cleanup() {
        if let dndEnabledObserver {
            DistributedNotificationCenter.default().removeObserver(dndEnabledObserver)
        }
        if let dndDisabledObserver {
            DistributedNotificationCenter.default().removeObserver(dndDisabledObserver)
        }
        pollTimer?.invalidate()
        pollTimer = nil
        dirSource?.cancel()
        dirSource = nil
        dirFD = -1
    }

    func refresh() {
        let active = checkDNDActive()
        if Thread.isMainThread {
            if isActive != active {
                isActive = active
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.isActive != active {
                    self.isActive = active
                }
            }
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
