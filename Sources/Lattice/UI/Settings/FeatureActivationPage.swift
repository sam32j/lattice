// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

/// The closure is intentionally lazy: an off page never constructs its
/// service-backed content simply because somebody visits the sidebar row.
struct FeatureActivationPage<Content: View>: View {
    let feature: AppFeature
    var options: (() -> AnyView)? = nil
    @State private var showingOptions = false
    @ViewBuilder var content: () -> Content
    @ObservedObject private var runtime = FeatureRuntime.shared
    @ObservedObject private var l10n = L10n.shared

    private var title: String { feature.hubTitle(l10n.s, hub: FeatureStrings.hub(l10n.language)) }

    var body: some View {
        Group {
            if feature.isAvailable {
                content()
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        ContentUnavailableView {
                            Label(title, systemImage: feature.symbolName)
                        } description: {
                            Text(feature.hubDescription(FeatureStrings.hub(l10n.language)))
                        } actions: {
                            FeatureActivationControl(feature: feature)
                                .toggleStyle(.button)
                                .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity,
                               minHeight: max(0, geometry.size.height - 44))
                        .padding(22)
                    }
                }
            }
        }
        .toolbar {
            activationToolbarItem
        }
        .onChange(of: feature.isAvailable) { _, enabled in
            if !enabled { showingOptions = false }
        }
    }
    @ToolbarContentBuilder
    private var activationToolbarItem: some ToolbarContent {
#if compiler(>=6.2)
        if #available(macOS 26, *) {
            ToolbarItem(id: "feature-activation-\(feature.rawValue)", placement: .primaryAction) { toolbarControl }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(id: "feature-activation-\(feature.rawValue)", placement: .primaryAction) { toolbarControl }
        }
#else
        ToolbarItem(id: "feature-activation-\(feature.rawValue)", placement: .primaryAction) { toolbarControl }
#endif
    }

    private var toolbarControl: some View {
        HStack(spacing: 6) {
            if feature.isAvailable, let options {
                Button { showingOptions.toggle() } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(FlatSettingsOptionsButtonStyle())
                .help(FeatureStrings.recorder(l10n.language).moreOptions)
                .accessibilityLabel(FeatureStrings.recorder(l10n.language).moreOptions)
                .popover(isPresented: $showingOptions) { options() }
            }
            FeatureActivationControl(feature: feature)
                .toggleStyle(.switch)
                .controlSize(.small)
                .fixedSize()
        }
        .padding(.horizontal, 8)
    }

}

/// Inline owner for a feature on a shared settings page. Its children are
/// constructed only after activation, including their ObservedObject values.
struct FeatureActivationSection<Content: View>: View {
    let feature: AppFeature
    @ViewBuilder var content: () -> Content
    @ObservedObject private var runtime = FeatureRuntime.shared
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsCard {
                FeatureActivationControl(feature: feature)
                    .toggleStyle(.switch)
                Text(feature.hubDescription(FeatureStrings.hub(l10n.language)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if feature.isAvailable { content() }
        }
        .settingsExpansionAnimation(value: feature.isAvailable)
    }
}

struct FeatureActivationControl: View {
    let feature: AppFeature
    @ObservedObject private var runtime = FeatureRuntime.shared
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.radialMenuEnabled) private var radialEnabled = false

    private var title: String {
        if feature == .radialMenu { return FeatureStrings.radialMenu(l10n.language).enableLabel }
        return SettingsOwnershipStrings.enable(
            feature.hubTitle(l10n.s, hub: FeatureStrings.hub(l10n.language)), l10n.language)
    }

    private var requirements: [SettingsPermission] {
        guard feature == .radialMenu else { return [] }
        let profiles = RadialMenuSupport.decodeProfiles(
            UserDefaults.standard.data(forKey: DefaultsKey.radialMenuProfiles))
        return RadialMenuSupport.needsAccessibility(profiles) ? [.accessibility] : []
    }

    private var binding: Binding<Bool> {
        Binding(get: { feature.isAvailable }, set: { runtime.setPageEnabled(feature, $0) })
    }

    var body: some View {
        Group {
            if feature.isAvailable {
                FeatureActivationBusyGuard(feature: feature) { activationToggle }
            } else {
                activationToggle
            }
        }
        .help(title)
    }

    @ViewBuilder private var activationToggle: some View {
        if requirements.isEmpty {
            Toggle(title, isOn: binding)
        } else {
            PermissionGatedToggle(title, isOn: binding, requiring: requirements)
        }
    }
}
