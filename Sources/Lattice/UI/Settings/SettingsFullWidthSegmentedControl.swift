// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// A segmented control as wide as the space it is given, with equal segments.
/// SwiftUI's segmented picker on macOS keeps to its labels' width, which reads
/// as a small switch rather than the page's own sections.
struct SettingsFullWidthSegmentedControl<Value: Hashable>: NSViewRepresentable {
    let title: String
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: options.map(\.label), trackingMode: .selectOne,
                                         target: context.coordinator,
                                         action: #selector(Coordinator.selectionChanged(_:)))
        control.segmentDistribution = .fillEqually
        control.controlSize = .large
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        control.setAccessibilityLabel(title)
        if control.segmentCount != options.count { control.segmentCount = options.count }
        for (index, option) in options.enumerated() where control.label(forSegment: index) != option.label {
            control.setLabel(option.label, forSegment: index)
        }
        let selected = options.firstIndex { $0.value == selection } ?? -1
        if control.selectedSegment != selected { control.selectedSegment = selected }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSSegmentedControl, context: Context) -> CGSize? {
        let natural = nsView.intrinsicContentSize
        return CGSize(width: max(proposal.width ?? natural.width, natural.width), height: natural.height)
    }

    final class Coordinator: NSObject {
        var parent: SettingsFullWidthSegmentedControl

        init(_ parent: SettingsFullWidthSegmentedControl) { self.parent = parent }

        @MainActor @objc func selectionChanged(_ sender: NSSegmentedControl) {
            guard parent.options.indices.contains(sender.selectedSegment) else { return }
            parent.selection = parent.options[sender.selectedSegment].value
        }
    }
}
