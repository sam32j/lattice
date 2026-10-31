// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

/// Configuration pages keep a dedicated preference row while disabled. Their
/// active Form owns the same control and all of its existing presentation state.
struct FeatureConfigurationPage<Content: View>: View {
    let feature: AppFeature
    @ViewBuilder var content: () -> Content
    @ObservedObject private var runtime = FeatureRuntime.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        Group {
            if feature.isAvailable {
                content()
            } else {
                Form {
                    Section {
                        FeatureActivationControl(feature: feature)
                        Text(feature.hubDescription(FeatureStrings.hub(l10n.language)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text(feature.hubTitle(l10n.s, hub: FeatureStrings.hub(l10n.language)))
                    }
                }
                .formStyle(.grouped)
                .toggleStyle(.switch)
            }
        }
    }
}
