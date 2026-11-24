// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Combine
import SwiftUI

/// The App Manager's tabs, one per module, in display order.
enum AppManagerTab: String, CaseIterable, Hashable {
    case installer, updates, uninstaller, homebrew

    var feature: AppFeature {
        switch self {
        case .installer: return .diskImageInstaller
        case .updates: return .appUpdates
        case .uninstaller: return .uninstaller
        case .homebrew: return .homebrew
        }
    }

    var anchor: SettingsSectionAnchor {
        switch self {
        case .installer: return .appInstaller
        case .updates: return .appUpdates
        case .uninstaller: return .appUninstaller
        case .homebrew: return .homebrew
        }
    }

    init?(anchor: SettingsSectionAnchor?) {
        guard let tab = Self.allCases.first(where: { $0.anchor == anchor }) else { return nil }
        self = tab
    }

    init?(feature: AppFeature) {
        guard let tab = Self.allCases.first(where: { $0.feature == feature }) else { return nil }
        self = tab
    }

    func title(_ strings: AppManagerStrings) -> String {
        switch self {
        case .installer: return strings.tabInstaller
        case .updates: return strings.tabUpdates
        case .uninstaller: return strings.tabUninstaller
        case .homebrew: return strings.tabHomebrew
        }
    }

    func help(_ strings: AppManagerStrings) -> String {
        switch self {
        case .installer: return strings.helpInstaller
        case .updates: return strings.helpUpdates
        case .uninstaller: return strings.helpUninstaller
        case .homebrew: return strings.helpHomebrew
        }
    }
}

/// The App Manager's modules as one switch, like the System Monitor's: off
/// turns every module off and remembers which were on. The App Installer has
/// no switch of its own; it is on whenever the App Manager is.
@MainActor
enum AppManagerModules {
    static let all: [AppFeature] = AppManagerTab.allCases.map(\.feature)
    /// The module that is on whenever any is.
    static let locked: AppFeature = .diskImageInstaller

    static var anyOn: Bool { all.contains(where: \.isAvailable) }

    static var visibleTabs: [AppManagerTab] { AppManagerTab.allCases.filter { $0.feature.isAvailable } }

    static func setOn(_ on: Bool) {
        let defaults = UserDefaults.standard
        if on {
            let saved = Set(defaults.stringArray(forKey: DefaultsKey.appManagerModulesBeforeOff) ?? [])
            let remembered = all.filter { saved.contains($0.rawValue) && $0 != locked }
            let restore = remembered.isEmpty && saved.isEmpty ? all.filter { $0 != locked } : remembered
            setLocked(true)
            FeatureRuntime.shared.setAvailable(restore, true)
        } else {
            defaults.set(all.filter(\.isAvailable).map(\.rawValue), forKey: DefaultsKey.appManagerModulesBeforeOff)
            FeatureRuntime.shared.setAvailable(all.filter { $0 != locked }, false)
            setLocked(false)
        }
        settingsFinishAvailabilityChange()
    }

    static func setModule(_ feature: AppFeature, on: Bool) {
        guard feature != locked else { return }
        if on { setLocked(true) }
        FeatureRuntime.shared.setAvailable([feature], on)
        settingsFinishAvailabilityChange()
    }

    private static func setLocked(_ on: Bool) {
        FeatureRuntime.shared.setAvailable([locked], on)
    }
}

/// App Manager: the App Installer, App Updates, App Uninstaller and Homebrew
/// as tabs of one page. The main switch and the module switches sit in the
/// title bar; a tab shows only while its module is on.
struct AppManagerSettings: View {
    /// The tab last shown, so coming back without a deep link returns to it.
    @MainActor static var lastTab = AppManagerTab.installer

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var router = SettingsRouter.shared
    @State private var tab: AppManagerTab

    init() {
        _tab = State(initialValue: AppManagerTab(anchor: SettingsRouter.shared.destination.sectionAnchor) ?? Self.lastTab)
    }

    private var strings: AppManagerStrings { FeatureStrings.appManager(l10n.language) }

