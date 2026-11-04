// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The App Switcher section of the Dock & Applications page: header
/// enablement, three illustrative layouts, automatic system-shortcut
/// replacement, and streamlined dropdown/switch controls. The page around it
/// supplies the scroll view and the permission cards.
struct SwitcherSettingsSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var secureInput = SecureInputMonitor.shared
    @State private var switcherCoversSecureInput = AppSwitcher.shared.coversSecureInput
    @AppStorage(DefaultsKey.switcherEnabled) private var switcherEnabled = true
    @AppStorage(DefaultsKey.switcherShortcut) private var switcherShortcutStorage = GlobalShortcut.switcherDefault.storageValue
    @AppStorage(DefaultsKey.switcherWindowShortcut) private var switcherWindowShortcutStorage = GlobalShortcut.switcherWindowDefault.storageValue
    @AppStorage(DefaultsKey.switcherIconRowMode) private var switcherIconRowMode = false
    @AppStorage(DefaultsKey.switcherSimpleMode) private var switcherSimpleMode = false
    @AppStorage(DefaultsKey.switcherPreviewSize) private var switcherPreviewSize = "normal"
    @AppStorage(DefaultsKey.minimalWindowPreviews) private var minimalPreviews = false
    @AppStorage(DefaultsKey.switcherMergeTabs) private var switcherMergeTabs = false
    @AppStorage(DefaultsKey.switcherWindowlessApps) private var switcherWindowlessApps = SwitcherWindowlessApps.fallback.rawValue
    @AppStorage(DefaultsKey.switcherMinimizedPlacement) private var switcherMinimizedPlacement = WindowSwitchMinimizedPlacement.normal.rawValue
    @AppStorage(DefaultsKey.switcherShowFullscreenWindows) private var switcherShowFullscreenWindows = true
    @AppStorage(DefaultsKey.switcherScreenPlacement) private var switcherScreenPlacement = SwitcherScreenPlacement.fallback.rawValue
    @AppStorage(DefaultsKey.switcherCurrentDisplayOnly) private var switcherCurrentDisplayOnly = false
    @AppStorage(DefaultsKey.switcherCurrentSpaceOnly) private var switcherCurrentSpaceOnly = false
    @AppStorage(DefaultsKey.switcherAppearanceDelay) private var switcherAppearanceDelay = SwitcherSupport.defaultAppearanceDelayMilliseconds

    private var pages: SettingsPageStrings { FeatureStrings.settingsPages(l10n.language) }
    private var copy: SwitcherSettingsCopy { SwitcherSettingsCopy.text(l10n.language) }
    private var switcherEngaged: Bool { switcherEnabled && AppFeature.switcher.isAvailable }

    private var switcherUsesSystemShortcuts: Bool {
        let apps = GlobalShortcut.saved(for: DefaultsKey.switcherShortcut, fallback: .switcherDefault)
        let windows = GlobalShortcut.saved(for: DefaultsKey.switcherWindowShortcut, fallback: .switcherWindowDefault)
        let _ = switcherShortcutStorage
        let _ = switcherWindowShortcutStorage
        return AppSwitcher.replacesNativeHotkeys(appsShortcut: apps, windowShortcut: windows)
    }

    private var switcherReplacesSystemShortcuts: Bool {
        switcherEngaged && switcherUsesSystemShortcuts && permissions.accessibility
    }

    private var showsSecureInputWarning: Bool {
        // Carbon stand-ins keep the shortcut working under secure input. Only
        // when they cannot register does ⌘Tab go back to macOS until it ends.
        switcherReplacesSystemShortcuts && secureInput.holder != .off && !switcherCoversSecureInput
    }


    var body: some View {
        switcherCard
            .settingsSectionAnchor(.switcher, cornerRadius: 16)
            .toggleStyle(.switch)
            .observesSecureInput(isActive: switcherReplacesSystemShortcuts)
            .onReceive(AppSwitcher.shared.$coversSecureInput) { switcherCoversSecureInput = $0 }
            .settingsExpansionAnimation(value: [
                switcherEngaged,
                permissions.accessibility,
                permissions.screenRecording,
                switcherSimpleMode,
                switcherIconRowMode,
                switcherWindowlessApps == SwitcherWindowlessApps.all.rawValue,
                showsSecureInputWarning,
            ])
    }

    // MARK: - App switcher

    private var switcherCard: some View {
        SettingsCard(symbol: "rectangle.on.rectangle",
                     title: l10n.s.switcherSection,
                     caption: switcherHeaderCaption,
                     headerAccessory: {
                         PermissionGatedToggle(l10n.s.switcherSection, isOn: Binding(
                             get: { switcherEngaged },
                             set: { enabled in
                                 switcherEnabled = enabled
                                 settingsApplyFeatureSwitch(enabled: enabled) {
                                     let isEnabled = UserDefaults.standard.bool(forKey: DefaultsKey.switcherEnabled)
                                     FeatureRuntime.shared.setAvailable([.switcher], isEnabled)
                                     AppSwitcher.shared.syncWithPreferences()
                                 }
                             }
                         ), requiring: [.accessibility, .screenRecording], feature: .switcher)
                         .labelsHidden()
                     }) {
            if switcherEngaged {
                VStack(alignment: .leading, spacing: 14) {
                    layoutAndShortcutsSection
                    Divider()
                    displayAndPreviewsSection
                    Divider()
                    windowsAndAppsSection
                }
                .padding(.leading, settingsRowTextInset)
                .transition(.settingsReveal)
            }
        }
    }

    private var layoutAndShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                SwitcherLayoutChoice(layout: .windows,
                                     title: pages.switcherLayoutWindows,
                                     caption: copy.layoutWindowsCaption,
                                     selected: layout == .windows) {
                    choose(.windows)
                }
                SwitcherLayoutChoice(layout: .icons,
                                     title: pages.switcherLayoutIcons,
                                     caption: copy.layoutIconsCaption,
                                     selected: layout == .icons) {
                    choose(.icons)
                }
                SwitcherLayoutChoice(layout: .simple,
                                     title: pages.switcherLayoutSimple,
                                     caption: copy.layoutSimpleCaption,
                                     selected: layout == .simple) {
                    choose(.simple)
                }
            }

            ShortcutPreferenceRow(role: .switcher, label: copy.switchAppsShortcut) {
                AppSwitcher.shared.syncWithPreferences()
            }
            VStack(alignment: .leading, spacing: 17) {
                ShortcutPreferenceRow(role: .switcherWindow, label: copy.switchWindowsShortcut) {
                    AppSwitcher.shared.syncWithPreferences()
                }
                if showsSecureInputWarning {
                    SecureInputRow(blocking: .switcher)
                        .transition(.settingsReveal)
                }
            }

            SettingsControlRow(title: l10n.s.switcherAppearanceDelay) {
                Picker(l10n.s.switcherAppearanceDelay, selection: switcherAppearanceDelayBinding) {
                    if ![0, 100, 250].contains(switcherAppearanceDelayBinding.wrappedValue) {
                        Text("\(switcherAppearanceDelayBinding.wrappedValue) ms")
                            .tag(switcherAppearanceDelayBinding.wrappedValue)
                    }
                    Text(copy.delayInstant).tag(0)
                    Text(l10n.s.dockPreviewDelayDefault).tag(100)
                    Text(l10n.s.dockPreviewDelayLonger).tag(250)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }
        }
    }

    private var displayAndPreviewsSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SettingsControlRow(title: l10n.s.switcherScreenPlacementLabel) {
                Picker(l10n.s.switcherScreenPlacementLabel, selection: $switcherScreenPlacement) {
                    Text(l10n.s.switcherScreenPlacementPointer).tag(SwitcherScreenPlacement.pointer.rawValue)
                    Text(l10n.s.switcherScreenPlacementMenuBar).tag(SwitcherScreenPlacement.menuBar.rawValue)
                    Text(l10n.s.switcherScreenPlacementActiveWindow).tag(SwitcherScreenPlacement.activeWindow.rawValue)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            }

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 13) {
                    SettingsControlRow(title: l10n.s.previewSizeLabel) {
                        Picker(l10n.s.previewSizeLabel, selection: $switcherPreviewSize) {
                            Text(l10n.s.previewSizeSmall).tag("small")
                            Text(l10n.s.previewSizeNormal).tag("normal")
                            Text(l10n.s.previewSizeLarge).tag("large")
                            Text(l10n.s.previewSizeXLarge).tag("xlarge")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                        .onChange(of: switcherPreviewSize) { _, _ in
                            AppSwitcher.shared.syncWithPreferences()
                        }
                    }

                    VStack(alignment: .leading, spacing: 13) {
                        SettingsControlRow(title: l10n.s.minimalWindowPreviews) {
                            Toggle(l10n.s.minimalWindowPreviews, isOn: $minimalPreviews)
                                .labelsHidden()
                        }

                        // Only Window previews groups: Large icons always shows
                        // every window of the selected app, and the simple list is
                        // one icon per app already.
                        if layout == .windows {
                            SettingsControlRow(title: l10n.s.switcherMergeTabs) {
                                Toggle(l10n.s.switcherMergeTabs, isOn: $switcherMergeTabs)
                                    .labelsHidden()
                            }
                            .transition(.settingsReveal)
                        }
                    }
                }
            }
        }
    }

    private var windowsAndAppsSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SettingsControlRow(title: l10n.s.switcherCurrentDisplayOnly) {
                Toggle(l10n.s.switcherCurrentDisplayOnly, isOn: $switcherCurrentDisplayOnly)
                    .labelsHidden()
            }

            SettingsControlRow(title: l10n.s.switcherCurrentSpaceOnly) {
                Toggle(l10n.s.switcherCurrentSpaceOnly, isOn: $switcherCurrentSpaceOnly)
                    .labelsHidden()
            }

            SettingsControlRow(title: l10n.s.switcherShowFullscreenWindows) {
                Toggle(l10n.s.switcherShowFullscreenWindows, isOn: $switcherShowFullscreenWindows)
                    .labelsHidden()
                    .onChange(of: switcherShowFullscreenWindows) { _, _ in
                        AppSwitcher.shared.syncWithPreferences()
                    }
            }

            SettingsControlRow(title: l10n.s.switcherMinimizedPlacementLabel) {
                Picker(l10n.s.switcherMinimizedPlacementLabel, selection: $switcherMinimizedPlacement) {
                    Text(l10n.s.switcherMinimizedPlacementNormal).tag(WindowSwitchMinimizedPlacement.normal.rawValue)
                    Text(l10n.s.switcherMinimizedPlacementEnd).tag(WindowSwitchMinimizedPlacement.end.rawValue)
                    Text(l10n.s.switcherMinimizedPlacementHidden).tag(WindowSwitchMinimizedPlacement.hidden.rawValue)
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
                .onChange(of: switcherMinimizedPlacement) { _, _ in
                    AppSwitcher.shared.syncWithPreferences()
                }
            }

            VStack(alignment: .leading, spacing: 13) {
                SettingsControlRow(title: l10n.s.switcherWindowlessApps) {
                    Toggle(l10n.s.switcherWindowlessApps, isOn: hidesWindowlessAppsBinding)
                        .labelsHidden()
                }

                // Finder runs with no window most of the time, so it can stay
                // listed while other windowless apps are hidden.
                if windowlessMode != .all {
                    SettingsControlRow(title: l10n.s.switcherWindowlessAppsFinder) {
                        Toggle(l10n.s.switcherWindowlessAppsFinder, isOn: keepsWindowlessFinderBinding)
                            .labelsHidden()
                    }
                    .transition(.settingsReveal)
                }
            }

            SwitcherAppRulesList()
        }
    }

    // MARK: - State

    private var switcherHeaderCaption: String? {
        guard switcherEngaged else { return nil }
        if !permissions.accessibility {
            return "\(l10n.s.permissionRequired): \(l10n.s.permissionAccessibility)"
        }
        if !permissions.screenRecording {
            return "\(l10n.s.permissionRequired): \(l10n.s.permissionScreenRecording)"
        }
        return nil
    }

    private var layout: SwitcherLayout {
        if switcherSimpleMode { return .simple }
        return switcherIconRowMode ? .icons : .windows
    }

    private func choose(_ layout: SwitcherLayout) {
        switch layout {
        case .windows:
            switcherSimpleMode = false
            switcherIconRowMode = false
        case .icons:
            switcherSimpleMode = false
            switcherIconRowMode = true
        case .simple:
            switcherSimpleMode = true
        }
        AppSwitcher.shared.syncWithPreferences()
    }

    private var windowlessMode: SwitcherWindowlessApps {
        SwitcherWindowlessApps.mode(storedValue: switcherWindowlessApps)
    }

    /// The stored value keeps its three modes; the toggles are two views of
    /// it. Hiding off lists every app; hiding on lists Finder alone or none.
    private var hidesWindowlessAppsBinding: Binding<Bool> {
        Binding(
            get: { windowlessMode != .all },
            set: { switcherWindowlessApps = ($0 ? SwitcherWindowlessApps.finder : .all).rawValue }
        )
    }

    private var keepsWindowlessFinderBinding: Binding<Bool> {
        Binding(
            get: { windowlessMode == .finder },
            set: { switcherWindowlessApps = ($0 ? SwitcherWindowlessApps.finder : .off).rawValue }
        )
    }

    private var switcherAppearanceDelayBinding: Binding<Int> {
        Binding(
            get: { SwitcherSupport.sanitizedAppearanceDelay(milliseconds: switcherAppearanceDelay) },
            set: { switcherAppearanceDelay = SwitcherSupport.sanitizedAppearanceDelay(milliseconds: $0) }
        )
    }
}

