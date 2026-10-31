// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import Foundation
import SwiftUI

/// Reads Now Playing through `/usr/bin/perl` loading the adapter library
/// (`Sources/NowPlayingAdapter`). Since macOS 15.4 MediaRemote answers only
/// processes carrying Apple's signature; perl is one, the app is not. A
/// missing script or library, a failed run, a timeout and malformed output
/// all read as an empty playback session.
final class MediaRemoteNowPlayingBridge {
    let queue = DispatchQueue(label: "io.github.sam32j.lattice.radial-now-playing", qos: .userInitiated)
    /// 2 s: a cold perl load measured 500 ms with no session playing, and a
    /// real reply adds the MediaRemote round trip plus up to 16 MB of base64
    /// artwork through the pipe. A kill reads as nothing playing, so a deadline
    /// that is too tight empties the first wheel after login (#1280). The wheel
    /// shows `.loading` and holds the card anchor while it waits, so the extra
    /// second costs nothing on screen.
    static let replyTimeout: TimeInterval = 2.0

    var cancellation: BoundedProcessCancellation?

    func cancel() {
        cancellation?.cancel()
        cancellation = nil
    }

    func fetch(completion: @escaping (RadialNowPlayingSnapshot?) -> Void) {
        guard let script = Bundle.main.url(forResource: "now-playing", withExtension: "pl"),
              let library = Bundle.main.privateFrameworksURL?
                .appendingPathComponent("libLatticeNowPlaying.dylib"),
              FileManager.default.fileExists(atPath: library.path) else {
            completion(nil)
            return
        }
        cancel()
        let cancellation = BoundedProcessCancellation()
        self.cancellation = cancellation
        queue.async {
            let result = BoundedProcessRunner.run("/usr/bin/perl", [script.path, library.path],
                                                  timeout: Self.replyTimeout,
                                                  maxOutputBytes: RadialNowPlayingSupport.maximumAdapterReplyBytes, cancellation: cancellation)
            guard result.status == 0, !result.timedOut,
                  let reply = RadialNowPlayingSupport.adapterReply(from: result.output) else {
                completion(nil)
                return
            }
            let isPlaying = RadialNowPlayingSupport.playbackIsActive(
                remoteIsPlaying: reply.isPlaying, info: reply.info)
            completion(RadialNowPlayingSupport.snapshot(info: reply.info,
                                                        isPlaying: isPlaying,
                                                        appBundleIdentifier: reply.displayID,
                                                        appPID: reply.pid))
        }
    }
}
