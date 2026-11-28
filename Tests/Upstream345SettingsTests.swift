// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// The v3.4.5 ports' visible controls sit on the pages the UI audit assigned
/// them, start off, travel with backups, carry Settings Search keywords and
/// requirements, and bring nothing section D rejected.
enum Upstream345SettingsTests {
    static func run(_ suite: TestSuite) {
        func source(_ path: String) -> String {
            (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        }

        // U4: Window Layout Option-drag tiling awareness.
        let gestureSupport = source("Sources/Lattice/Services/WindowLayout/WindowGestureSupport.swift")
        suite.expect(gestureSupport.contains("EnableTilingByEdgeDrag")
                     && gestureSupport.contains("EnableTilingOptionAccelerator"),
                     "WindowGestureSupport distinguishes macOS Option-drag tiling from edge-drag conflict")

        // U5: XDG settings file save row in Data & Permissions.
        let dataPerms = source("Sources/Lattice/UI/Settings/DataPermissionsSettings.swift")
        suite.expect(dataPerms.contains("doc.badge.gearshape")
                     && dataPerms.contains("backup.configFileButton")
                     && dataPerms.contains("backup.configFileAction")
                     && dataPerms.contains("SettingsBackup.writeConfigFile()")
                     && dataPerms.contains("backup.importConfigFileNotice"),
                     "Data & Permissions hosts the Save to settings file row, confirmation alert, and import precedence notice")

        // U7: Stay Awake power-loss delay follow-up in StayAwakeSettings.
        let stayAwake = source("Sources/Lattice/UI/Settings/StayAwakeSettings.swift")
        suite.expect(stayAwake.contains("DefaultsKey.keepAwakePowerDisconnectDelay")
                     && stayAwake.contains("powerDisconnectDelayPresets = [0, 10, 30, 60]")
                     && stayAwake.contains("if connectedToPower {")
                     && stayAwake.contains("settingsExpansionAnimation(value: [pickingTime, connectedToPower,"),
                     "StayAwakeSettings reveals the power-loss delay preset picker under Power inside the page animation")

        // U8: Cursor provider row in AI Agents settings.
        let agentsSettings = source("Sources/Lattice/UI/Settings/NotchAgentsSettings.swift")
        suite.expect(agentsSettings.contains("providerRow(.cursor, isOn: $cursor)"),
                     "NotchAgentsSettings renders the Cursor provider row")

        // U10 & U34: Mic Mute verification states & call-app unmute switch.
        let audioInput = source("Sources/Lattice/UI/Settings/AudioInputSettings.swift")
        suite.expect(audioInput.contains("DefaultsKey.micMuteFollowCallApps")
                     && audioInput.contains("SettingsToggleRow(title: l10n.s.micMuteFollowCallAppsToggle")
                     && audioInput.contains("MicMuteService.shared.syncWithPreferences()")
                     && audioInput.contains("if micMute.warning == .manualRestore"),
                     "AudioInputSettings hosts the U34 call-app switch and keeps non-manual warnings on the mute icon")

        // U11: Audio priority list removes unavailable entries while keeping DragGesture reorder.
        let priorityList = source("Sources/Lattice/UI/Audio/AudioPriorityDeviceList.swift")
        suite.expect(priorityList.contains("DragGesture")
                     && !priorityList.contains(".onDrag(")
                     && !priorityList.contains(".onDrop("),
                     "AudioPriorityDeviceList preserves in-place DragGesture reordering")

        // U12: Fan Control pending recovery uses amber rather than red.
        let fanSection = source("Sources/Lattice/UI/MenuPanel/FanControlSection.swift")
        suite.expect(fanSection.contains("systemControlUnconfirmed")
                     && fanSection.contains(".orange"),
                     "FanControlSection distinguishes pending unconfirmed recovery with amber styling")

        // U14: Monitor Alerts repeat picker excludes disk-only alerts.
        let monitorAlerts = source("Sources/Lattice/UI/Settings/MonitorAlertsControls.swift")
        suite.expect(monitorAlerts.contains("MonitorAlertService.anyEnabled(in: .standard, includingDisk: false)"),
                     "MonitorAlertsRepeatMenu stays disabled when only low-disk alerts are enabled")

        // Defaults & backup coverage.
        let registered = Defaults.registeredDefaults
        suite.expect(registered[DefaultsKey.micMuteFollowCallApps] as? Bool == false
                     && registered[DefaultsKey.keepAwakePowerDisconnectDelay] as? Int == 0,
                     "U34 call-app unmute starts off and U7 power disconnect delay starts at 0")
        let backupKeys = SettingsBackupSupport.exportKeys()
        suite.expect(backupKeys.isSuperset(of: [DefaultsKey.micMuteFollowCallApps,
                                                DefaultsKey.keepAwakePowerDisconnectDelay]),
                     "new 3.4.5 preferences travel with settings backups")

        // Settings Search keywords, requirements, and aliases.
        let directory = source("Sources/Lattice/UI/Settings/SettingsDirectoryPages.swift")
        suite.expect(directory.contains("aliases: [\"xdg\", \"config file\", \"dotfiles\", \"settings file\"]")
                     && directory.contains("FeatureStrings.backup(language).configFileButton"),
                     "U5 XDG settings file carries its Settings Search keywords and aliases")
        suite.expect(directory.contains("(.keepAwake, DefaultsKey.keepAwakeConnectedToPower,")
                     && directory.contains("powerDisconnectDelay"),
                     "U7 power disconnect delay requires keepAwakeConnectedToPower in Settings Search")
        suite.expect(directory.contains("\"Cursor\""),
                     "U8 Cursor is indexed in Settings Search")
        suite.expect(directory.contains("aliases: [\"call\", \"zoom\", \"teams\"]")
                     && directory.contains("(.micMute, DefaultsKey.microphoneLevelControlEnabled,")
                     && directory.contains("s.micMuteFollowCallAppsToggle"),
                     "U34 call-app unmute requires microphoneLevelControlEnabled and carries call/zoom/teams aliases")

        // Section D & U15: Lattice branding and no rejected features in shipped copy.
        suite.expect(FeatureStrings.backup(.enUS).invalidFile == "This file is not a valid Lattice backup.",
                     "U15 invalid backup message names Lattice")
        for language in AppLanguage.allCases {
            let s = Strings.localized(language)
            let b = FeatureStrings.backup(language)
            let k = FeatureStrings.keepAwakeAutomation(language)
            let m = FeatureStrings.monitorAlerts(language)
            let f = FeatureStrings.fanControl(language)
            let shipped = [
                b.invalidFile, b.configFileConfirmFormat, b.importConfigFileNotice,
                k.powerDisconnectDelay, k.waitingForPower,
                m.caption, f.controlUnconfirmed, f.awaitingSystemControl,
                s.micMuteFollowCallAppsToggle, s.micMuteFollowCallAppsCaption,
                s.micMutePartialHUD, s.micUnmutePartialHUD, s.micRestoreExhaustedHUD, s.micManualRestore,
            ]
            suite.expect(!shipped.contains { $0.localizedCaseInsensitiveContains("Vorssaint") },
                         "\(language) 3.4.5 shipped copy says Lattice, never Vorssaint")
        }
    }
}
