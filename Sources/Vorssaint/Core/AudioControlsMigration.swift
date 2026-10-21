import Foundation

extension Defaults {
    static let audioControlsMigrationKey = "audioControlsMigrated"

    /// Migrate retired sound installation gates to their owning toggles before defaults registration.
    static func migrateAudioControls(in defaults: UserDefaults) {
        guard !defaults.bool(forKey: audioControlsMigrationKey) else { return }

        if let mixerInstalled = defaults.object(forKey: AppFeature.mixer.availabilityKey) as? Bool, !mixerInstalled {
            defaults.set(false, forKey: DefaultsKey.volumeMixerEnabled)
            defaults.set(false, forKey: DefaultsKey.microphoneLevelControlEnabled)
        }
        if let switcherInstalled = defaults.object(forKey: AppFeature.soundOutputSwitcher.availabilityKey) as? Bool, !switcherInstalled {
            defaults.set(false, forKey: DefaultsKey.soundOutputSwitcherEnabled)
        }
        if let musicBlockInstalled = defaults.object(forKey: AppFeature.musicBlock.availabilityKey) as? Bool, !musicBlockInstalled {
            defaults.set(false, forKey: DefaultsKey.musicBlockEnabled)
        }
        if let priorityInstalled = defaults.object(forKey: AppFeature.audioPriority.availabilityKey) as? Bool, !priorityInstalled {
            defaults.set(false, forKey: DefaultsKey.audioPriorityOutputEnabled)
            defaults.set(false, forKey: DefaultsKey.audioPriorityInputEnabled)
        }
        if let micMuteInstalled = defaults.object(forKey: AppFeature.micMute.availabilityKey) as? Bool, !micMuteInstalled {
            defaults.set(false, forKey: DefaultsKey.micMuteShortcutEnabled)
        }

        defaults.set(true, forKey: audioControlsMigrationKey)
    }
}
