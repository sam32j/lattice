// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

/// The closure is intentionally lazy: an off page never constructs its
/// service-backed content simply because somebody visits the sidebar row.
struct FeatureActivationPage<Content: View>: View {
    let feature: AppFeature
    var options: (() -> AnyView)? = nil
    /// A page control shown before the options button, such as Refresh.
    var accessory: (() -> AnyView)? = nil
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
                SettingsFeatureEmptyState(title: title, symbol: feature.symbolName,
                                          description: feature.emptyStateDescription(FeatureStrings.hub(l10n.language))) {
                    FeatureActivationControl(feature: feature)
                        .toggleStyle(.button)
                        .buttonStyle(.borderedProminent)
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
    private var activationToolbarItem: some ToolbarContent {
        SettingsTitleBarItem(id: "feature-activation-\(feature.rawValue)") { toolbarControl }
    }

    private var toolbarControl: some View {
        HStack(spacing: 6) {
            if feature.isAvailable, let accessory {
                accessory()
            }
            if feature.isAvailable, let options {
                Button { showingOptions.toggle() } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(FlatSettingsOptionsButtonStyle())
                // The page hands this button first focus as it opens; no ring for that.
                .focusEffectDisabled()
                .help(FeatureStrings.recorder(l10n.language).moreOptions)
                .accessibilityLabel(FeatureStrings.recorder(l10n.language).moreOptions)
                .popover(isPresented: $showingOptions) { options() }
            }
            FeatureActivationControl(feature: feature, settlesBeforeApplying: true)
                .toggleStyle(.switch)
                .controlSize(SettingsTitleBarSwitch.controlSize)
                .fixedSize()
        }
        .padding(.horizontal, 8)
    }

}

/// A switched-off feature's whole page: its symbol, name and what it does,
/// centered, with a button that turns it on.
struct SettingsFeatureEmptyState<Actions: View>: View {
    let title: String
    let symbol: String
    let description: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ContentUnavailableView {
                    Label(title, systemImage: symbol)
                } description: {
                    Text(description)
                } actions: {
                    actions()
                }
                .frame(maxWidth: .infinity, minHeight: max(0, geometry.size.height - 44))
                .padding(22)
            }
        }
    }
}

/// A page's own controls on the trailing side of the settings title bar,
/// without the shared glass background macOS 26 would draw behind them.
struct SettingsTitleBarItem<Content: View>: ToolbarContent {
    let id: String
    @ViewBuilder let content: () -> Content

    @ToolbarContentBuilder
    var body: some ToolbarContent {
#if compiler(>=6.2)
        if #available(macOS 26, *) {
            ToolbarItem(id: id, placement: .primaryAction) { content() }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(id: id, placement: .primaryAction) { content() }
        }
#else
        ToolbarItem(id: id, placement: .primaryAction) { content() }
#endif
    }
}

/// A page's main switch in the settings title bar, at the regular size.
///
/// The knob slides first, and the change it stands for is applied once the
/// slide has finished. Applying it at once rebuilt the page and the title bar
/// items mid-slide, which cut the animation short so the knob seemed to jump.
/// Flipping again before then cancels the earlier change.
struct SettingsTitleBarSwitch: View {
    static let controlSize = ControlSize.regular

    let title: String
    let isOn: Bool
    let apply: (Bool) -> Void
    @StateObject private var settling = SettlingSwitchState()

    var body: some View {
        Toggle(title, isOn: settling.binding(isOn: isOn, apply: apply))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(Self.controlSize)
            .fixedSize()
            .accessibilityLabel(title)
            .help(title)
    }
}

/// What a settling switch shows while its change waits for the knob.
@MainActor
final class SettlingSwitchState: ObservableObject {
    @Published private(set) var pending: Bool?
    private var generation = 0
    /// Its own burst, so another switch's change never replaces this one's.
    private let burstKey = UUID().uuidString

    func binding(isOn: Bool, apply: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: { self.pending ?? isOn }, set: { value in
            self.pending = value
            self.generation &+= 1
            let current = self.generation
            settingsApplyAfterSwitch(key: self.burstKey) {
                guard self.generation == current else { return }
                apply(value)
                self.pending = nil
            }
        })
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
    /// In the title bar: let the knob finish sliding before the page swaps.
    var settlesBeforeApplying = false
    @StateObject private var settling = SettlingSwitchState()
    @ObservedObject private var runtime = FeatureRuntime.shared
    @ObservedObject private var l10n = L10n.shared

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
        let runtime = runtime
        let feature = feature
        guard settlesBeforeApplying else {
            return Binding(get: { feature.isAvailable }, set: { runtime.setPageEnabled(feature, $0) })
        }
        return settling.binding(isOn: feature.isAvailable) { runtime.setPageEnabled(feature, $0) }
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
            PermissionGatedToggle(title, isOn: binding, requiring: requirements, feature: feature)
        }
    }
}

/// One option in a page's title bar menu: a title, a line of help and a
/// switch, clickable anywhere on the row.
struct SettingsMenuToggleRow: View {
    /// A title bar popover's corner radius (about 16pt) less the 6pt inset
    /// every title bar menu puts around its rows.
    static let highlightRadius: CGFloat = 10

    let title: String
    var help: String? = nil
    @Binding var isOn: Bool
    @State private var hovered = false

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: help == nil ? .center : .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                    if let help {
                        Text(help)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                Toggle(title, isOn: .constant(isOn))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            // Concentric with the popover: its corner radius less the menu's
            // 6pt inset, so the highlight follows the outer curve.
            .background(hovered ? Color.primary.opacity(0.06) : Color.clear,
                        in: RoundedRectangle(cornerRadius: Self.highlightRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // A popover hands its first row keyboard focus as it opens; the hover
        // fill already marks the row, so no ring for that.
        .focusEffectDisabled()
        .onHover { hovered = $0 }
        .accessibilityRepresentation {
            Toggle(title, isOn: $isOn)
                .accessibilityHint(help ?? "")
        }
    }
}
