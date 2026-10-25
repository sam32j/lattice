// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import AudioToolbox
import Foundation

enum PadlockSound {
    static func url(locking: Bool, fileManager: FileManager = .default) -> URL? {
        if let padlock = Bundle(path: "/System/Library/Frameworks/SecurityInterface.framework")?
            .url(forResource: locking ? "lock" : "unlock", withExtension: "aif") { return padlock }
        let fallback = URL(fileURLWithPath: "/System/Library/Sounds/\(locking ? "Tink" : "Pop").aiff")
        return fileManager.fileExists(atPath: fallback.path) ? fallback : nil
    }

    static func play(locking: Bool) {
        guard let url = url(locking: locking) else { return }
        var sound: SystemSoundID = 0
        guard AudioServicesCreateSystemSoundID(url as CFURL, &sound) == noErr else { return }
        // Keep the default UI-sound behavior, respecting macOS's sound-effects preference.
        AudioServicesPlaySystemSoundWithCompletion(sound) { AudioServicesDisposeSystemSoundID(sound) }
    }
}
