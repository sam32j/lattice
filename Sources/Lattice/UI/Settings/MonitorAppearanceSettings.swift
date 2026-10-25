import AppKit
import SwiftUI

/// Values or bars, each drawn the way the menu bar would draw a CPU reading.
struct MenuBarStyleChoice: View {
    let appearance: MenuBarMetricAppearance
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                mockup
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(selected ? Color.accentColor : .primary)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(selected ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? Color.accentColor.opacity(0.55) : .clear, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // The same proportions the real blocks use (MenuBarRenderer), reduced to
    // a CPU sample so the two styles read as themselves.
    @ViewBuilder
    private var mockup: some View {
        switch appearance {
        case .values:
            HStack(spacing: 10) {
                block(label: "CPU", value: "42%")
                block(label: "RAM", value: "61%")
            }
        case .bars:
            HStack(spacing: 10) {
                bar(label: "CPU", fraction: 0.42)
                bar(label: "RAM", fraction: 0.61)
            }
        }
    }

    private func block(label: String, value: String) -> some View {
        VStack(spacing: -1) {
            Text(label)
                .font(.system(size: 6.6, weight: .medium))
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(.white)
    }

    private func bar(label: String, fraction: CGFloat) -> some View {
        HStack(spacing: 2) {
            VStack(spacing: -1.8) {
                ForEach(Array(label.enumerated()), id: \.offset) { _, character in
                    Text(String(character))
                        .font(.system(size: 6.1, weight: .semibold))
                }
            }
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2.2, style: .continuous)
                    .stroke(Color.white, lineWidth: 1.15)
                RoundedRectangle(cornerRadius: 1.2, style: .continuous)
                    .fill(Color(red: 0.39, green: 0.82, blue: 1.0))
                    .frame(width: 4.8, height: 13.8 * fraction)
                    .padding(.bottom, 2.1)
            }
            .frame(width: 9, height: 18)
        }
        .foregroundStyle(.white)
    }
}

/// The menu bar readings as tiles: drag to put them in order, click the
/// checkmark to show or hide one. The order stays independent from which
/// metrics are visible, so toggles do not reshuffle it.
struct MenuBarMetricTiles: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.menuBarMetricOrder) private var metricOrder = ""
    @State private var order: [MenuBarMetric] = MenuBarMetric.order(in: .standard)
    @State private var dragging: MenuBarMetric?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: monitorTokenColumns, spacing: 8) {
                ForEach(visibleOrder) { metric in
                    // Dragging moves within the full saved order, so metrics
                    // hidden by the hub keep their slot for their return.
                    PanelReorderableItem(item: metric, order: $order, dragging: $dragging) {
                        MenuBarMetricTile(metric: metric)
                    }
                }
            }
            .monitorTokenGroup()
        }
        .onAppear { order = MenuBarMetric.order(in: .standard) }
        .onChange(of: order) { _, order in
            // Only a drag writes; reloading the saved order must not.
            if order != MenuBarMetric.order(in: .standard) { MenuBarMetric.setOrder(order) }
        }
        .onChange(of: metricOrder) { _, _ in order = MenuBarMetric.order(in: .standard) }
    }

    /// Metrics whose family left the hub keep their saved slot but stay out
    /// of the editor until they return.
    private var visibleOrder: [MenuBarMetric] {
        order.filter { $0.feature.isAvailable && $0.isAvailableOnCurrentHardware }
    }
}

extension MenuBarMetric: PanelOrderItem {}

/// One reading, backed by its own key so the preview above updates the
/// moment it is ticked. A reading with its own option carries it in its card.
struct MenuBarMetricTile: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var colorScheme
    let metric: MenuBarMetric
    @AppStorage private var shown: Bool
    @AppStorage(DefaultsKey.menuBarMemoryStyle) private var memoryStyle = "percent"
    @AppStorage(DefaultsKey.menuBarNetworkUploadFirst) private var uploadFirst = false
    @AppStorage(DiskMenuBarStyle.defaultsKey) private var diskStyle = DiskMenuBarStyle.percent

    init(metric: MenuBarMetric) {
        self.metric = metric
        _shown = AppStorage(wrappedValue: false, metric.defaultsKey)
    }

    var body: some View {
        MonitorToken(symbol: metric.symbolName, title: metric.title(l10n.s), included: $shown,
                     options: options, optionsSummary: optionsSummary)
    }

    /// What the reading's option makes the menu bar show, in its own terms.
    private var optionsSummary: String {
        switch metric {
        case .memory:
            return Defaults.sanitizedMenuBarMemoryStyle(memoryStyle) != "percent"
                ? l10n.s.monitorMemoryPressureDot : FeatureStrings.mouseClickDebounce(l10n.language).moreOptions
        case .network: return uploadFirst ? "↑ ↓" : "↓ ↑"
        case .diskUsage:
            switch diskStyle {
            case DiskMenuBarStyle.free: return l10n.s.diskMenuBarAvailableSpace
            case DiskMenuBarStyle.used: return l10n.s.diskMenuBarUsedSpace
            default: return l10n.s.diskMenuBarUsedPercentage
            }
        default: return ""
        }
    }

    private var options: AnyView? {
        switch metric {
        case .memory:
            return AnyView(MonitorTokenOption(
                symbol: "circle.fill",
                title: l10n.s.monitorMemoryPressureDot,
                tint: PanelMetricColor.green(for: colorScheme),
                isOn: Binding(get: { Defaults.sanitizedMenuBarMemoryStyle(memoryStyle) != "percent" },
                              set: { memoryStyle = $0 ? "both" : "percent" })))
        case .network:
            return AnyView(MonitorTokenOption(symbol: "arrow.up.arrow.down",
                                                 title: l10n.s.monitorNetworkUploadFirst,
                                                 isOn: $uploadFirst))
        case .diskUsage:
            return AnyView(Picker(l10n.s.diskMenuBarStyleLabel, selection: $diskStyle) {
                Text(l10n.s.diskMenuBarUsedPercentage).tag(DiskMenuBarStyle.percent)
                Text(l10n.s.diskMenuBarAvailableSpace).tag(DiskMenuBarStyle.free)
                Text(l10n.s.diskMenuBarUsedSpace).tag(DiskMenuBarStyle.used)
            }
            .pickerStyle(.menu))
        default:
            return nil
        }
    }
}
