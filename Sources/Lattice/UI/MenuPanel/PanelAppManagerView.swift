// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// The App Manager tile's tab, shared by the floating Hub and the Dynamic
/// Island, so either opens where the other left off and both size to it.
@MainActor
final class AppManagerPanelState: ObservableObject {
    static let shared = AppManagerPanelState()
    @Published var tab: AppManagerTab = .updates

    /// The tabs the panel offers: every module that is on.
    var tabs: [AppManagerTab] { AppManagerTab.allCases.filter { $0.feature.isAvailable } }

    var shownTab: AppManagerTab {
        let available = tabs
        return available.contains(tab) ? tab : (available.first ?? .installer)
    }

    /// The height the island gives the panel: App Updates sizes to its list,
    /// the others take the utility's usual height.
    var contentHeight: CGFloat? {
        let bar: CGFloat = tabs.count > 1 ? 34 : 0
        switch shownTab {
        case .updates:
            return AppUpdatesListView.compactUtilityHeight(itemCount: AppUpdatesService.shared.items.count) + bar
        case .installer:
            return 210 + bar
        case .uninstaller, .homebrew:
            return nil
        }
    }
}

/// The App Manager in the Hub and the island: a compact tab picker over the
/// panel of the module it names.
struct PanelAppManagerView: View {
    var onClose: () -> Void = {}
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var state = AppManagerPanelState.shared
    @ObservedObject private var attention = AppManagerAttention.shared

    var body: some View {
        let strings = FeatureStrings.appManager(l10n.language)
        VStack(alignment: .leading, spacing: 8) {
            if state.tabs.count > 1 {
                Picker(strings.tabsLabel, selection: Binding(get: { state.shownTab }, set: { state.tab = $0 })) {
                    ForEach(state.tabs, id: \.self) { tab in
                        Text(shortTitle(tab, strings)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
            }
            Group {
                switch state.shownTab {
                case .installer: PanelAppInstallerView()
                case .updates: PanelAppUpdatesView(showHeader: false, onClose: onClose)
                case .uninstaller: PanelUninstallerView(showHeader: false, onClose: onClose)
                case .homebrew: PanelHomebrewView(showHeader: false, onClose: onClose)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            // A disk image waiting to install is what the tile is opened for.
            if attention.diskImageWaiting || DiskImageInstallerService.shared.detected != nil {
                state.tab = .installer
            }
        }
    }

    /// The segment names without the "App" every one would repeat.
    private func shortTitle(_ tab: AppManagerTab, _ strings: AppManagerStrings) -> String {
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

/// The App Installer in the Hub and the island: the disk image waiting with
/// Install and Skip, or the recent installs while none is.
struct PanelAppInstallerView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var installer = DiskImageInstallerService.shared
    @Environment(\.notchPresentation) private var inNotch

    private var strings: AppInstallerTabStrings { FeatureStrings.appInstallerTab(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let image = installer.detected {
                HStack(spacing: 10) {
                    AppManagerAppIcon(path: image.appPath, name: image.displayName, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(image.displayName).font(.system(size: 12.5, weight: .semibold))
                        Group {
                            if case let .installing(step) = image.phase {
                                ProgressView(value: step.progress).progressViewStyle(.linear)
                            } else if let accepted = image.gatekeeperAccepted {
                                Text(accepted ? strings.gatekeeperVerified : strings.gatekeeperUnverified)
                                    .foregroundStyle(accepted ? Color.green : Color.orange)
                            } else {
                                Text(image.imageFileName).foregroundStyle(.secondary)
                            }
                        }
                        .font(.system(size: 10.5))
                    }
                    Spacer(minLength: 6)
                    if image.phase == .waiting {
                        Button(strings.skip) { installer.skipDetected() }
                            .controlSize(.small)
                        Button(FeatureStrings.diskImageInstaller(l10n.language).installButton) {
                            installer.installDetected()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
                .padding(10)
                .background(Color.accentColor.opacity(inNotch ? 0.18 : 0.08),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "externaldrive.badge.plus").foregroundStyle(.secondary)
                    Text(strings.watchingTitle).font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
            }
            if !installer.recentInstalls.isEmpty {
                Text(strings.recentTitle)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                ForEach(installer.recentInstalls.prefix(3)) { install in
                    Button {
                        installer.reveal(install)
                    } label: {
                        HStack(spacing: 8) {
                            AppManagerAppIcon(path: install.destinationPath, name: install.name, size: 22)
                            Text(install.name).font(.system(size: 12))
                            Spacer()
                            Text(AppManagerFormat.relative(install.date, language: l10n.language))
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(strings.reveal)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
