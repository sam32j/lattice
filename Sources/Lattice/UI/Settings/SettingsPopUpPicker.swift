// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// A menu picker whose items can be greyed out one by one. SwiftUI's menu
/// picker drops `.disabled` on its items, so an option that exists but is
/// taken stayed choosable; this is the same pop-up button underneath, with
/// item validation turned off so each item keeps the state given here.
struct SettingsPopUpPicker<Value: Hashable>: NSViewRepresentable {
    struct Option: Equatable {
        let value: Value
        let title: String
        var isEnabled = true
    }

    let title: String
    let options: [Option]
    @Binding var selection: Value

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.autoenablesItems = false
        button.target = context.coordinator
        button.action = #selector(Coordinator.choose(_:))
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    func updateNSView(_ button: NSPopUpButton, context: Context) {
        context.coordinator.parent = self
        button.setAccessibilityLabel(title)
        if context.coordinator.shownOptions != options {
            context.coordinator.shownOptions = options
            button.removeAllItems()
            for option in options {
                button.addItem(withTitle: option.title)
                button.lastItem?.isEnabled = option.isEnabled
            }
        }
        if let index = options.firstIndex(where: { $0.value == selection }),
           button.indexOfSelectedItem != index {
            button.selectItem(at: index)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSPopUpButton, context: Context) -> CGSize? {
        // Fills a width the caller fixes with `.frame(width:)`, never less
        // than its own longest title.
        let natural = nsView.intrinsicContentSize
        guard let width = proposal.width, width.isFinite else { return natural }
        return CGSize(width: max(width, natural.width), height: natural.height)
    }

    @MainActor
    final class Coordinator: NSObject {
        var parent: SettingsPopUpPicker
        var shownOptions: [Option] = []

        init(_ parent: SettingsPopUpPicker) { self.parent = parent }

        @objc func choose(_ sender: NSPopUpButton) {
            let index = sender.indexOfSelectedItem
            guard parent.options.indices.contains(index), parent.options[index].isEnabled else { return }
            parent.selection = parent.options[index].value
        }
    }
}
