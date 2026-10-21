// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Production preference setters and availability transitions, with device I/O inert.
enum AudioPriorityToggleTests {
    static var defaults: UserDefaults!
    enum FeatureRuntime { static var shared: FeatureAvailabilityTransitionTests.Runtime! }
    final class SoundOutputSwitcher {
        static let shared = SoundOutputSwitcher()
        func syncWithPreferences() {}
    }
    class InputState {
        var inputPriorityIsActive = false
        var running = false
        func start() { running = true }
        func stop() { running = false }
    }
    class State {
        var outputPriorityEnabled = false
        var inputPriorityEnabled = false
        var pendingOutputPreferenceChange = false
        var pendingInputPreferenceChange = false
        func mergeAvailableDevicesIntoPriorityLists() {}
        func updateDeviceNames() {}
        func scheduleEnforcement() {}
    }

    static func run(_ suite: TestSuite) {
        let domain = "vorss.tests.audio-priority-toggles.\(UUID())"
        defaults = UserDefaults(suiteName: domain)!
        defer {
            defaults.removePersistentDomain(forName: domain)
            FeatureAvailabilityTransitionTests.State.bindings = [:]
            FeatureRuntime.shared = nil
        }
        FeatureRuntime.shared = FeatureAvailabilityTransitionTests.Runtime(defaults)
        let service = Service()
        defaults.set(true, forKey: AppFeature.audioPriority.availabilityKey)
        defaults.set(true, forKey: AppFeature.soundOutputSwitcher.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.audioPriorityInputEnabled)
        service.outputPriorityEnabled = true
        service.inputPriorityEnabled = true
        service.setOutputPriorityEnabled(false)
        suite.expect(AppFeature.audioPriority.isAvailable(in: defaults)
                     && !AppFeature.soundOutputSwitcher.isAvailable(in: defaults)
                     && service.inputPriorityEnabled,
                     "disabling output priority preserves input priority and removes only the output switcher")
        defaults.set(false, forKey: DefaultsKey.microphoneLevelControlEnabled)
        defaults.set(false, forKey: DefaultsKey.audioPriorityInputEnabled)
        service.inputPriorityEnabled = false
        AudioInputDeviceManager.shared.running = false
        AudioInputDeviceManager.shared.inputPriorityIsActive = false
        service.setInputPriorityEnabled(true)
        suite.expect(AudioInputDeviceManager.shared.running && AudioInputDeviceManager.shared.inputPriorityIsActive,
                     "enabling input priority starts device observation even when availability was already on")
        service.setInputPriorityEnabled(false)
        suite.expect(!AppFeature.audioPriority.isAvailable(in: defaults)
                     && !AudioInputDeviceManager.shared.running,
                     "disabling both priority directions removes availability and stops input observation")
    }
}
