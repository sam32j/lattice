// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Mirrors the player's real repeat switch. Apple Music offers off/all/one;
/// Spotify currently publishes only off/all through its scripting dictionary.
/// Like Shuffle, reads/writes happen away from the main thread.
final class NotchRepeatService: ObservableObject {
    static let shared = NotchRepeatService()

    @Published private(set) var availability: NotchMusicAutomation.Availability?
    @Published private(set) var mode: NotchMusicRepeatMode?
    @Published private(set) var pending = false
    @Published private(set) var requestingAccess = false

    private let queue = DispatchQueue(label: "io.github.sam32j.lattice.notch-repeat", qos: .utility)
    private var generation = UUID()
    private var switchID = UUID()
    private var open = false

    private init() {}

    var isOffered: Bool {
        guard let availability else { return false }
        return availability.access == .consent || (availability.access == .granted && mode != nil)
    }

    func refresh(for playback: NotchPlayback?) {
        let target = playback.flatMap(NotchMusicAutomation.Target.init)
        let request = UUID()
        generation = request
        open = true
        if availability?.target != target {
            availability = nil
            mode = nil
            pending = false
            switchID = UUID()
        }
        guard let target else { return }
        queue.async { [weak self] in
            let availability = NotchMusicAutomation.inspect(target)
                .flatMap { $0.capabilities.repeating == nil ? nil : $0 }
            let state = availability.flatMap(NotchMusicAutomation.repeatMode(of:))
            DispatchQueue.main.async {
                guard let self, self.generation == request else { return }
                self.availability = availability
                self.mode = state
            }
        }
    }

    func cycle() {
        guard !pending, !requestingAccess,
              let availability, availability.target.isCurrent else { return }
        if availability.access == .consent {
            requestAccess(availability)
            return
        }
        guard availability.access == .granted, let current = mode,
              let repeating = availability.capabilities.repeating else { return }
        pending = true
        let request = UUID()
        switchID = request
        // Snapshot the source and request before entering the serial automation
        // queue. A delayed inspection must not overwrite a different player.
        let source = availability.target
        queue.async { [weak self] in
            // The player's repeat state may have changed outside Lattice since
            // the last refresh. Read immediately before deciding the next mode.
            let observed = NotchMusicAutomation.repeatMode(of: availability) ?? current
            let target = observed.next(supportsOne: repeating.supportsRepeatOne)
            var sent = false
            // UI state is main-thread owned. Check the live request/source there
            // before writing to the selected app, not just on completion.
            DispatchQueue.main.sync {
                guard let self, self.open, self.switchID == request,
                      self.availability?.target == source,
                      NotchMusicService.shared.playback.flatMap(NotchMusicAutomation.Target.init) == source,
                      source.isCurrent else { return }
                sent = true
            }
            guard sent else { return }
            // Source changes after this check cannot be made atomic with the
            // external Apple Event, but the operation is still targeted to the
            // original process, never the newly selected app.
            let success = source.isCurrent && NotchMusicAutomation.setRepeat(target, availability: availability)
            DispatchQueue.main.async {
                guard let self, self.switchID == request else { return }
                self.pending = false
                guard self.availability?.target == source else { return }
                self.mode = success ? target : observed
                if !success { self.refresh(for: NotchMusicService.shared.playback) }
            }
            self?.queue.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                let fresh = NotchMusicAutomation.repeatMode(of: availability)
                DispatchQueue.main.async {
                    guard let self, self.switchID == request,
                          self.availability?.target == source,
                          let fresh else { return }
                    self.mode = fresh
                }
            }
        }
    }

    func stop() {
        open = false
        generation = UUID()
        switchID = UUID()
        availability = nil
        mode = nil
        pending = false
    }

    private func requestAccess(_ availability: NotchMusicAutomation.Availability) {
        requestingAccess = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if availability.target.isCurrent {
                _ = AppleScriptRunner.consentToAutomate(bundleID: availability.target.bundleIdentifier)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.requestingAccess = false
                guard self.open else { return }
                NotchMusicService.shared.refreshAutomation()
                self.refresh(for: NotchMusicService.shared.playback)
            }
        }
    }
}
