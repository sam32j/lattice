// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Bridges the pure feature catalog to the live singletons. Every binding is
/// a closure, so merely mentioning a feature never instantiates its service:
/// a service only comes to life when its binding runs, and syncAtLaunch skips
/// unavailable features entirely — switched off in the hub means nothing
/// loads and nothing runs after the next launch. Main thread only, like the
/// services it drives.
final class FeatureRuntime: ObservableObject {
    static let shared = FeatureRuntime()

    /// Bumped on every availability change; views observing the runtime
    /// re-read the catalog when it moves.
    @Published private(set) var revision = 0

    /// Every feature that came to life in THIS process: available at launch
    /// or installed later in the session. A feature uninstalled mid-session
    /// stops working immediately, but its (inert) singleton only leaves
    /// memory on the next launch — this set is what the hub's restart banner
    /// keys off, including the install-then-uninstall-again case.
    private var loadedThisSession = Set(AppFeature.allCases.filter(\.isAvailable))

    /// What was installed when the app came up and has not been installed
    /// again since. A feature installed later in the session, a reinstall
    /// included, has not had its chance yet, so it is never offered for
    /// uninstalling as unused until the next launch.
    private var offerableThisSession = Set(AppFeature.allCases.filter(\.isAvailable))

    private init() {}

    /// True while something that loaded this session is now uninstalled, so
    /// a restart would actually unload it. Features already uninstalled when
    /// the app came up never loaded, so they need no restart.
    var needsRestartToUnload: Bool {
        loadedThisSession.contains { !$0.isToggleOwned && !$0.isAvailable }
    }

    /// Relaunches the app in place: a detached helper waits for this process
    /// to be gone and only then reopens it, so the fresh instance starts
    /// without the uninstalled features.
    ///
    /// It waits for the process rather than for a fixed moment because
    /// quitting flushes the clipboard history and every other pending write
    /// first: a reopen that arrives while the app is still here does nothing,
    /// and the restart ends as a plain quit.
    func relaunchApp() {
        let path = Bundle.main.bundlePath
        // Its own session: the reopen fires after we terminate, so the child
        // has to outlive the session it was started from. It gives up if we
        // are somehow still here after twenty seconds, so a quit that never
        // happens cannot reopen the app long afterwards.
        let script = """
            waited=0
            while kill -0 "$1" 2>/dev/null && [ "$waited" -lt 100 ]; do
                sleep 0.2
                waited=$((waited + 1))
            done
            kill -0 "$1" 2>/dev/null || /usr/bin/open "$2"
            """
        let pid = String(ProcessInfo.processInfo.processIdentifier)
        // Nothing is quit until the helper is running: without it, terminating
        // would close the app instead of restarting it.
        guard (try? DetachedProcess.spawn(
            "/bin/sh", ["-c", script, "lattice-relaunch", pid, path])) != nil
        else { return }
        NSApp.terminate(nil)
    }

    func isAvailable(_ feature: AppFeature) -> Bool { feature.isAvailable }

    var availableCount: Int { AppFeature.hubInstallableFeatures.filter(\.isAvailable).count }

    /// How many features this Mac can end up with. Counting against the whole
    /// catalog instead would leave the hub's install-all button forever one
    /// short of its own disabled condition on a Mac missing some hardware.
    /// An install that predates the check still counts, so the tally can
    /// never read more installed than installable.
    var installableCount: Int {
        AppFeature.hubInstallableFeatures.filter { $0.isHardwareSupported || $0.isAvailable }.count
    }

    /// The one gate every install passes, whichever surface asks: the hub
    /// row, the hub's install-all button, a preset and the first-run picker
    /// all decide here. A feature the Mac cannot run never installs, so a
    /// disabled row cannot be walked around from the button above it.
    ///
    /// Uninstalls are never refused and an existing install is never revoked:
    /// the check reads hardware and can be wrong, and a wrong answer that
    /// strands someone's settings costs far more than one that leaves a
    /// feature reporting itself unsupported.
    private func mayFlip(_ feature: AppFeature, to available: Bool) -> Bool {
        guard !feature.isToggleOwned || feature.group == .monitor else { return false }
        guard feature.isAvailable != available else { return false }
        guard available || !FeatureMutationGuard.isBusy(feature) else { return false }
        return !available || feature.isHardwareSupported
    }

