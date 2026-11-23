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
                    // A normal reading fills with the bar's own color, as in the menu bar.
                    .fill(Color.white)
                    .frame(width: 4.8, height: 13.8 * fraction)
                    .padding(.bottom, 2.1)
            }
            .frame(width: 9, height: 18)
        }
        .foregroundStyle(.white)
    }
}

/// The readings a component offers, shown and ordered together: CPU usage
/// and temperature sit under CPU, each with its own switch, and move as one.
enum MenuBarReadingGroup: String, CaseIterable, PanelOrderItem {
    case cpu, gpu, memory, network, disk, battery, power, peripheralBattery, fanSpeed, connectedDevices

    var members: [MenuBarMetric] {
        switch self {
        case .cpu: return [.cpu, .cpuTemperature]
        case .gpu: return [.gpu, .gpuTemperature]
        case .memory: return [.memory]
        case .network: return [.network]
        case .disk: return [.diskUsage, .diskActivity]
        case .battery: return [.battery, .batteryTime, .batteryTemperature]
        case .power: return [.power]
        case .peripheralBattery: return [.peripheralBattery]
        case .fanSpeed: return [.fanSpeed]
        case .connectedDevices: return [.connectedDevices]
        }
    }

    static func group(of metric: MenuBarMetric) -> MenuBarReadingGroup {
        allCases.first { $0.members.contains(metric) } ?? .memory
    }

    /// Where usage and temperature can share one block, its own setting.
    var combineKey: String? {
        switch self {
        case .cpu: return DefaultsKey.menuBarCombineCPU
        case .gpu: return DefaultsKey.menuBarCombineGPU
        case .battery: return DefaultsKey.menuBarCombineBattery
        default: return nil
        }
    }

    var symbolName: String { members[0].symbolName }

    func title(_ s: Strings) -> String {
        switch self {
        case .cpu: return s.cpuLabel
        case .gpu: return s.gpuLabel
        case .disk: return s.diskStorageSettings
        case .battery: return s.batteryLabel
        default: return members[0].title(s)
        }
    }

    /// The groups in the order their first reading sits in `order`.
    static func order(from metrics: [MenuBarMetric]) -> [MenuBarReadingGroup] {
        var seen = Set<MenuBarReadingGroup>()
        var groups = metrics.map(group(of:)).filter { seen.insert($0).inserted }
        groups += allCases.filter { !seen.contains($0) }
        return groups
    }

    /// The flat reading order for these groups, keeping each group's
    /// readings in the order they already had.
    static func metrics(for groups: [MenuBarReadingGroup], current: [MenuBarMetric]) -> [MenuBarMetric] {
        groups.flatMap { group in
            let ordered = current.filter { group.members.contains($0) }
            return ordered + group.members.filter { !ordered.contains($0) }
        }
    }
}

/// The menu bar readings as a list of components: drag a component to put
/// it in order, and switch each of its readings on or off. The order stays
/// independent from which readings are visible, so switches do not reshuffle it.
struct MenuBarReadingsList: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.menuBarMetricOrder) private var metricOrder = ""
    @State private var order: [MenuBarReadingGroup] = MenuBarReadingGroup.order(from: MenuBarMetric.order(in: .standard))
    @State private var dragging: MenuBarReadingGroup?

    var body: some View {
        let groups = visibleGroups
        VStack(spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element) { index, group in
                // Dragging moves within the full saved order, so components
                // hidden by a module keep their slot for their return.
                VStack(spacing: 0) {
                    PanelReorderableItem(item: group, cornerRadius: 8, order: $order, dragging: $dragging) {
                        MenuBarReadingRow(group: group, members: visibleMembers(of: group))
                    }
                    if index < groups.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
                .transition(.settingsReveal)
            }
        }
        .onAppear { reload() }
        .onChange(of: order) { _, order in
            // Only a drag writes; reloading the saved order must not.
            let saved = MenuBarMetric.order(in: .standard)
            let next = MenuBarReadingGroup.metrics(for: order, current: saved)
            if next != saved { MenuBarMetric.setOrder(next) }
        }
        .onChange(of: metricOrder) { _, _ in reload() }
    }

    private func reload() {
        order = MenuBarReadingGroup.order(from: MenuBarMetric.order(in: .standard))
    }

    private func visibleMembers(of group: MenuBarReadingGroup) -> [MenuBarMetric] {
        group.members.filter { $0.feature.isAvailable && $0.isAvailableOnCurrentHardware }
    }

    /// Components whose module is off keep their saved slot but stay out of
    /// the list until it returns.
    private var visibleGroups: [MenuBarReadingGroup] {
        order.filter { !visibleMembers(of: $0).isEmpty }
    }
}

extension MenuBarMetric: PanelOrderItem {}

