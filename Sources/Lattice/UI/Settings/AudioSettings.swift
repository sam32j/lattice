// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Audio settings: one page with Input and Output segments. The segmented
/// control heads the page and scrolls with it; below it, each segment shows
/// the Audio Input or Audio Output cards, permission handling included.
struct AudioSettings: View {
    /// The segment last shown, so coming back to Audio without a deep link
    /// returns to it rather than resetting to Input.
    @MainActor private static var lastSide = AudioSettingsSide.input

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var router = SettingsRouter.shared
    @State private var side: AudioSettingsSide

    init() {
        let anchor = SettingsRouter.shared.destination.sectionAnchor
        _side = State(initialValue: AudioSettingsSide(anchor: anchor) ?? Self.lastSide)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sidePicker

                // Both segments share the spot under the control while one
                // fades into the other.
                ZStack(alignment: .top) {
                    switch side {
                    case .input:
                        AudioInputSettings()
                            .transition(.opacity)
                    case .output:
                        AudioOutputSettings()
                            .transition(.opacity)
                    }
                }
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
            .padding(22)
        }
        .settingsExpansionAnimation(value: side)
        .onChange(of: router.requestID) { _, _ in
            // A deep link names a section; show the segment that holds it
            // before the section focus scrolls there.
            guard router.page == .audio,
                  let requested = AudioSettingsSide(anchor: router.destination.sectionAnchor) else { return }
            side = requested
        }
        // Initial too: a deep link that opens Audio on one side records it.
        .onChange(of: side, initial: true) { _, newSide in Self.lastSide = newSide }
    }

    private var sidePicker: some View {
        let strings = FeatureStrings.settingsPages(l10n.language)
        return SettingsFullWidthSegmentedControl(
            title: strings.audioTitle,
            options: [(AudioSettingsSide.input, strings.audioInputSegment),
                      (AudioSettingsSide.output, strings.audioOutputSegment)],
            selection: $side)
    }
}