    var body: some View {
        Group {
            if AppManagerModules.anyOn {
                page
            } else {
                SettingsFeatureEmptyState(title: strings.title, symbol: LatticeSymbol.appManagerSymbol,
                                          description: strings.emptyDescription) {
                    Button(SettingsOwnershipStrings.enable(strings.title, l10n.language)) {
                        AppManagerModules.setOn(true)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .toolbar {
            SettingsTitleBarItem(id: "app-manager-activation") { AppManagerTitleBarControls() }
        }
        .settingsExpansionAnimation(value: AppManagerModules.anyOn)
        .settingsExpansionAnimation(value: AppManagerModules.all.map(\.isAvailable))
        .onChange(of: router.requestID) { _, _ in
            // A deep link names a tab; show it.
            guard router.page == .appManager,
                  let requested = AppManagerTab(anchor: router.destination.sectionAnchor) else { return }
            tab = requested
        }
        .onChange(of: tab, initial: true) { _, newTab in Self.lastTab = newTab }
    }

    /// The tab on screen: the chosen one while its module is on, otherwise
    /// the first module that is.
    private var shownTab: AppManagerTab {
        let visible = AppManagerModules.visibleTabs
        return visible.contains(tab) ? tab : (visible.first ?? .installer)
    }

    private var page: some View {
        let visible = AppManagerModules.visibleTabs
        return VStack(spacing: 0) {
            if visible.count > 1 {
                AppManagerTabBar(tabs: visible, selection: Binding(get: { shownTab }, set: { tab = $0 }),
                                 strings: strings)
                    .frame(maxWidth: 760)
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
                    .transition(.opacity)
            }
            ZStack(alignment: .top) {
                switch shownTab {
                case .installer: AppInstallerTab().transition(.opacity)
                case .updates: AppUpdatesSettings().transition(.opacity)
                case .uninstaller: AppUninstallerTab().transition(.opacity)
                case .homebrew: HomebrewTab().transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .animation(.easeInOut(duration: 0.18), value: shownTab)
    }
}

/// The page's tabs: a full-width segmented control whose segments carry a dot
/// when their module wants attention (an update, a disk image waiting).
struct AppManagerTabBar: View {
    let tabs: [AppManagerTab]
    @Binding var selection: AppManagerTab
    let strings: AppManagerStrings
    @ObservedObject private var attention = AppManagerAttention.shared
    @Namespace private var thumb
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    HStack(spacing: 5) {
                        Text(tab.title(strings))
                            .lineLimit(1)
                        if let dot = attention.dot(for: tab) {
                            Circle().fill(dot).frame(width: 6, height: 6)
                        }
                    }
                    .font(.system(size: 12, weight: selection == tab ? .semibold : .regular))
                    .foregroundStyle(selection == tab ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
                                .matchedGeometryEffect(id: "thumb", in: thumb)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .accessibilityAddTraits(selection == tab ? [.isSelected] : [])
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .animation(reduceMotion ? nil : .spring(duration: 0.25, bounce: 0.1), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(strings.tabsLabel)
    }
}

/// What each tab's dot reports: a disk image waiting to install, app
/// updates found, Homebrew packages out of date.
@MainActor
final class AppManagerAttention: ObservableObject {
    static let shared = AppManagerAttention()
    @Published var diskImageWaiting = false
    private var subscriptions: Set<AnyCancellable> = []

    private init() {
        // The tabs redraw when either service's findings change.
        AppUpdatesService.shared.$items.map { _ in () }
            .merge(with: HomebrewManager.shared.$outdatedPackagesByID.map { _ in () })
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &subscriptions)
    }

    func dot(for tab: AppManagerTab) -> Color? {
        switch tab {
        case .installer: return diskImageWaiting ? .accentColor : nil
        case .updates: return AppUpdatesService.shared.items.isEmpty ? nil : .accentColor
        case .uninstaller: return nil
        case .homebrew: return HomebrewManager.shared.outdatedPackagesByID.isEmpty ? nil : .orange
        }
    }
}

/// The module menu and the main switch, laid out like the other pages'
/// title bar controls.
private struct AppManagerTitleBarControls: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @State private var showingMenu = false
    @State private var menuClosedAt = Date.distantPast

    var body: some View {
        let isOn = AppManagerModules.anyOn
        let title = FeatureStrings.appManager(l10n.language).title
        HStack(spacing: 6) {
            if isOn { menuButton }
            SettingsTitleBarSwitch(title: title, isOn: isOn) { AppManagerModules.setOn($0) }
        }
        .padding(.horizontal, 8)
        .onChange(of: isOn) { _, on in
            if !on { showingMenu = false }
        }
    }

    private var menuButton: some View {
        let label = FeatureStrings.recorder(l10n.language).moreOptions
        return Button {
            guard Date().timeIntervalSince(menuClosedAt) > 0.3 else { return }
            showingMenu.toggle()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .foregroundStyle(showingMenu ? Color.accentColor : Color.primary)
        }
        .buttonStyle(FlatSettingsOptionsButtonStyle())
        .focusEffectDisabled()
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(showingMenu ? .isSelected : [])
        .popover(isPresented: $showingMenu, arrowEdge: .bottom) { AppManagerModulesMenu() }
        .onChange(of: showingMenu) { _, open in
            if !open { menuClosedAt = Date() }
        }
    }
}

/// One switch per module, each with its line of help; the App Installer's is
/// fixed on.
private struct AppManagerModulesMenu: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared

    var body: some View {
        let strings = FeatureStrings.appManager(l10n.language)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(AppManagerTab.allCases, id: \.self) { tab in
                let locked = tab.feature == AppManagerModules.locked
                SettingsMenuToggleRow(title: tab.title(strings), help: tab.help(strings),
                                      lockedLabel: locked ? strings.alwaysOn : nil,
                                      isOn: Binding(get: { tab.feature.isAvailable },
                                                    set: { AppManagerModules.setModule(tab.feature, on: $0) }))
            }
        }
        .padding(6)
        .frame(width: 320)
    }
}