/// One of the three switcher layouts, drawn as the switcher would look:
/// window previews, one large icon per app under its previews, or a plain
/// list of icons and titles.
private struct SwitcherLayoutChoice: View {
    let layout: SwitcherLayout
    let title: String
    let caption: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // The sketches stay narrow enough for three tiles to share
                // the page's standard column; a wider one pushed every card on
                // the page past the margins other pages keep.
                sketch
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .frame(height: 68)
                    .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(selected ? Color.accentColor : .primary)
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(10)
            .background(selected ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor.opacity(0.55) : .clear, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(caption)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Drawn like the switcher itself: gray selections, no accent color, and
    /// for Large icons the selected app's window under its icon.
    @ViewBuilder
    private var sketch: some View {
        switch layout {
        case .windows:
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    window(selected: index == 0)
                        .frame(width: 22, height: 16)
                        .padding(3)
                        .background(selection(index == 0, cornerRadius: 5))
                }
            }
        case .icons:
            VStack(spacing: 5) {
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { index in
                        icon(selected: index == 0)
                    }
                }
                HStack(spacing: 6) {
                    window(selected: true)
                        .frame(width: 22, height: 15)
                        .padding(2)
                        .background(selection(true, cornerRadius: 4))
                    Spacer(minLength: 0)
                }
                .frame(width: 4 * 18 + 3 * 6)
            }
        case .simple:
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { index in
                    icon(selected: index == 0)
                }
            }
        }
    }

    private func icon(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3.5, style: .continuous)
            .fill(Color.white.opacity(selected ? 0.85 : 0.4))
            .frame(width: 13, height: 13)
            .padding(2.5)
            .background(selection(selected, cornerRadius: 5))
    }

    private func selection(_ selected: Bool, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(selected ? 0.2 : 0))
    }

    private func window(selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(Color.white.opacity(selected ? 0.85 : 0.4))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.black.opacity(0.35))
                    .frame(height: 3)
                    .padding(.horizontal, 1)
                    .padding(.top, 1)
            }
    }
}

/// The three ways the switcher can look; `simple` wins over `icons` when
/// both keys are set, as the switcher itself decides.
private enum SwitcherLayout: Hashable {
    case windows, icons, simple
}

#if LATTICE_DEVELOPMENT
/// Rendering probe only: the three layout tiles as the Settings page draws them.
struct SwitcherLayoutTilesPreview: View {
    var body: some View {
        HStack(spacing: 10) {
            SwitcherLayoutChoice(layout: .windows, title: "Window previews", caption: "Live thumbnails.", selected: false) {}
            SwitcherLayoutChoice(layout: .icons, title: "Large icons", caption: "Icons, previews below.", selected: true) {}
            SwitcherLayoutChoice(layout: .simple, title: "Simple list", caption: "Icons only.", selected: false) {}
        }
        .padding(12)
    }
}
#endif
