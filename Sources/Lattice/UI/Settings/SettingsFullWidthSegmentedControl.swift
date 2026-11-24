// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// A segmented control as wide as the space it is given, with equal segments.
/// SwiftUI's segmented picker on macOS keeps to its labels' width, which reads
/// as a small switch rather than the page's own sections.
///
/// One thumb stays on screen and slides to the selected segment's place, so a
/// new choice made mid-slide carries on from where the thumb is, in either
/// direction.
struct SettingsFullWidthSegmentedControl<Value: Hashable>: View {
    let title: String
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    /// A dot after a segment's label, for a section that wants attention.
    var dot: (Value) -> Color? = { _ in nil }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedIndex: Int {
        options.firstIndex { $0.value == selection } ?? 0
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                segment(options[index])
            }
        }
        .background(alignment: .leading) {
            GeometryReader { proxy in
                let width = proxy.size.width / CGFloat(max(options.count, 1))
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
                    .frame(width: width)
                    .offset(x: width * CGFloat(selectedIndex))
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.1), value: selectedIndex)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private func segment(_ option: (value: Value, label: String)) -> some View {
        let selected = option.value == selection
        return Button {
            selection = option.value
        } label: {
            HStack(spacing: 5) {
                Text(option.label)
                    .lineLimit(1)
                if let color = dot(option.value) {
                    Circle().fill(color).frame(width: 6, height: 6)
                }
            }
            .font(.system(size: 12, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
