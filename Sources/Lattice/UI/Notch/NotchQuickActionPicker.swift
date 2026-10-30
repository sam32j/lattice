// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct NotchQuickActionPicker: View {
    var selected: NotchQuickAction?
    let onSelect: (NotchQuickAction) -> Void

    @ObservedObject private var l10n = L10n.shared
    @State private var query = ""
    @FocusState private var isSearching: Bool

    private var editor: NotchEditorStrings { FeatureStrings.notchEditor(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            searchBar

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if !NotchQuickAction.optionalActions.contains(where: matchesQuery) {
                        Text(FeatureStrings.clipboard(l10n.language).noResults)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                    }

                    actionSection(
                        title: editor.sectionActions,
                        actions: [.explore, .settings] + NotchModule.allCases.map(NotchQuickAction.module)
                    )

                    actionSection(
                        title: editor.quickActions,
                        actions: [.pin] + NotchControlItem.allCases.filter { !$0.isLevel }.map(NotchQuickAction.control)
                    )
                }
                .padding(.horizontal, 1)
            }
            .frame(maxHeight: 240)
        }
        .padding(14)
        .frame(width: 320)
        .onAppear { isSearching = true }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(editor.findAction, text: $query)
                .textFieldStyle(.plain)
                .focused($isSearching)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func actionSection(title: String, actions: [NotchQuickAction]) -> some View {
        let matches = actions.filter(matchesQuery)
        if !matches.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 2)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                    ForEach(matches) { action in
                        Button {
                            onSelect(action)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: action.symbol)
                                    .font(.system(size: 12, weight: .medium))
                                    .frame(width: 16)
                                Text(action.title(l10n))
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 8)
                            .background(
                                selected == action ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func matchesQuery(_ action: NotchQuickAction) -> Bool {
        guard action.isAvailable() else { return false }
        let term = CommandBarSearch.normalized(query)
        return term.isEmpty || CommandBarSearch.normalized(action.title(l10n) + " " + action.id).contains(term)
    }
}