/// One component in one row: a grip, its icon and name, and a menu that
/// both shows what it puts in the menu bar and changes it. The menu lists
/// the component's readings as checkmarks, then its own options.
struct MenuBarReadingRow: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.menuBarMetricAppearance) private var metricAppearance = "values"
    /// Bumped whenever a preference changes, so the summary follows a
    /// checkmark picked in the menu.
    @State private var revision = 0
    let group: MenuBarReadingGroup
    let members: [MenuBarMetric]

    private var strings: SystemMonitorSettingsStrings { FeatureStrings.systemMonitorSettings(l10n.language) }

    var body: some View {
        let title = group.title(l10n.s)
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.quaternary)
                .frame(width: 12)
                .accessibilityHidden(true)
            LatticeSymbol(group.symbolName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(title)
                .lineLimit(1)
            Spacer(minLength: 12)
            Menu {
                Group {
                    if members.count == 1, let only = members.first {
                        MenuBarReadingToggle(metric: only, title: strings.showInMenuBar)
                    } else {
                        ForEach(members) { MenuBarReadingToggle(metric: $0, title: memberTitle($0)) }
                    }
                    if let key = group.combineKey, metricAppearance == "values", members.count > 1 {
                        Divider()
                        MenuBarDefaultsToggle(title: strings.combineTitle, key: key)
                    }
                    ForEach(members) { metric in
                        MenuBarReadingOptions(metric: metric)
                    }
                }
                // The page draws its toggles as switches, which a menu cannot
                // show; without this every item reads disabled.
                .toggleStyle(.automatic)
            } label: {
                Text(summary)
            }
            .fixedSize()
            .accessibilityLabel(title)
            .accessibilityValue(summary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            revision &+= 1
        }
    }

    /// "Usage, Temperature", "On" for a single reading, or "Off".
    private var summary: String {
        _ = revision
        let shown = members.filter { UserDefaults.standard.bool(forKey: $0.defaultsKey) }
        if shown.isEmpty { return strings.offOption }
        if members.count == 1 { return strings.onOption }
        return shown.map(memberTitle).joined(separator: ", ")
    }

    private func memberTitle(_ metric: MenuBarMetric) -> String {
        switch metric {
        case .cpu, .gpu, .diskUsage: return strings.memberUsage
        case .cpuTemperature, .gpuTemperature, .batteryTemperature: return strings.memberTemperature
        case .diskActivity: return strings.memberActivity
        case .battery: return strings.memberCharge
        case .batteryTime: return strings.memberTimeLeft
        default: return metric.title(l10n.s)
        }
    }
}

/// A reading's checkmark in its component's menu.
private struct MenuBarReadingToggle: View {
    let title: String
    @AppStorage private var shown: Bool

    init(metric: MenuBarMetric, title: String) {
        self.title = title
        _shown = AppStorage(wrappedValue: false, metric.defaultsKey)
    }

    var body: some View { Toggle(title, isOn: $shown) }
}

/// A checkmark backed by any Bool preference.
private struct MenuBarDefaultsToggle: View {
    let title: String
    @AppStorage private var isOn: Bool

    init(title: String, key: String) {
        self.title = title
        _isOn = AppStorage(wrappedValue: true, key)
    }

    var body: some View { Toggle(title, isOn: $isOn) }
}

/// A reading's own choices, after a divider in its component's menu.
private struct MenuBarReadingOptions: View {
    @ObservedObject private var l10n = L10n.shared
    let metric: MenuBarMetric
    @AppStorage(DefaultsKey.menuBarMemoryStyle) private var memoryStyle = "percent"
    @AppStorage(DefaultsKey.menuBarNetworkUploadFirst) private var uploadFirst = false
    @AppStorage(DiskMenuBarStyle.defaultsKey) private var diskStyle = DiskMenuBarStyle.percent

    var body: some View {
        switch metric {
        case .memory:
            Divider()
            Toggle(l10n.s.monitorMemoryPressureDot, isOn: Binding(
                get: { Defaults.sanitizedMenuBarMemoryStyle(memoryStyle) != "percent" },
                set: { memoryStyle = $0 ? "both" : "percent" }))
        case .network:
            Divider()
            Toggle(l10n.s.monitorNetworkUploadFirst, isOn: $uploadFirst)
        case .diskUsage:
            Divider()
            Picker(l10n.s.diskMenuBarStyleLabel, selection: $diskStyle) {
                Text(l10n.s.diskMenuBarUsedPercentage).tag(DiskMenuBarStyle.percent)
                Text(l10n.s.diskMenuBarAvailableSpace).tag(DiskMenuBarStyle.free)
                Text(l10n.s.diskMenuBarUsedSpace).tag(DiskMenuBarStyle.used)
            }
        default:
            EmptyView()
        }
    }
}
