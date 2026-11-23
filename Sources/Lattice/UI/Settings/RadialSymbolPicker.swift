// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// The icon an action shows: a picked symbol, a fetched website icon, the
/// real app or file icon, or the action's own symbol.
struct RadialIconPreview: View {
    let item: RadialMenuItem
    var size: CGFloat = 18

    var body: some View {
        if !item.symbolName.isEmpty {
            Image(systemName: item.symbolName)
                .font(.system(size: size * 0.8, weight: .semibold))
        } else if let custom = RadialMenuIconStore.customIcon(for: item) {
            Image(nsImage: custom).resizable().interpolation(.high).frame(width: size, height: size)
        } else if item.usesFileIcon, !item.payload.isEmpty {
            Image(nsImage: RadialMenuIconStore.fileIcon(for: item.payload))
                .resizable().interpolation(.high).frame(width: size + 2, height: size + 2)
        } else {
            Image(systemName: item.defaultSymbolName)
                .font(.system(size: size * 0.8, weight: .semibold))
        }
    }
}

/// The icon chooser, shaped like the menu bar icon chooser: search, the
/// automatic icon, then icons suggested for this kind of action, then all.
struct RadialIconChooser: View {
    let text: RadialMenuFeatureStrings
    @Binding var item: RadialMenuItem
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private static func exists(_ name: String) -> Bool {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }

    private var suggested: [String] {
        RadialIconChooser.suggestions(for: item).filter(Self.exists)
    }

    /// Symbols that fit the kind of action, its own default first.
    static func suggestions(for item: RadialMenuItem) -> [String] {
        let byKind: [String]
        switch item.kind {
        case .app: byKind = ["star.fill", "heart.fill", "bolt.fill", "sparkles", "terminal.fill", "globe", "hammer.fill"]
        case .file: byKind = ["folder.fill", "doc.fill", "tray.full.fill", "archivebox.fill", "paperclip", "externaldrive.fill"]
        case .url: byKind = ["globe", "link", "bookmark.fill", "safari", "envelope.fill", "cart.fill", "book.fill"]
        case .shortcut: byKind = ["command", "keyboard", "bolt.fill", "switch.2", "slider.horizontal.3", "textformat"]
        case .tool: byKind = RadialMenuTool.allCases.map(\.symbolName) + ["wrench.and.screwdriver"]
        case .quickToggle: byKind = RadialMenuQuickToggle.allCases.map(\.symbolName)
        case .windowLayout: byKind = WindowLayoutAction.allCases.prefix(8).map(\.symbolName)
        case .media: byKind = ["play.fill", "pause.fill", "forward.fill", "backward.fill", "music.note",
                               "headphones", "speaker.wave.2.fill", "waveform"]
        case .submenu: byKind = ["ellipsis.circle", "folder.fill", "square.grid.2x2", "list.bullet", "star.fill"]
        }
        var seen = Set<String>()
        return ([item.defaultSymbolName] + byKind).filter { seen.insert($0).inserted }
    }

    private var others: [String] {
        let taken = Set(suggested)
        return RadialMenuSupport.symbolNames.filter { !taken.contains($0) && Self.exists($0) }
    }

    private func matching(_ names: [String]) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return names }
        return names.filter { $0.lowercased().contains(trimmed) }
    }

    var body: some View {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var all = matching(others)
        if !search.isEmpty, Self.exists(search), !suggested.contains(search), !all.contains(search) {
            all.insert(search, at: 0)
        }
        let suggestions = matching(suggested)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(text.iconLabel, text: $query,
                          prompt: Text(FeatureStrings.generalSettings(l10n.language).menuBarIconSearchPlaceholder))
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.secondary.opacity(0.08)))

            Button {
                item.symbolName = ""
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    RadialIconPreview(item: { var copy = item; copy.symbolName = ""; return copy }(), size: 16)
                        .frame(width: 18, height: 18)
                    Text(text.automaticLabel).font(.callout)
                    Spacer()
                    if item.symbolName.isEmpty {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(item.symbolName.isEmpty ? Color.accentColor.opacity(0.12) : Color.clear))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if !suggestions.isEmpty {
                        section(text.iconSuggested, suggestions)
                    }
                    if !all.isEmpty {
                        section(text.iconAll, all)
                    }
                }
                .padding(2)
            }
            .frame(maxHeight: 260)
        }
        .padding(14)
        .frame(width: 320)
        .onAppear { DispatchQueue.main.async { searchFocused = true } }
    }

    private func section(_ title: String, _ names: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 34), spacing: 6)], spacing: 6) {
                ForEach(names, id: \.self) { symbol in
                    let selected = item.symbolName == symbol
                    Button {
                        item.symbolName = symbol
                        dismiss()
                    } label: {
                        Image(systemName: symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selected ? Color.accentColor : Color.primary)
                            .frame(width: 34, height: 32)
                            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(selected ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.06)))
                            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(selected ? Color.accentColor.opacity(0.75) : Color.secondary.opacity(0.13),
                                              lineWidth: selected ? 1.2 : 1))
                    }
                    .buttonStyle(.plain)
                    .help(symbol)
                    .accessibilityLabel(symbol)
                    .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }
}
