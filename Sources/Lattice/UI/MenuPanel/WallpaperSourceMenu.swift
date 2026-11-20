// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// Picks which wallpapers the gallery shows, and leads to the folder list in
/// Settings. The island holds it in its band; the HUD in the page's corner.
struct WallpaperSourceMenu: View {
    enum Surface { case island, hud }

    /// Text in the island's band; a contained pop-up in the HUD.
    let surface: Surface
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = WallpaperService.shared

    private var text: WallpaperFeatureStrings { FeatureStrings.wallpaper(l10n.language) }

    private static let order: [WallpaperSupport.Filter] = [.all, .apple, .own]

    private func title(_ filter: WallpaperSupport.Filter) -> String {
        switch filter {
        case .all: return text.filterAll
        case .apple: return text.filterApple
        case .own: return text.filterOwn
        }
    }

    private var selectorWidth: CGFloat {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .small))
        let widest = Self.order
            .map { (title($0) as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        // the bezel's insets and its up-down chevrons
        return ceil(widest) + 34
    }

    /// The pop-up's rows: the three sources, then the way to Settings,
    /// which runs instead of becoming the selection.
    private static let manageTag = "manage"

    private var selection: Binding<String> {
        Binding(get: { service.filter.rawValue }, set: { newValue in
            if newValue == Self.manageTag {
                Self.openManagement()
                return
            }
            guard let filter = WallpaperSupport.Filter(rawValue: newValue),
                  filter != service.filter else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { service.setFilter(filter) }
        })
    }

    var body: some View {
        switch surface {
        case .island: islandMenu
        case .hud: hudPicker
        }
    }

    /// Text in the island's band, as its other band menus are.
    private var islandMenu: some View {
        Menu {
            Picker(text.sourceMenu, selection: selection) {
                ForEach(Self.order) { filter in
                    Text(title(filter)).tag(filter.rawValue)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            Divider()
            Button(text.manageWallpapers) { Self.openManagement() }
        } label: {
            // One text run, so the menu label keeps the chevron after the name.
            (Text(title(service.filter) + " ")
             + Text(Image(systemName: "chevron.down")).font(.system(size: 8, weight: .bold)))
            .foregroundStyle(Color.white.opacity(0.6))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .font(.system(size: 11, weight: .semibold))
        .accessibilityLabel(text.sourceMenu)
        .accessibilityValue(title(service.filter))
    }

    private var hudPicker: some View {
        // The same contained pop-up as the Device Controls output pickers,
        // which open from both the HUD and the island.
        Picker(text.sourceMenu, selection: selection) {
            ForEach(Self.order) { filter in
                Text(title(filter)).tag(filter.rawValue)
            }
            Divider()
            Text(text.manageWallpapers).tag(Self.manageTag)
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .controlSize(.small)
        // A pop-up sizes itself to its longest row, but "Manage Wallpapers…"
        // is an action and never shows closed: fit the three sources only.
        .frame(width: selectorWidth)
        .accessibilityLabel(text.sourceMenu)
        .accessibilityValue(title(service.filter))
    }

    /// Closes the island or HUD, pinned or not, and shows the folder list.
    static func openManagement() {
        let notch = NotchService.shared
        let hub = LatticeHubService.shared
        if notch.expanded, notch.selected == .hub {
            notch.collapse()
            hub.isPinned = false
        } else {
            hub.hide()
        }
        SettingsRouter.shared.request(FeatureSettingsDestination(.energy, sectionAnchor: .wallpaper))
        (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
    }
}