    /// Availability is written as a batch before bindings run, so companions
    /// observe the same parent state. Off tears resources down, while a first
    /// install turns on the feature's main control. Saved choices survive a
    /// reinstall. One row, the "all" buttons and the Dynamic Island leaving
    /// with its extensions all pass through here, with one revision bump.
    /// Install all leaves enable keys alone: it would otherwise switch on
    /// intrusive features nobody picked, such as focus follows mouse.
    func setAvailable(_ features: [AppFeature], _ available: Bool,
                      enablingFirstInstalls: Bool = true) {
        var requestedList = features
        if features.contains(.screenshot) {
            for companion in [AppFeature.colorPicker, AppFeature.screenOCR] {
                if !requestedList.contains(companion) {
                    requestedList.append(companion)
                }
            }
        }
        let firstIslandInstall = available && requestedList.contains(.notch)
            && mayFlip(.notch, to: true)
            && !UserDefaults.standard.bool(forKey: DefaultsKey.notchInitialExtensionsInstalled)
        let requested = firstIslandInstall
            ? requestedList + AppFeature.dynamicIslandInitialExtensions.filter { !requestedList.contains($0) }
            : requestedList
        let savedValues = savedPreferences()
        let changed = requested.filter { mayFlip($0, to: available) }
        for feature in changed {
            if available && enablingFirstInstalls {
                feature.enableOnFirstInstall(in: .standard, savedValues: savedValues)
            }
            UserDefaults.standard.set(available, forKey: feature.availabilityKey)
            if available {
                loadedThisSession.insert(feature)
                offerableThisSession.remove(feature)
            }
        }
        for feature in changed { Self.bindings[feature]?() }
        if changed.contains(.clipboardHistory) { sync([.pastePlain]) }
        if firstIslandInstall && AppFeature.notch.isAvailable {
            UserDefaults.standard.set(true, forKey: DefaultsKey.notchInitialExtensionsInstalled)
        }
        if !changed.isEmpty { finishAvailabilityChange() }
    }



    /// Installed switches that were never once turned on, for the Features
    /// page to offer as one batch, minus the ones the person chose to keep.
    func neverSwitchedOnFeatures() -> [AppFeature] {
        let saved = savedPreferences()
        let kept = Self.keptFeatures()
        return AppFeature.neverSwitchedOn(isAvailable: \.isAvailable,
                                          boolFor: UserDefaults.standard.bool(forKey:),
                                          isSaved: { saved[$0] != nil })
            .filter { offerableThisSession.contains($0) && !kept.contains($0) }
    }

    /// Stops offering these features as unused. A later one that turns out
    /// never used is still offered, on its own merits.
    func keep(_ features: [AppFeature]) {
        let kept = Self.keptFeatures().union(features)
        UserDefaults.standard.set(kept.map(\.rawValue).sorted().joined(separator: ","),
                                  forKey: DefaultsKey.featureHubKeptFeatures)
    }

    private static func keptFeatures() -> Set<AppFeature> {
        Set((UserDefaults.standard.string(forKey: DefaultsKey.featureHubKeptFeatures) ?? "")
            .split(separator: ",")
            .compactMap { AppFeature(rawValue: String($0)) })
    }

    /// Bulk install or uninstall for the hub's "all" buttons.
    func setAllAvailable(_ available: Bool) {
        setAvailable(AppFeature.hubInstallableFeatures, available, enablingFirstInstalls: false)
    }

    private func savedPreferences() -> [String: Any] {
        guard let domain = Bundle.main.bundleIdentifier else { return [:] }
        return UserDefaults.standard.persistentDomain(forName: domain) ?? [:]
    }

