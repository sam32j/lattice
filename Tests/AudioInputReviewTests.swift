// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import CoreAudio
import Combine

extension MixerInputVolumeContract {
    static func pendingMuteSurvivesDeviceChange() -> Bool {
        HAL.reset()
        HAL.levels[HAL.key(10)] = 0.5
        let service = MicMuteService.shared
        service.setMuted(true)
        service.reapplyIfNeeded()
        DispatchQueue.drain()
        let kept = service.isMuted && HAL.levels[HAL.key(10)] == 0
            && UserDefaults.standard.bool(forKey: DefaultsKey.micMuteActive)
        HAL.reset()
        return kept
    }

    static func reviewChecks(_ suite: TestSuite) {
        restorationOwnershipChecks(suite)
        func manager() -> AudioInputDeviceManager {
            let manager = AudioInputDeviceManager()
            manager.start()
            DispatchQueue.drain()
            return manager
        }
        HAL.reset()
        HAL.devices = [10, 20]
        HAL.levels[HAL.key(10)] = 0.5; HAL.levels[HAL.key(20)] = 0.5
        let preferred = manager()
        preferred.setPreferredInputDeviceUID("device-10")
        DispatchQueue.drain()
        HAL.current = 20
        let readsBeforeNotification = HAL.reads
        preferred.scheduleListenerRefresh()
        suite.expect(HAL.reads == readsBeforeNotification,
                     "default-input notifications never synchronously query the audio daemon")
        DispatchQueue.drain()
        suite.expect(UserDefaults.standard.string(forKey: DefaultsKey.preferredInputDevice) == "device-10",
                     "external input changes cannot overwrite the user's saved microphone preference")
        preferred.stop(); DispatchQueue.drain()

        HAL.reset()
        HAL.devices = [10, 20]
        HAL.running = [10, 20]
        HAL.levels[HAL.key(10)] = 0.5; HAL.levels[HAL.key(20)] = 0.5
        let active = manager()
        var activity: [Bool] = []
        let subscription = active.$isInputActive.sink { activity.append($0) }
        activity = []
        HAL.current = 20
        active.refreshAndApply()
        DispatchQueue.drain()
        suite.expect(active.isInputActive && !activity.contains(false),
                     "moving between active microphones never reports a synthetic session end")
        HAL.running = []
        active.updateInputActiveState(for: 20)
        suite.expect(!active.isInputActive && activity.last == false,
                     "a real recording-session end still publishes inactivity")
        subscription.cancel()
        active.stop(); DispatchQueue.drain()

        HAL.reset()
        HAL.mute[10] = 1
        let mute = MicMuteService.shared
        let readsBeforeSync = HAL.reads
        mute.syncWithPreferences()
        suite.expect(HAL.reads == readsBeforeSync,
                     "microphone preference sync reads external mute only on the HAL queue")
        DispatchQueue.drain()
        suite.expect(mute.isMuted && !mute.installedListeners.isEmpty,
                     "asynchronous external-mute detection publishes and installs device listeners")
        let readsBeforeReapply = HAL.reads
        mute.reapplyIfNeeded()
        suite.expect(HAL.reads == readsBeforeReapply,
                     "device-change mute recovery returns without blocking on the audio daemon")
        DispatchQueue.drain()
        mute.setMuted(false); DispatchQueue.drain()
        HAL.reset()
        HAL.mute[10] = 1
        let stale = MicMuteService.shared
        stale.syncWithPreferences()
        stale.halQueue.run()
        stale.setMuted(false)
        DispatchQueue.main.run()
        suite.expect(!stale.isMuted, "an old hardware mute reading cannot overwrite an explicit unmute request")
        DispatchQueue.drain()
        HAL.reset()
        HAL.mute[10] = 0
        let notified = MicMuteService.shared
        notified.setMuted(true)
        DispatchQueue.drain()
        notified.setMuted(false)
        notified.halQueue.run()
        notified.reapplyIfNeeded()
        DispatchQueue.drain()
        suite.expect(!UserDefaults.standard.bool(forKey: DefaultsKey.micMuteActive)
                     && !notified.isMuted && notified.inputVolumeAdjustmentLifetime != nil,
                     "a notification between unmute sweep and publication cannot cancel the user's completion")
        HAL.reset()
    }

    private static func restorationOwnershipChecks(_ suite: TestSuite) {
        for path in 0..<3 {
            HAL.reset()
            HAL.devices = [10, 20]
            HAL.mute = [10: 1, 20: 1]
            UserDefaults.standard.set(["device-10"], forKey: DefaultsKey.micMuteMutedDevices)
            let mute = MicMuteService.shared
            switch path {
            case 0: mute.syncWithPreferences()
            case 1: mute.reapplyIfNeeded()
            default: mute.unmuteForTeardown()
            }
            DispatchQueue.drain()
            suite.expect(HAL.mute[10] == 0 && HAL.mute[20] == 1,
                         "automatic claim release restores only Lattice-owned microphones on path \(path)")
            mute.setMuted(false)
            DispatchQueue.drain()
            suite.expect(HAL.mute[20] == 0, "explicit Unmute still opens an independently muted microphone")
        }
        HAL.reset()
    }
}
