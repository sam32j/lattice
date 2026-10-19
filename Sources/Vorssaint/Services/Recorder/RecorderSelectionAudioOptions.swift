// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Foundation

/// Shared by selection and waiting controls; changes persist for the next take.
final class RecorderSelectionAudioOptions: ObservableObject {
    private let defaults: UserDefaults
    @Published var systemAudio: Bool {
        didSet { defaults.set(systemAudio, forKey: DefaultsKey.recorderSystemAudio) }
    }
    @Published var microphone: Bool {
        didSet { defaults.set(microphone, forKey: DefaultsKey.recorderMicrophone) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        systemAudio = defaults.bool(forKey: DefaultsKey.recorderSystemAudio)
        microphone = defaults.bool(forKey: DefaultsKey.recorderMicrophone)
    }
}
