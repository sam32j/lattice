// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Menu bar panel preferences, separate from General's app preferences.
struct GeneralToolSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.notchHidesMenuBarIcon) private var hideMenuIcon = false

    private var text: GeneralSettingsStrings { FeatureStrings.generalSettings(l10n.language) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsCard(title: l10n.s.menuBarSection) {
                    SettingsToggleRow(title: SettingsFollowupStrings.text(.showMenuIcon, l10n.language),
                                      isOn: Binding(get: { !hideMenuIcon }, set: { hideMenuIcon = !$0 }))
                    if !hideMenuIcon { MenuBarIconPickerRow().padding(.leading, settingsRowTextInset) }
                    Divider()
                    Text(text.panelIntro)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    PanelLayoutEditor()
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .onChange(of: hideMenuIcon) { _, _ in AppMenuDestination.reconcile(in: .standard) }
    }
}

/// A setting row with a button that presents a searchable SF Symbol picker popover.
private struct MenuBarIconPickerRow: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.menuBarIconSymbol) private var savedName = ""
    @State private var showingPicker = false
    @State private var isHovered = false

    private var text: GeneralSettingsStrings { FeatureStrings.generalSettings(l10n.language) }

    var body: some View {
        let name = Defaults.sanitizedMenuBarIconSymbol(savedName)
        SettingsControlRow(title: text.menuBarIconTitle, caption: text.menuBarIconCaption) {
            Button {
                showingPicker = true
            } label: {
                iconPreview(name: name)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(showingPicker ? Color.accentColor.opacity(0.12) : (isHovered ? Color.secondary.opacity(0.12) : Color.secondary.opacity(0.06)))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(showingPicker ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.16), lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
            .popover(isPresented: $showingPicker, arrowEdge: .bottom) {
                MenuBarIconSearchPopover(savedName: $savedName)
            }
        }
    }

    @ViewBuilder
    private func iconPreview(name: String) -> some View {
        if name.isEmpty {
            vorssaintMark
        } else if let custom = BlackHoleGlyph.customMark(named: name) {
            Image(nsImage: custom)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 18, maxHeight: 16)
        } else {
            Image(systemName: name)
                .font(.system(size: 14, weight: .semibold))
                .frame(maxWidth: 18, maxHeight: 16)
        }
    }

    private var vorssaintMark: some View {
        Group {
            if let mark = BlackHoleGlyph.mark(symbolName: "") {
                Image(nsImage: mark)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "circle.fill")
            }
        }
        .frame(maxWidth: 18, maxHeight: 16)
    }
}

/// Searchable icon picker popover for selecting menu bar icons.
private struct MenuBarIconSearchPopover: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss
    @Binding var savedName: String
    @State private var searchQuery = ""
    @FocusState private var isSearchFocused: Bool

    private static let curatedSymbols: [String] = {
        var set = Set<String>()
        var list: [String] = []
        let rawCandidates = Defaults.menuBarIconGallery + RadialMenuSupport.symbolNames + [
            "apple.logo", "shield.fill", "lock.fill", "bell.fill", "pin.fill", "link",
            "tag.fill", "bookmark.fill", "flag.fill", "pencil", "scissors", "lightbulb.fill",
            "antenna.radiowaves.left.and.right", "wifi", "display", "printer.fill"
        ]
        for name in rawCandidates {
            if set.insert(name).inserted,
               NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil {
                list.append(name)
            }
        }
        return list
    }()

    private var text: GeneralSettingsStrings { FeatureStrings.generalSettings(l10n.language) }

    private var filteredSymbols: [String] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var results = Self.curatedSymbols
        if !query.isEmpty {
            results = results.filter { $0.lowercased().contains(query) }
            // If the query itself matches a valid SF Symbol not in the curated list, add it at the top
            if !results.contains(where: { $0.caseInsensitiveCompare(query) == .orderedSame }),
               NSImage(systemSymbolName: query, accessibilityDescription: nil) != nil {
                results.insert(query, at: 0)
            }
        }
        return results
    }

    var body: some View {
        let current = Defaults.sanitizedMenuBarIconSymbol(savedName)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(text.menuBarIconTitle, text: $searchQuery, prompt: Text(text.menuBarIconSearchPlaceholder))
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )

            // Default icon choice button
            Button {
                savedName = ""
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    if let mark = BlackHoleGlyph.mark(symbolName: "") {
                        Image(nsImage: mark)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "circle.fill")
                            .frame(width: 16, height: 16)
                    }
                    Text(text.menuBarIconReset)
                        .font(.callout)
                    Spacer()
                    if current.isEmpty {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(current.isEmpty ? Color.accentColor.opacity(0.12) : Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 34), spacing: 6)], spacing: 6) {
                    ForEach(filteredSymbols, id: \.self) { symbol in
                        let selected = current == symbol
                        Button {
                            savedName = symbol
                            dismiss()
                        } label: {
                            Image(systemName: symbol)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(selected ? Color.accentColor : Color.primary)
                                .frame(width: 34, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(selected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .strokeBorder(selected ? Color.accentColor.opacity(0.75) : Color.secondary.opacity(0.13),
                                                      lineWidth: selected ? 1.2 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(symbol)
                    }
                }
                .padding(2)
            }
            .frame(maxHeight: 220)
        }
        .padding(14)
        .frame(width: 320)
        .onAppear {
            DispatchQueue.main.async { isSearchFocused = true }
        }
    }
}
