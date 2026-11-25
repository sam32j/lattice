// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// The App Manager tile's tab, shared by the floating Hub and the Dynamic
/// Island, so either opens where the other left off.
@MainActor
final class AppManagerPanelState: ObservableObject {
    static let shared = AppManagerPanelState()
    @Published var tab: AppManagerTab = .updates
    /// Every App Manager tab in the island has this height.
    static let islandHeight: CGFloat = 240

    /// The tabs the panel offers: every module that is on, except the App
    /// Installer, which works by opening or dropping a disk image instead.
    var tabs: [AppManagerTab] {
        AppManagerTab.allCases.filter { $0 != .installer && $0.feature.isAvailable }
    }

    var shownTab: AppManagerTab {
        let available = tabs
        return available.contains(tab) ? tab : (available.first ?? .updates)
    }

}

/// The App Manager in the Hub and the island: the panel of the module the
/// tab names. The tab is chosen in the surface's own header: a menu beside
/// the island's pin, a full-width segmented control under the floating Hub's
/// title, so scrolling never hides it.
struct PanelAppManagerView: View {
    var onClose: () -> Void = {}
    var showsPicker = true
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var state = AppManagerPanelState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsPicker {
                AppManagerPanelPicker()
            }
            Group {
                switch state.shownTab {
                case .installer, .updates: PanelAppUpdatesView(showHeader: false, onClose: onClose)
                case .uninstaller: PanelUninstallerView(onClose: onClose)
                case .homebrew: PanelHomebrewView(showHeader: false, onClose: onClose)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

}

extension AppManagerTab {
    /// The tab's name without the "App" every one would repeat, for the
    /// Hub's narrow pickers.
    func shortTitle(_ strings: AppManagerStrings) -> String {
        let tab = self
        switch tab {
        case .homebrew: return strings.tabHomebrew
        default:
            let title = tab.title(strings)
            for prefix in ["App ", "Appの", "App"] where title.hasPrefix(prefix) && title.count > prefix.count + 2 {
                return String(title.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            }
            return title
        }
    }
}

/// The floating Hub's App Manager tabs: a full-width segmented control.
struct AppManagerPanelPicker: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var state = AppManagerPanelState.shared

    var body: some View {
        let strings = FeatureStrings.appManager(l10n.language)
        if state.tabs.count > 1 {
            // The same full-width control as Settings, with room under it
            // before the page.
            SettingsFullWidthSegmentedControl(
                title: strings.tabsLabel,
                options: state.tabs.map { ($0, $0.shortTitle(strings)) },
                selection: Binding(get: { state.shownTab }, set: { state.tab = $0 }),
                dot: { AppManagerAttention.shared.dot(for: $0) })
                .frame(maxWidth: .infinity)
                .padding(.bottom, 5)
        }
    }
}

/// The island's App Manager tabs: a text menu in the band beside the pin.
struct AppManagerTabMenu: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var state = AppManagerPanelState.shared

    var body: some View {
        let strings = FeatureStrings.appManager(l10n.language)
        if state.tabs.count > 1 {
            Menu {
                Picker(strings.tabsLabel, selection: Binding(get: { state.shownTab }, set: { state.tab = $0 })) {
                    ForEach(state.tabs, id: \.self) { tab in
                        Text(tab.title(strings)).tag(tab)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                // One text run, so the menu label keeps the chevron after the name.
                (Text(state.shownTab.shortTitle(strings) + " ")
                 + Text(Image(systemName: "chevron.down")).font(.system(size: 8, weight: .bold)))
                .foregroundStyle(Color.white.opacity(0.6))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .controlSize(.small)
            .accessibilityLabel(strings.tabsLabel)
            .accessibilityValue(state.shownTab.title(strings))
        }
    }
}
