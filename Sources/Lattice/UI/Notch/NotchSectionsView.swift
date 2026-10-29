// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// An in-place destination gallery. It only observes navigation, never the
/// contents or services of the sections represented by its buttons.
///
/// Rows step in whole, so the grid always rests on a row boundary; a dot per
/// resting position shows where it is and that more rows follow. Rows that
/// have stepped away keep their place for the motion but take no clicks.
struct NotchSectionsView: View {
    @ObservedObject var service: NotchService
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var text: NotchStrings { FeatureStrings.notch(l10n.language) }
    private var sections: [NotchModule] { service.filteredSections }
    private static let pitch = NotchLayout.sectionTileHeight + NotchLayout.sectionSpacing

    var body: some View {
        Group {
            if sections.isEmpty {
                NotchEmptyView(symbol: "magnifyingglass", message: FeatureStrings.clipboard(l10n.language).noResults)
            } else {
                gallery
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: sections) { _, visible in
            if !visible.contains(where: { $0 == service.highlightedSection }) {
                service.highlightedSection = visible.first
            }
        }
    }

    private var gallery: some View {
        let columns = service.geometry.sectionColumns
        let rows = NotchSectionPaging.rows(count: sections.count, columns: columns)
        let visible = service.geometry.sectionRows(count: sections.count)
        let positions = NotchSectionPaging.positions(rows: rows, visible: visible)
        let first = NotchSectionPaging.clamped(service.sectionRow, rows: rows, visible: visible)
        let shown = first..<(first + visible)
        return HStack(spacing: 0) {
            VStack(spacing: NotchLayout.sectionSpacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: NotchLayout.sectionSpacing) {
                        ForEach(0..<columns, id: \.self) { column in
                            let index = row * columns + column
                            if index < sections.count {
                                tile(sections[index], visible: shown.contains(row))
                            } else {
                                Color.clear.frame(maxWidth: .infinity).frame(height: NotchLayout.sectionTileHeight)
                            }
                        }
                    }
                    .allowsHitTesting(shown.contains(row))
                    .accessibilityHidden(!shown.contains(row))
                }
            }
            .offset(y: -CGFloat(first) * Self.pitch)
            .frame(height: NotchLayout.railHeight(rows: visible, rowHeight: NotchLayout.sectionTileHeight,
                                                  spacing: NotchLayout.sectionSpacing), alignment: .top)
            .clipped()
            .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0), value: first)
            .accessibilityScrollAction { edge in
                if edge == .bottom { service.scrollSections(by: 1) }
                else if edge == .top { service.scrollSections(by: -1) }
            }
            indicator(positions: positions, current: first)
                .frame(width: NotchLayout.sectionIndicatorWidth, alignment: .trailing)
        }
        .accessibilityHint(text.sectionKeyboardHint)
    }

    /// One dot per resting position, the current one lit. Clicking a dot
    /// rests the gallery there; the wheel and the arrow keys step rows. The
    /// column keeps its width when everything fits, so tiles never shift.
    @ViewBuilder private func indicator(positions: Int, current: Int) -> some View {
        if positions > 1 {
            VStack(spacing: 5) {
                ForEach(0..<positions, id: \.self) { position in
                    Button { service.showSectionRow(position) } label: {
                        Circle()
                            .fill(.white.opacity(position == current ? 0.9 : contrast == .increased ? 0.5 : 0.28))
                            .frame(width: 6, height: 6)
                            .frame(width: 12, height: 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: current)
            .accessibilityHidden(true)
        } else {
            Color.clear
        }
    }

    private func tile(_ module: NotchModule, visible: Bool) -> some View {
        let highlighted = service.highlightedSection == module
        let current = service.selected == module
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return Button { service.select(module) } label: {
            VStack(spacing: 8) {
                Image(systemName: module.symbol)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(tint(for: module))
                    .frame(width: 28, height: 28)
                Text(module.title(l10n.language))
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                    .frame(height: 27)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .frame(height: NotchLayout.sectionTileHeight)
            .background(.white.opacity(highlighted ? 0.12 : 0.045), in: shape)
            .overlay {
                shape.strokeBorder(.white.opacity(highlighted ? 0.55 : contrast == .increased ? 0.4 : 0.04), lineWidth: 1)
            }
            .overlay(alignment: .topTrailing) {
                if current {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(7)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 16, lifts: false))
        .accessibilityLabel(module.title(l10n.language))
        .accessibilityAddTraits(current ? .isSelected : [])
        .accessibilityIdentifier("notch.module.\(module.rawValue)")
        // A stepped-away row sits under the header, clipped; it keeps no
        // tooltip there.
        .help(visible ? module.title(l10n.language) : "")
    }

    private func tint(for module: NotchModule) -> Color {
        switch module {
        case .music: return .pink
        case .calendar: return .red
        case .timer: return .orange
        default: return .white.opacity(0.85)
        }
    }
}