    /// App-wide sounds register independently. Feature bindings launch only
    /// when available, with narrow recovery and keyboard-light exceptions.
    func syncAtLaunch() {
        LockSoundService.shared.syncWithPreferences()
        for feature in AppFeature.allCases where feature.isAvailable {
            Self.bindings[feature]?()
        }
        // Repay Bluetooth switched off by an earlier run, even when sleep
        // handling has since been disabled. Recovery does not enable it.
        if !AppFeature.bluetoothSleep.isAvailable,
           UserDefaults.standard.bool(forKey: DefaultsKey.bluetoothSleepRestorePending) {
            Self.bindings[.bluetoothSleep]?()
        }
        if !AppFeature.brightness.isAvailable,
           UserDefaults.standard.bool(forKey: DefaultsKey.keyboardBrightnessShortcutsEnabled)
            || NotchSupport.routes(.keyboardLight, in: .standard) {
            Self.bindings[.brightness]?()
        }
    }

    /// Capability changes can enable a saved preference without constructing
    /// services for unsupported or switched-off controls.
    func hardwareDidChange() {
        sync([.extraBrightness, .fanControl])
    }

    /// Permanent input controls must also sync when off: they can have started
    /// directly from Settings, so an off change must always reach teardown.
    func sync(_ features: [AppFeature]) {
        guard !InputEventTap.isBlocked else { return }
        for feature in features where feature.isToggleOwned || feature.isAvailable || loadedThisSession.contains(feature) {
            if feature.isAvailable { loadedThisSession.insert(feature) }
            Self.bindings[feature]?()
            if feature == .clipboardHistory, loadedThisSession.contains(.pastePlain) || AppFeature.pastePlain.isAvailable {
                if AppFeature.pastePlain.isAvailable { loadedThisSession.insert(.pastePlain) }
                Self.bindings[.pastePlain]?()
            }
        }
        if features.contains(where: \.isToggleOwned) {
            revision += 1
            if AppFeature.commandBar.isAvailable { CommandBarService.shared.noteHubChange() }
        }
    }

    /// One bump for Settings, and the Command Bar drops rows of features that
    /// just left the hub so a pin cannot linger as a bare id.
    func finishAvailabilityChange() {
        LatticeHubService.shared.refreshAvailability()
        revision += 1
        if AppFeature.commandBar.isAvailable { CommandBarService.shared.noteHubChange() }
        if AppFeature.notch.isAvailable { NotchService.shared.syncWithPreferences() }
    }

}

/// Hardware a feature needs and this Mac may not have. One switch answers
/// both questions, so a feature can never be unsupported without a reason to
/// show for it, and a feature added here can never grey a row silently.
/// It lives beside the runtime rather than in the catalog because the answer
/// comes from a service, and the catalog stays a pure description.
extension AppFeature {
    /// Why this Mac cannot run the feature, ready to show. `nil` when it can,
    /// or when the feature depends on no hardware at all.
    var hardwareUnsupportedReason: String? {
        switch self {
        case .fanControl:
            return FanControlHardware.hasControllableFan
                ? nil : FeatureStrings.fanControl(L10n.shared.language).noFans
        case .extraBrightness:
            return XDRDisplaySupport.supportedScreen != nil ? nil : L10n.shared.s.extraBrightnessUnsupported
        default:
            return nil
        }
    }

    var isHardwareSupported: Bool { hardwareUnsupportedReason == nil }

    /// Why a feature list must refuse to install this feature, ready to show
    /// as a tooltip. `nil` once it is installed: the check reads hardware and
    /// can be wrong, so it is never allowed to strand an existing install
    /// behind a greyed row. Both the hub and the first-run picker read this,
    /// so neither can drift from the gate in `FeatureRuntime`.
    var installBlockedReason: String? {
        isAvailable ? nil : hardwareUnsupportedReason
    }
}
