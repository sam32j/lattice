// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The Audio priority disclosure shown inside the shared audio device card.
/// Contains independent Output and Microphone priority subsections. Each one
/// is a complete ordered list of discovered devices, and its position is the
/// priority used by automatic selection.
struct AudioPriorityDisclosure: View {
    @ObservedObject private var l10n = L10n.shared
    private let showsHeader: Bool
    @State private var expanded: Bool

    init(initiallyExpanded: Bool = false, showsHeader: Bool = true) {
        self.showsHeader = showsHeader
        _expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsHeader {
                Button {
                    expanded.toggle()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "list.number")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(l10n.s.audioPrioritySection)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(l10n.s.audioPriorityCaption)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    AudioOutputPriorityControls()
                    Divider()
                    AudioInputPriorityControls()
                }
                .padding(.leading, showsHeader ? 19 : 0)
            }
        }
    }

}

struct AudioPrioritySection: View {
    @ObservedObject private var l10n = L10n.shared
    var collapsible = true

    var body: some View {
        PanelSection(.mixer, title: l10n.s.audioPrioritySection, collapsible: collapsible) {
            AudioPriorityDisclosure(initiallyExpanded: true, showsHeader: false)
                .panelCard()
        }
    }
}
