// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// The Dynamic Island presentation for Text Snippets: grouped by folder,
/// filterable via search, navigable with arrow keys, and insertable via Return,
/// click, or ⌘1–9 position shortcuts.
struct NotchSnippetsView: View {
    @ObservedObject var service: NotchService
    let size: CGSize
    @ObservedObject private var library = SnippetLibraryService.shared
    @ObservedObject private var l10n = L10n.shared
    @FocusState private var searching: Bool
    @State private var searchOpen = false
    @State private var highlightedID: UUID?
    @State private var copiedID: UUID?
    @Environment(\.notchSettingsPreview) private var preview
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var text: SnippetFeatureStrings { FeatureStrings.snippets(l10n.language) }

    var body: some View {
        VStack(spacing: searchOpen ? NotchLayout.rowSpacing : 0) {
            searchField
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .notchBand(leading: {
            if !searchOpen {
                NotchIconButton(symbol: "magnifyingglass", title: text.librarySearchPlaceholder) { openSearch() }
            }
        }, trailing: {
            NotchIconButton(symbol: "gearshape", title: text.manageButton) { openSnippetSettings() }
        })
        .background {
            if !preview {
                SnippetKeyMonitor(handleKey: handleKey, composed: { searchOpen = true })
                    .frame(width: 0, height: 0)
            }
        }
        .onAppear(perform: appeared)
        .onChange(of: searchOpen) { _, open in
            guard !preview else { return }
            service.setPageLayer(.snippets, close: open ? { closeSearch() } : nil)
        }
        .onChange(of: searching) { _, focused in
            if !focused, library.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchOpen = false
            }
        }
        .onChange(of: library.rows.map(\.id)) { _, rows in
            if let highlighted = highlightedID, !rows.contains(highlighted) {
                highlightedID = rows.first
            } else if highlightedID == nil {
                highlightedID = rows.first
            }
        }
        .onDisappear {
            if !preview { service.setPageLayer(.snippets, close: nil) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !library.hasLibraryContent {
            NotchEmptyView(symbol: "text.badge.plus", message: text.libraryEmpty) {
                Button(text.manageButton) { openSnippetSettings() }
                    .buttonStyle(.bordered).controlSize(.small)
            }
            .frame(maxHeight: .infinity)
        } else if library.rows.isEmpty {
            NotchEmptyView(symbol: "magnifyingglass", message: text.libraryNoResults)
                .frame(maxHeight: .infinity)
        } else {
            listView
        }
    }

    private var listView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(library.sections.enumerated()), id: \.element.folder) { index, section in
                        if !section.folder.isEmpty {
                            folderHeader(section.folder, topPadding: index == 0 ? 2 : 8)
                        }
                        ForEach(section.snippets) { snippet in
                            snippetRow(snippet)
                                .id(snippet.id)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            .scrollIndicators(.automatic)
            .onChange(of: highlightedID) { _, id in
                guard let id else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                    proxy.scrollTo(id)
                }
            }
        }
    }

    private func folderHeader(_ name: String, topPadding: CGFloat) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "folder").font(.system(size: 10, weight: .semibold))
            Text(name).font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.55))
        .padding(.horizontal, 10).padding(.top, topPadding).padding(.bottom, 2)
    }

    private func snippetRow(_ snippet: TextSnippet) -> some View {
        let isHighlighted = highlightedID == snippet.id
        let rowIndex = library.rows.firstIndex(where: { $0.id == snippet.id })
        return Button {
            library.insert(snippet)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(snippet.name.isEmpty ? snippet.trigger : snippet.name)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.white).lineLimit(1)
                        if !snippet.trigger.isEmpty {
                            Text(snippet.trigger)
                                .font(.system(size: 10, design: .monospaced))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(.white.opacity(isHighlighted ? 0.18 : 0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    Text(previewText(of: snippet))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(isHighlighted ? 0.7 : 0.45))
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    copyButton(snippet)
                    if let rowIndex, rowIndex < 9 {
                        Text("⌘\(rowIndex + 1)")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(isHighlighted ? 0.75 : 0.35))
                    } else if isHighlighted {
                        Image(systemName: "return")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .modifier(NotchControlSurface(cornerRadius: 10, selected: isHighlighted))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(isHighlighted ? 0.3 : 0), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { inside in if inside { highlightedID = snippet.id } }
    }

    private func copyButton(_ snippet: TextSnippet) -> some View {
        Button {
            copyExpansion(of: snippet)
        } label: {
            Image(systemName: copiedID == snippet.id ? "checkmark" : "doc.on.doc")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(copiedID == snippet.id ? Color.green : .white.opacity(0.5))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(copiedID == snippet.id ? "Copied" : "Copy expansion")
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(text.librarySearchPlaceholder, text: $library.query)
                .textFieldStyle(.plain).font(.system(size: 12)).focused($searching)
            if !library.query.isEmpty {
                Button { library.query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12).frame(height: NotchLayout.clipboardSearchHeight)
        .modifier(NotchControlSurface(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(searching ? 0.34 : 0), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.15), value: searching)
        .frame(height: searchOpen ? NotchLayout.clipboardSearchHeight : 0, alignment: .top)
        .opacity(searchOpen ? 1 : 0)
        .clipped()
        .allowsHitTesting(searchOpen)
        .accessibilityHidden(!searchOpen)
    }

    private func previewText(of snippet: TextSnippet) -> String {
        snippet.replacement.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
    }

    private func openSearch() { searchOpen = true; searching = true }
    private func closeSearch() { library.query = ""; searchOpen = false; searching = true }

    private func appeared() {
        guard !preview else { return }
        library.reloadSnippets()
        highlightedID = library.rows.first?.id
        searching = true
    }

    private func openSnippetSettings() {
        service.collapse()
        SettingsRouter.shared.page = .textSnippets
        (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
    }

    private func copyExpansion(of snippet: TextSnippet) {
        let clipboard = TextSnippetSupport.needsClipboard(snippet.replacement)
            ? NSPasteboard.general.string(forType: .string) : nil
        let expanded = TextSnippetSupport.expand(snippet.replacement, date: Date(), clipboard: clipboard)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(expanded, forType: .string)
        withAnimation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.7)) {
            copiedID = snippet.id
        }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            if copiedID == snippet.id { await MainActor.run { copiedID = nil } }
        }
    }

    private func handleKey(keyCode: UInt16, characters: String, modifiers: NSEvent.ModifierFlags,
                           composing: Bool, editing: Bool) -> Bool {
        if modifiers.contains(.command), let index = SnippetLibraryService.digitIndex(for: keyCode) {
            let rows = library.rows
            if rows.indices.contains(index) { library.insert(rows[index]); return true }
        }
        if !modifiers.isDisjoint(with: [.command, .control, .option]) || composing { return false }
        switch Int(keyCode) {
        case kVK_UpArrow: moveHighlight(by: -1); return true
        case kVK_DownArrow: moveHighlight(by: 1); return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if let snippet = library.rows.first(where: { $0.id == highlightedID }) {
                library.insert(snippet)
                return true
            }
            return false
        default:
            let typed = !characters.isEmpty && !characters.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && characters.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) && !(0xF700...0xF8FF).contains($0.value) }
            if typed && !searchOpen { searchOpen = true }
            return false
        }
    }

    private func moveHighlight(by offset: Int) {
        let rows = library.rows
        guard !rows.isEmpty else { return }
        let current = rows.firstIndex { $0.id == highlightedID } ?? 0
        let next = min(max(current + offset, 0), rows.count - 1)
        highlightedID = rows[next].id
    }
}
