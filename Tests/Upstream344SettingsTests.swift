// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// The v3.4.4 ports' visible controls sit on the pages the UI audit assigned
/// them, start off, travel with backups, and bring nothing the audit rejected.
enum Upstream344SettingsTests {
    static func run(_ suite: TestSuite) {
        func source(_ path: String) -> String {
            (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        }

        // Ownership: each control on its assigned page (ui-audit U1, U2, U3, U6, U9, U32).
        let mouseCard = source("Sources/Lattice/UI/Settings/MouseSettings.swift")
        let scrolling = source("Sources/Lattice/UI/Settings/MouseScrollingSettings.swift")
        suite.expect(mouseCard.contains("scrollSpeedControls.settingsSectionAnchor(.scrollSpeed")
                     && scrolling.contains("PermissionGatedToggle(l10n.s.scrollSpeedName")
                     && scrolling.contains("if scrollSpeedEnabled {")
                     && scrolling.contains("ScrollWheelSupport.speedMultiplierPresets"),
                     "scroll speed lives in the Mouse Scrolling card with its follow-ups revealed by its switch")
        suite.expect(AppFeature.scrollSpeed.settingsDestination.page == .mouse
                     && AppFeature.scrollSpeed.settingsDestination.sectionAnchor == .scrollSpeed,
                     "scroll speed's feature destination opens its Mouse section")
        let switcher = source("Sources/Lattice/UI/Settings/SwitcherSettings.swift")
        suite.expect(switcher.contains("Toggle(l10n.s.switcherIgnoreHoverSelection"),
                     "ignore hover selection sits on the Window Switcher page")
        let snapping = source("Sources/Lattice/UI/Settings/WindowSnappingControls.swift")
        let revealed = snapping.components(separatedBy: "if edgeSnapEnabled {").dropFirst().first ?? ""
        suite.expect(revealed.prefix(2_500).contains("isOn: $edgeSnapRestoreOnDrag"),
                     "restore-on-drag is revealed with the edge snapping follow-ups")
        let switchRow = snapping.components(separatedBy: "SettingsControlRow(title: text.edgeSnapSection").dropFirst().first ?? ""
        suite.expect(switchRow.prefix(600).contains("SettingsStatusDot(status: systemTilingStatus)")
                     && snapping.components(separatedBy: "if systemTilingEnabled {").count == 2,
                     "a macOS tiling conflict shows as a status icon beside the edge snapping switch, like Super Key's")
        let tab = source("Sources/Lattice/UI/Settings/AppUninstallerTab.swift")
        let panel = source("Sources/Lattice/UI/MenuPanel/PanelUninstallerView.swift")
        suite.expect(tab.contains("uninstaller.setAllIncluded(") && panel.contains("uninstaller.setAllIncluded(")
                     && tab.contains("showsTitle: false") && panel.contains("showsTitle: false"),
                     "both uninstaller footers offer Select all with the count as their visible text")
        let editor = source("Sources/Lattice/UI/Recorder/RecorderEditorView.swift")
        suite.expect(editor.contains("RecorderExportOptionsMenu(model: model)")
                     && !editor.contains("RecorderExportFormatControl(")
                     && editor.contains("controller.copyGIF") && editor.contains("controller.saveGIF"),
                     "GIF size and rate join the export options menu; no format switch is added to the toolbar")
        let recorderSettings = source("Sources/Lattice/UI/Settings/ScreenRecorderSettings.swift")
        suite.expect(recorderSettings.contains("DefaultsKey.recorderGIFScalePercent")
                     && recorderSettings.contains("DefaultsKey.recorderGIFFrameRate"),
                     "Settings keeps the GIF size and frame rate defaults")

        // Follow-ups reveal inside their page's expansion animation (ui-audit E2):
        // the parent switch drives the page animation, so the card grows in step.
        suite.expect(mouseCard.contains("settingsExpansionAnimation(value: [horizontalScrollEnabled, scrollSpeedEnabled,"),
                     "the Mouse page animates the scroll speed follow-ups with its other reveals")
        let layoutPage = source("Sources/Lattice/UI/Settings/WindowLayoutSettings.swift")
        suite.expect(layoutPage.contains("settingsExpansionAnimation(value: [systemTilingEnabled, edgeSnapEnabled,")
                     && revealed.prefix(2_500).contains(".transition(.settingsReveal)"),
                     "restore-on-drag reveals with the edge snapping group the Window Layout page animates")

        // Off by default and part of backups.
        let registered = Defaults.registeredDefaults
        suite.expect(registered[DefaultsKey.scrollSpeedEnabled] as? Bool == false
                     && registered[DefaultsKey.switcherIgnoreHoverSelection] as? Bool == false
                     && registered[DefaultsKey.windowEdgeSnapRestoreOnDrag] as? Bool == false
                     && registered[DefaultsKey.recorderGIFScalePercent] as? Int == 75,
                     "the new switches start off and new GIFs start at 75%")
        let backup = SettingsBackupSupport.exportKeys()
        suite.expect(backup.isSuperset(of: [DefaultsKey.scrollSpeedEnabled, DefaultsKey.scrollSpeedModifier,
                                            DefaultsKey.scrollSpeedMultiplier, DefaultsKey.switcherIgnoreHoverSelection,
                                            DefaultsKey.windowEdgeSnapRestoreOnDrag, DefaultsKey.recorderGIFScalePercent]),
                     "the new preferences travel with settings backups")

        // The GIF size default moved to percentages without losing a choice.
        // The migration itself runs before registration; the mapping is tested here.
        suite.expect(["small", "medium", "large", nil, "bogus"].map(Defaults.gifScalePercent(fromLegacySize:))
                     == [50, 75, 100, 75, 75],
                     "an old GIF size maps to its percentage preset")
        suite.expect(RecorderSupport.nearestGIFScalePreset(40) == 50
                     && RecorderSupport.nearestGIFScalePreset(90) == 100
                     && RecorderSupport.nearestGIFScalePreset(75) == 75,
                     "Settings shows an odd saved size as its nearest preset")

        // Section D: nothing the audit rejected arrives in shipped copy.
        for language in AppLanguage.allCases {
            let s = Strings.localized(language)
            let shipped = [s.scrollSpeedName, s.scrollSpeedCaption, s.switcherIgnoreHoverSelection,
                           s.uninstallerSelectAll,
                           WindowEdgeSnapRestoreStrings.localized(language).title,
                           WindowEdgeSnapRestoreStrings.localized(language).caption]
            suite.expect(!shipped.contains { $0.localizedCaseInsensitiveContains("Vorssaint") },
                         "\(language) copy from the 3.4.4 ports says Lattice, never Vorssaint")
        }
        let english = Strings.localized(.enUS)
        suite.expect(!english.scrollSpeedCaption.localizedCaseInsensitiveContains("pinch")
                     && !english.switcherIgnoreHoverSelection.localizedCaseInsensitiveContains("all windows"),
                     "no Pinch Zoom or All-windows wording arrives with the ports")
    }
}
