// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

enum MetricDetailKind: String, Equatable, Identifiable {
    case cpu, gpu, memory, network, disk, battery, power, fan, connectedDevices

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "rectangle.connected.to.line.below"
        case .memory: return "memorychip"
        case .network: return "network"
        case .disk: return "internaldrive"
        case .battery: return "battery.100"
        case .power: return "powerplug.fill"
        case .fan: return "fanblades"
        case .connectedDevices: return "cable.connector"
        }
    }

    var monitorNeeds: SystemMonitorPanelNeeds {
        switch self {
        case .cpu:
            return SystemMonitorPanelNeeds(cpu: true, cpuTemperature: true)
        case .gpu:
            return SystemMonitorPanelNeeds(gpu: true, gpuTemperature: true)
        case .memory:
            return SystemMonitorPanelNeeds(memory: true)
        case .network:
            return SystemMonitorPanelNeeds(network: true)
        case .disk:
            return SystemMonitorPanelNeeds(disk: true)
        case .battery:
            if PowerSampler.hasInternalBattery {
                return SystemMonitorPanelNeeds(power: true,
                                               battery: true,
                                               peripheralBattery: true,
                                               batteryTemperature: true)
            }
            return SystemMonitorPanelNeeds(peripheralBattery: true)
        case .power:
            return SystemMonitorPanelNeeds(power: true)
        case .fan:
            return SystemMonitorPanelNeeds(fanSpeed: true)
        case .connectedDevices:
            return SystemMonitorPanelNeeds(connectedDevices: true)
        }
    }

    func title(_ s: Strings) -> String {
        switch self {
        case .cpu: return s.cpuLabel
        case .gpu: return s.gpuLabel
        case .memory: return s.memorySection
        case .network: return s.networkSection
        case .disk: return s.diskStorageSettings
        case .battery: return s.batteryLabel
        case .power: return s.powerSection
        case .fan: return FeatureStrings.fanControl(L10n.shared.language).menuBarTitle
        case .connectedDevices: return FeatureStrings.connectedDevices(L10n.shared.language).title
        }
    }

    var processKind: BreakdownKind? {
        switch self {
        case .cpu: return .cpu
        case .gpu: return .gpu
        case .memory: return .memory
        case .power: return .energy
        case .battery: return .energy
        case .network: return .network
        case .disk: return .disk
        case .fan, .connectedDevices: return nil
        }
    }
}

extension MenuBarMetric {
    var detailKind: MetricDetailKind {
        switch self {
        case .cpu, .cpuTemperature:
            return .cpu
        case .gpu, .gpuTemperature:
            return .gpu
        case .memory:
            return .memory
        case .network:
            return .network
        case .diskUsage, .diskActivity:
            return .disk
        case .battery, .batteryTemperature, .peripheralBattery:
            return .battery
        case .batteryTime, .power:
            return .power
        case .fanSpeed:
            return .fan
        case .connectedDevices:
            return .connectedDevices
        }
    }
}

struct ActivityMonitorButton: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var isHovered = false

    var body: some View {
        Button {
            let fallback = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
            let url = NSWorkspace.shared
                .urlForApplication(withBundleIdentifier: "com.apple.ActivityMonitor") ?? fallback
            NSWorkspace.shared.open(url)
        } label: {
            Image(systemName: "arrow.up.forward.app")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.primary.opacity(isHovered ? 0.1 : 0)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(l10n.s.monitorOpenActivityMonitor)
        .accessibilityLabel(l10n.s.monitorOpenActivityMonitor)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}

struct MetricDetailView: View {
    enum Presentation {
        case menuPanel, hubPanel, island
    }

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var speed = SpeedTest.shared
    @ObservedObject private var addressService = NetworkAddressService.shared
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue
    @AppStorage(DefaultsKey.monitorInterval) private var monitorInterval = 2
    @AppStorage(DefaultsKey.networkSpeedUnit) private var speedUnit = NetworkSpeedUnit.bytes
    let kind: MetricDetailKind

    private let presentation: Presentation
    private var fitsIsland: Bool { presentation == .island }
    private var usesWidgetDesign: Bool { presentation != .menuPanel }
    private var showsHeroTitle: Bool { usesWidgetDesign && SystemWidgetLayout.showsHeroTitle(kind) }
    private var isWidgetEnergy: Bool { usesWidgetDesign && SystemWidgetLayout.isEnergyMetric(kind) }
    private var isDesktopEnergy: Bool { isWidgetEnergy && !PowerSampler.hasInternalBattery }
    private var processKind: BreakdownKind? { isWidgetEnergy ? .cpuPower : kind.processKind }
    @StateObject private var navigation: SystemNavigationState
    @State private var speedSamples: [Double] = []
    @State private var processRows: [ProcessUsage] = []
    @State private var processRowsLoading = true
    @State private var lastProcessRefresh = Date.distantPast
    @State private var refreshSerial = 0
    @State private var networkMonitoringActive = false
    @State private var metricViewOwner = UUID()
    private let processLimit = 15

    init(kind: MetricDetailKind, presentation: Presentation = .menuPanel) {
        self.kind = kind
        self.presentation = presentation
        _navigation = StateObject(wrappedValue: presentation == .menuPanel ? SystemNavigationState() : .shared)
    }

    private func severity(for fraction: Double, inverted: Bool = false) -> Int {
        guard fraction.isFinite else { return 0 }
        if inverted {
            if fraction <= 0.10 { return 2 }
            if fraction <= 0.20 { return 1 }
            return 0
        } else {
            if fraction >= 0.90 { return 2 }
            if fraction >= 0.70 { return 1 }
            return 0
        }
    }

    private var currentSeverity: Int {
        let snapshot = monitor.snapshot
        switch kind {
        case .cpu:
            return severity(for: snapshot.cpuUsage ?? 0)
        case .gpu:
            return severity(for: snapshot.gpuUsage ?? 0)
        case .memory:
            let used = snapshot.memoryUsed ?? 0
            let total = snapshot.memoryTotal ?? 1
            let ratio = total > 0 ? Double(used) / Double(total) : 0
            return severity(for: ratio)
        case .battery, .power:
            guard kind == .battery || isWidgetEnergy,
                  let power = snapshot.power, power.hasBattery else { return 0 }
            let discharging = isWidgetEnergy
                ? SystemWidgetDetailContent.batteryIsDischarging(power)
                : !power.isCharging && !power.externalConnected
            guard discharging else { return 0 }
            let charge = Double(power.chargePercent ?? 100) / 100.0
            return severity(for: charge, inverted: true)
        case .disk:
            let disk = currentDisk
            return severity(for: disk?.usedFraction ?? 0)
        case .network, .fan, .connectedDevices:
            return 0
        }
    }

    private var graphColor: Color {
        switch currentSeverity {
        case 2:
            return Color(red: 1.0, green: 0.27, blue: 0.23)
        case 1:
            return Color(red: 1.0, green: 0.62, blue: 0.04)
        default:
            return Color(red: 0.37, green: 0.66, blue: 1.0)
        }
    }

    private var heroSubtitleColor: Color {
        switch currentSeverity {
        case 2:
            return Color(red: 1.0, green: 0.27, blue: 0.23)
        case 1:
            return Color(red: 1.0, green: 0.62, blue: 0.04)
        default:
            return Color(red: 0.63, green: 0.63, blue: 0.66)
        }
    }

    private var currentDisk: DiskDeviceReading? {
        SystemWidgetDetailContent.disk(in: monitor.snapshot, index: navigation.selectedDiskIndex)
    }

    private var hasExternalDisks: Bool {
        monitor.snapshot.disk?.devices.contains(where: { !$0.isInternal }) == true
    }

    private var currentDiskReadWrite: (read: Double, write: Double) {
        if let disk = currentDisk, (disk.readBytesPerSec != nil || disk.writeBytesPerSec != nil) {
            return (disk.readBytesPerSec ?? 0, disk.writeBytesPerSec ?? 0)
        }
        return diskActivity(from: monitor.snapshot.disk) ?? (0, 0)
    }

    var body: some View {
        Group {
            if navigation.showingSpeedTest {
                speedTestView
            } else {
                VStack(alignment: .leading, spacing: SystemWidgetLayout.spacing) {
                    if kind == .disk {
                        if hasExternalDisks, let devices = monitor.snapshot.disk?.devices {
                            // The disk picker and its digits form one hero.
                            // Keep half the usual 12pt gap below the chips.
                            VStack(alignment: .leading, spacing: 6) {
                                VStack(alignment: .leading, spacing: 8) {
                                    if showsHeroTitle {
                                        Text(kind.title(l10n.s))
                                            .font(.system(size: 16, weight: .semibold))
                                            .lineLimit(1)
                                            .padding(.horizontal, 4)
                                    }
                                    disksChips(devices)
                                        .frame(height: SystemWidgetLayout.diskPickerHeight)
                                }
                                diskDigitsSection
                                    .frame(height: fitsIsland ? 72 : nil, alignment: .topLeading)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                if showsHeroTitle {
                                    Text(kind.title(l10n.s))
                                        .font(.system(size: 16, weight: .semibold))
                                        .lineLimit(1)
                                }
                                Text(heroPrimaryValue)
                                    .font(.system(size: 46, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)

                                Text(heroSubtitle)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 4)
                            .frame(height: fitsIsland ? (showsHeroTitle ? SystemWidgetLayout.heroHeight(kind) : 72) : nil, alignment: .topLeading)
                        }
                    } else {
                        heroSection
                            .frame(height: fitsIsland ? SystemWidgetLayout.heroHeight(kind) : nil, alignment: .topLeading)
                    }

                    if SystemWidgetDetailContent.hasGraph(for: kind, widgetDesign: usesWidgetDesign) {
                        graphSection
                    }

                    let factList = facts
                    if !factList.isEmpty { factsGrid(factList) }

                    if processKind != nil {
                        processCard
                    }

                    if kind == .network {
                        speedTestRowButton
                            .frame(height: SystemWidgetLayout.speedButtonHeight)
                    }

                    moreDetailsSection
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, SystemWidgetLayout.topInset)
        .padding(.bottom, fitsIsland ? 0 : 6)
        .onAppear {
            monitor.panelDidAppear()
            updateMonitorNeeds()
            monitor.setNotchVisible(true)
            monitor.refreshNow()
            if kind == .network {
                startNetworkMonitoringIfNeeded()
                addressService.refreshPublicIP()
            }
            refreshProcessRows(force: true, delay: 0.2)
        }
        .onDisappear {
            monitor.setMetricViewNeeds(nil, owner: metricViewOwner)
            monitor.panelDidDisappear()
            monitor.setNotchVisible(false)
        }
        .onChange(of: kind) { oldKind, newKind in
            updateMonitorNeeds()
            if oldKind == .network, newKind != .network {
                stopNetworkMonitoringIfNeeded()
            } else if oldKind != .network, newKind == .network {
                startNetworkMonitoringIfNeeded()
                addressService.refreshPublicIP()
            }
            refreshProcessRows(force: true, delay: 0.2)
        }
        .onReceive(monitor.$snapshot) { _ in refreshProcessRows(force: false) }
        .onChange(of: navigation.showingSpeedTest) { [weak speed] _, showing in
            guard fitsIsland else { return }
            if showing {
                NotchService.shared.customBackAction = {
                    speed?.cancel()
                    withAnimation(.easeInOut(duration: 0.22)) {
                        SystemNavigationState.shared.showingSpeedTest = false
                        NotchService.shared.refreshPresentation()
                    }
                    return true
                }
            } else {
                NotchService.shared.customBackAction = nil
            }
        }
        .onDisappear {
            if fitsIsland { NotchService.shared.customBackAction = nil }
            refreshSerial &+= 1
            processRows = []
            processRowsLoading = true
            stopNetworkMonitoringIfNeeded()
        }
    }

    private func updateMonitorNeeds() {
        guard usesWidgetDesign else { return }
        var needs = isWidgetEnergy && PowerSampler.hasInternalBattery
            ? MetricDetailKind.battery.monitorNeeds : kind.monitorNeeds
        needs.cpuCores = kind == .cpu
        needs.gpuDetail = kind == .gpu
        monitor.setMetricViewNeeds(needs, owner: metricViewOwner)
    }

    private func disksChips(_ devices: [DiskDeviceReading]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(devices.enumerated()), id: \.element.id) { index, disk in
                    let isSelected = navigation.selectedDiskIndex == index
                    HStack(spacing: 6) {
                        Text(disk.name.isEmpty ? (disk.isInternal ? "Macintosh HD" : "Disk") : disk.name)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        if disk.canEject {
                            Button {
                                DiskProtectionService.shared.eject(disk)
                            } label: {
                                Image(systemName: "eject.fill")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .buttonStyle(.plain)
                            .help("Eject")
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isSelected
                                ? (colorScheme == .dark ? Color.white : Color.primary)
                                : (colorScheme == .dark ? Color(white: 0.16) : Color.primary.opacity(0.08)))
                    )
                    .foregroundStyle(isSelected
                        ? (colorScheme == .dark ? Color.black : Color(NSColor.windowBackgroundColor))
                        : (colorScheme == .dark ? Color.white : Color.primary))
                    .contentShape(Capsule())
                    .onTapGesture {
                        navigation.selectedDiskIndex = index
                        if fitsIsland { NotchService.shared.refreshPresentation() }
                    }
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
        }
    }

    private var diskDigitsSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(heroPrimaryValue)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(heroSubtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 4)
    }

    private var heroSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if showsHeroTitle {
                    Text(isWidgetEnergy ? (isDesktopEnergy ? "Energy" : l10n.s.batteryLabel) : kind.title(l10n.s))
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                }
                if kind == .network {
                    let down = Double(monitor.snapshot.netDownBytesPerSec ?? 0)
                    let fmt = NotchSystemView.formatRate(down)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("↓")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(Color(red: 0.37, green: 0.66, blue: 1.0))
                            .frame(width: 24, alignment: .center)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(fmt.n)
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(fmt.u)
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(Color(red: 0.63, green: 0.63, blue: 0.66))
                                .lineLimit(1)
                        }
                    }
                    let up = Double(monitor.snapshot.netUpBytesPerSec ?? 0)
                    let upFmt = NotchSystemView.formatRate(up)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("↑")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 0.19, green: 0.82, blue: 0.35))
                            .frame(width: 24, alignment: .center)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(upFmt.n)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(upFmt.u)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(heroSubtitleColor)
                                .lineLimit(1)
                        }
                    }
                } else {
                    HStack(alignment: isDesktopEnergy ? .firstTextBaseline : .center, spacing: 8) {
                        Text(heroPrimaryValue)
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if isDesktopEnergy, monitor.snapshot.power?.systemWatts != nil {
                            Text("W")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.secondary)
                        }
                        if usesWidgetDesign, kind == .memory, let ratio = memoryRatio {
                            Spacer(minLength: 0)
                            SystemMemoryPressureChip(fraction: ratio)
                        }
                    }
                    Text(heroSubtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(showsHeroTitle ? Color.secondary : heroSubtitleColor)
                        .lineLimit(1)
                }
            }
            if !usesWidgetDesign || kind != .memory { Spacer(minLength: 8) }
            if let auxLines = heroAuxLines, kind != .network {
                VStack(alignment: .trailing, spacing: 2) {
                    ForEach(auxLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(red: 0.44, green: 0.44, blue: 0.47))
                    }
                }
                .padding(.top, 6)
            }
        }
        .padding(.horizontal, 4)
    }

    private var graphSection: some View {
        VStack(spacing: SystemWidgetLayout.graphSpacing) {
            graph
            if kind == .disk {
                HStack(spacing: 14) {
                    let activity = currentDiskReadWrite
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 0.37, green: 0.66, blue: 1.0))
                            .frame(width: 6, height: 6)
                        Text("Read \(MetricFormat.bytesPerSec(activity.read))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(colorScheme == .dark ? Color(red: 0.63, green: 0.63, blue: 0.66) : Color.secondary)
                    }
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(red: 0.19, green: 0.82, blue: 0.35))
                            .frame(width: 6, height: 6)
                        Text("Write \(MetricFormat.bytesPerSec(activity.write))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(colorScheme == .dark ? Color(red: 0.63, green: 0.63, blue: 0.66) : Color.secondary)
                    }
                    Spacer()
                    Text("now")
                        .font(.system(size: 11))
                        .foregroundStyle(colorScheme == .dark ? Color(red: 0.44, green: 0.44, blue: 0.47) : Color.secondary)
                }
                .frame(height: SystemWidgetLayout.graphCaptionHeight)
            } else {
                HStack {
                    Text(graphUnit)
                    Spacer()
                    Text("now")
                }
                .font(.system(size: 11))
                .foregroundStyle(Color(red: 0.44, green: 0.44, blue: 0.47))
                .frame(height: SystemWidgetLayout.graphCaptionHeight)
            }
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var graph: some View {
        if isWidgetEnergy {
            widgetEnergyGraph
        } else {
            metricGraph
        }
    }

    @ViewBuilder
    private var metricGraph: some View {
        switch kind {
        case .cpu:
            usageHistoryGraph(monitor.snapshot.cpuUsageSamples)
        case .gpu:
            usageHistoryGraph(monitor.snapshot.gpuUsageSamples)
        case .memory:
            historyGraph(MonitorMemoryMetric.current.history(in: monitor.snapshot),
                         color: graphColor)
        case .network:
            networkGraph
        case .disk:
            diskGraph
        case .battery:
            if PowerSampler.hasInternalBattery {
                historyGraph(monitor.snapshot.batteryHistory, color: graphColor)
            }
        case .power:
            let peak = MetricFormat.graphCeiling(monitor.snapshot.systemPowerHistory.max() ?? 0, unitStep: 1000)
            historyGraph(monitor.snapshot.systemPowerHistory, color: graphColor, maxValue: peak,
                         ceilingLabel: MetricFormat.watts(peak))
        case .fan, .connectedDevices:
            EmptyView()
        }
    }

    private var widgetEnergyGraph: some View {
        let hour = Duration.seconds(UsageMetricHistory.hourSeconds)
        let points = UsageMetricHistory.window(monitor.snapshot.energyHistory, endingAt: .now, duration: hour)
        let maxGap: Duration = isDesktopEnergy ? .seconds(30) : .seconds(120)
        let segments = UsageMetricHistory.segments(points, duration: hour, maximumGap: maxGap)
        let peak = isDesktopEnergy ? MetricFormat.graphCeiling(points.map(\.value).max() ?? 0, unitStep: 10) : 1
        return ZStack {
            ForEach(segments.indices, id: \.self) { index in
                let segment = segments[index]
                Sparkline(values: segment.map(\.value), color: graphColor, maxValue: peak,
                          fillOpacity: 0.35, lineWidth: 2, horizontalPositions: segment.map(\.position))
            }
        }
        .frame(height: SystemWidgetLayout.graphHeight)
        .graphCeilingLabel(isDesktopEnergy ? MetricFormat.watts(peak) : MetricFormat.percent(1))
    }

    private func usageHistoryGraph(_ samples: [UsageMetricHistory.Sample]) -> some View {
        let points = UsageMetricHistory.window(samples, endingAt: .now)
        return historyGraph(points.map(\.value), color: graphColor, positions: points.map(\.position))
    }

    @ViewBuilder
    private func historyGraph(_ values: [Double], color: Color, maxValue: Double = 1,
                              ceilingLabel: String = MetricFormat.percent(1), positions: [Double]? = nil) -> some View {
        let plotValues = positions != nil || values.count >= 2 ? values : [0.001, 0.001]
        Sparkline(values: plotValues,
                  color: color,
                  maxValue: maxValue,
                  fillOpacity: 0.35,
                  lineWidth: 2,
                  showsZeroBaseline: !usesWidgetDesign,
                  horizontalPositions: positions)
            .frame(height: SystemWidgetLayout.graphHeight)
            .graphCeilingLabel(ceilingLabel)
    }

    @ViewBuilder
    private var networkGraph: some View {
        let down = monitor.snapshot.netDownHistory
        let up = monitor.snapshot.netUpHistory
        let inBits = speedUnit == .bits
        let peak = MetricFormat.networkGraphCeiling(max(down.max() ?? 0, up.max() ?? 0, 1),
                                                    inBits: inBits)
        ZStack {
            Sparkline(values: down.count >= 2 ? down : [0, 0], color: graphColor, maxValue: peak, fillOpacity: 0.35, lineWidth: 2, showsZeroBaseline: !usesWidgetDesign)
            Sparkline(values: up.count >= 2 ? up : [0, 0],
                      color: PanelMetricColor.green(for: colorScheme),
                      maxValue: peak,
                      fillOpacity: 0.15,
                      lineWidth: 1.5)
        }
        .frame(height: SystemWidgetLayout.graphHeight)
        .graphCeilingLabel(MetricFormat.networkRate(peak, inBits: inBits))
    }

    @ViewBuilder
    private var diskGraph: some View {
        let read = monitor.snapshot.diskReadHistory
        let write = monitor.snapshot.diskWriteHistory
        let peak = MetricFormat.graphCeiling(max(read.max() ?? 0, write.max() ?? 0, 1), unitStep: 1024)
        ZStack {
            Sparkline(values: read.count >= 2 ? read : [0, 0],
                      color: Color(red: 0.37, green: 0.66, blue: 1.0),
                      maxValue: peak,
                      fillOpacity: 0.35,
                      lineWidth: 2,
                      showsZeroBaseline: !usesWidgetDesign)
            Sparkline(values: write.count >= 2 ? write : [0, 0],
                      color: Color(red: 0.19, green: 0.82, blue: 0.35),
                      maxValue: peak,
                      fillOpacity: 0.15,
                      lineWidth: 1.5)
        }
        .frame(height: SystemWidgetLayout.graphHeight)
        .graphCeilingLabel(MetricFormat.bytesPerSec(peak))
    }

    private func factsGrid(_ list: [(String, String, String?, String?)]) -> some View {
        let columns = usesWidgetDesign ? SystemWidgetLayout.factColumns(kind) : 3
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: min(list.count, columns)),
                         alignment: .leading, spacing: SystemWidgetLayout.factRowSpacing) {
            ForEach(list, id: \.0) { fact in
                VStack(alignment: .leading, spacing: 2) {
                    Text(fact.0)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.54, green: 0.54, blue: 0.58))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(fact.1)
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                        if isWidgetEnergy, let sub = fact.2 {
                            Text(sub)
                                .font(.system(size: 10.5))
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        if let copyVal = fact.3 {
                            CopyButton(value: copyVal)
                        }
                    }
                    if !isWidgetEnergy, let sub = fact.2 {
                        Text(sub)
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color(red: 0.44, green: 0.44, blue: 0.47))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: fitsIsland ? SystemWidgetLayout.factRowHeight : nil)
            }
        }
        .padding(.vertical, fitsIsland ? 0 : 4)
        .padding(.horizontal, 4)
    }

    private var processCard: some View {
        VStack(alignment: .leading, spacing: SystemWidgetLayout.processSpacing) {
            HStack {
                Text(processCardHeaderTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 0.54, green: 0.54, blue: 0.58))
                Spacer()
                if processRows.count > 3 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            navigation.showMoreProcesses.toggle()
                            if fitsIsland { NotchService.shared.refreshPresentation() }
                        }
                    } label: {
                        Text(navigation.showMoreProcesses ? "Show less" : "Show more")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(usesWidgetDesign ? (colorScheme == .dark ? Color.white : Color.accentColor) : Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: SystemWidgetLayout.processHeaderHeight)
            VStack(spacing: 0) {
                if processRowsLoading {
                    VStack(spacing: 0) {
                        ForEach(0..<navigation.displayedProcessCount, id: \.self) { _ in
                            ProcessRowSkeleton()
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(l10n.s.breakdownMeasuring)
                } else if processRows.isEmpty {
                    Text(emptyProcessText)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 0.44, green: 0.44, blue: 0.47))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: SystemWidgetLayout.processRowHeight)
                } else {
                    ForEach(processRows.prefix(navigation.processDisplayLimit)) { row in
                        ProcessUsageRow(row: row, value: processValue(row))
                            .frame(height: SystemWidgetLayout.processRowHeight)
                    }
                }
            }
        }
        .padding(SystemWidgetLayout.processInset)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 0.06, green: 0.06, blue: 0.07) : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

private struct ProcessRowSkeleton: View {
    @State private var pulse = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill((colorScheme == .dark ? Color.white : Color.primary).opacity(pulse ? 0.12 : 0.05))
                .frame(width: 16, height: 16)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill((colorScheme == .dark ? Color.white : Color.primary).opacity(pulse ? 0.10 : 0.04))
                .frame(width: 90, height: 11)
            Spacer()
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill((colorScheme == .dark ? Color.white : Color.primary).opacity(pulse ? 0.08 : 0.03))
                .frame(width: 40, height: 11)
        }
        .frame(height: SystemWidgetLayout.processRowHeight)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

    private var speedTestRowButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                navigation.showingSpeedTest = true
                if fitsIsland { NotchService.shared.refreshPresentation() }
            }
            speed.start()
        } label: {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "powermeter")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Speed test")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(colorScheme == .dark ? Color(white: 0.95) : Color.primary)
                Spacer()
                if let down = speed.downloadMbps, let up = speed.uploadMbps {
                    Text("↓ \(Int(down.rounded())) · ↑ \(Int(up.rounded())) Mbps")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(colorScheme == .dark ? Color(red: 0.63, green: 0.63, blue: 0.66) : Color.secondary)
                } else {
                    Text("Run")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(colorScheme == .dark ? Color(red: 0.63, green: 0.63, blue: 0.66) : Color.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(colorScheme == .dark ? Color(red: 0.06, green: 0.06, blue: 0.07) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var speedTestView: some View {
        VStack(alignment: .leading, spacing: SystemWidgetLayout.spacing) {
            // Hero
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    let isUpload = speed.phase == .upload
                    Text(isUpload ? "↑" : "↓")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(isUpload ? Color(red: 0.19, green: 0.82, blue: 0.35) : Color(red: 0.37, green: 0.66, blue: 1.0))
                    let rateStr: String = {
                        if speed.isRunning {
                            if speed.phase == .latency { return "—" }
                            return "\(Int(speed.liveMbps.rounded()))"
                        }
                        if let dl = speed.downloadMbps { return "\(Int(dl.rounded()))" }
                        return "0"
                    }()
                    Text(rateStr)
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    if speed.phase != .latency {
                        Text("Mbps")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(Color(red: 0.63, green: 0.63, blue: 0.66))
                    }
                }
                Text(speedStatusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 0.63, green: 0.63, blue: 0.66))
                    .padding(.leading, 34)
                    .lineLimit(2)
            }
            .frame(height: SystemWidgetLayout.speedHeroHeight, alignment: .topLeading)

            // Graph & Progress
            VStack(spacing: 6) {
                speedTestGraph
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(red: 0.15, green: 0.15, blue: 0.17))
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(red: 0.37, green: 0.66, blue: 1.0))
                            .frame(width: geo.size.width * speedProgress)
                            .animation(.linear(duration: 0.2), value: speedProgress)
                    }
                }
                .frame(height: 3)
            }
            .frame(height: SystemWidgetLayout.speedGraphHeight)

            // Stats row (Latency, Download, Upload)
            HStack {
                speedStatBlock(title: "Latency", value: speed.latencyMs.map { "\(Int($0.rounded())) ms" } ?? "—", isActive: speed.phase == .latency)
                Spacer()
                speedStatBlock(title: "Download", value: speed.downloadMbps.map { "\(Int($0.rounded())) Mbps" } ?? "—", isActive: speed.phase == .download)
                Spacer()
                speedStatBlock(title: "Upload", value: speed.uploadMbps.map { "\(Int($0.rounded())) Mbps" } ?? "—", isActive: speed.phase == .upload)
            }
            .padding(.horizontal, 4)
            .frame(height: SystemWidgetLayout.factRowHeight)

            // Buttons
            HStack(spacing: 8) {
                if speed.isRunning {
                    Button {
                        speed.cancel()
                        withAnimation(.easeInOut(duration: 0.22)) {
                            navigation.showingSpeedTest = false
                            if fitsIsland { NotchService.shared.refreshPresentation() }
                        }
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(colorScheme == .dark ? Color(red: 0.06, green: 0.06, blue: 0.07) : Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        speed.start()
                    } label: {
                        Text("Run again")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(colorScheme == .dark ? Color(white: 0.95) : Color.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: SystemWidgetLayout.speedButtonHeight)
        }
        .padding(.horizontal, 4)
    }

    private var speedStatusText: String {
        switch speed.phase {
        case .idle:
            return "Ready to test"
        case .latency:
            return "Finding the fastest server…"
        case .download:
            return "Testing download"
        case .upload:
            return "Testing upload"
        case .done:
            return "Test complete"
        case .failed(let msg):
            return msg.isEmpty ? "Speed test failed" : msg
        }
    }

    private var speedProgress: Double {
        speed.phaseProgress
    }

    private func speedStatBlock(title: String, value: String, isActive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(isActive ? Color(red: 0.37, green: 0.66, blue: 1.0) : Color(red: 0.54, green: 0.54, blue: 0.58))
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
        }
    }

    private var speedTestGraph: some View {
        let dl = speed.downloadPoints.count >= 2 ? speed.downloadPoints : (speed.phase == .download ? [0, speed.liveMbps] : (speed.downloadMbps != nil ? [speed.downloadMbps!, speed.downloadMbps!] : [0, 0]))
        let ul = speed.uploadPoints.count >= 2 ? speed.uploadPoints : (speed.phase == .upload ? [0, speed.liveMbps] : (speed.uploadMbps != nil ? [speed.uploadMbps!, speed.uploadMbps!] : [0, 0]))
        let peak = max(50, (dl + ul).max() ?? 50) * 1.15
        return ZStack {
            Sparkline(values: dl,
                      color: Color(red: 0.37, green: 0.66, blue: 1.0),
                      maxValue: peak,
                      fillOpacity: 0.30,
                      lineWidth: 2,
                      showsZeroBaseline: !usesWidgetDesign)
            Sparkline(values: ul,
                      color: Color(red: 0.19, green: 0.82, blue: 0.35),
                      maxValue: peak,
                      fillOpacity: 0.20,
                      lineWidth: 1.5,
                      showsZeroBaseline: !usesWidgetDesign)
        }
        .frame(height: SystemWidgetLayout.graphHeight)
        .graphCeilingLabel("\(Int(peak.rounded())) Mbps")
    }

    @ViewBuilder
    private var moreDetailsSection: some View {
        let details = moreDetails
        if !details.isEmpty {
            VStack(alignment: .leading, spacing: navigation.showMoreDetails ? SystemWidgetLayout.detailsSpacing : 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        navigation.showMoreDetails.toggle()
                        if fitsIsland { NotchService.shared.refreshPresentation() }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text("More details")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .rotationEffect(.degrees(navigation.showMoreDetails ? 90 : 0))
                    }
                    .foregroundStyle(Color(red: 0.63, green: 0.63, blue: 0.66))
                    .frame(height: SystemWidgetLayout.detailsButtonHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                HubAccordion(isExpanded: navigation.showMoreDetails) {
                    VStack(spacing: SystemWidgetLayout.detailsRowSpacing) {
                        ForEach(details, id: \.0) { item in
                            HStack {
                                Text(item.0)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(red: 0.63, green: 0.63, blue: 0.66))
                                Spacer()
                                Text(item.1)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                    .monospacedDigit()
                            }
                            .lineLimit(1)
                            .frame(height: SystemWidgetLayout.detailsRowHeight)
                        }
                    }
                    .padding(SystemWidgetLayout.detailsInset)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(colorScheme == .dark ? Color(red: 0.06, green: 0.06, blue: 0.07) : Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var facts: [(String, String, String?, String?)] {
        let snapshot = monitor.snapshot
        if isWidgetEnergy {
            return SystemWidgetDetailContent.energyFacts(power: snapshot.power, hasBattery: !isDesktopEnergy,
                                                         temperature: snapshot.batteryTemperature.map(formatTemperature))
        }
        if !usesWidgetDesign, let legacy = menuPanelFacts(snapshot) { return legacy }
        switch kind {
        case .cpu:
            return [
                ("CPU temp", snapshot.cpuTemperature.map(formatTemperature) ?? "-", nil, nil),
                ("Performance", coreUsage("Performance"), nil, nil),
                ("Efficiency", coreUsage("Efficiency"), nil, nil)
            ]
        case .gpu:
            return [
                ("GPU temp", snapshot.gpuTemperature.map(formatTemperature) ?? "-", nil, nil),
                ("GPU power", snapshot.gpuWatts.map(MetricFormat.watts) ?? "-", nil, nil),
                ("Frequency", snapshot.gpuFrequencyMHz.map { "\(Int($0.rounded())) MHz" } ?? "-", nil, nil)
            ]
        case .memory:
            return [
                ("App memory", snapshot.memoryAppUsed.map(formatMemory) ?? "-", nil, nil),
                ("Wired", snapshot.memoryWired.map(formatMemory) ?? "-", nil, nil),
                ("Compressed", snapshot.memoryCompressed.map(formatMemory) ?? "-", nil, nil),
                ("Swap", snapshot.memorySwapUsed.map(formatMemory) ?? "-", nil, nil)
            ]
        case .battery:
            let power = snapshot.power
            return [
                ("Charger", power?.externalConnected == true ? (power?.adapterWatts.map(MetricFormat.watts) ?? "Connected") : "None", nil, nil),
                ("Battery", power?.batteryWatts.map(MetricFormat.watts) ?? batteryFlowText(power), nil, nil),
                ("System", power?.systemWatts.map(MetricFormat.watts) ?? "-", nil, nil)
            ]
        case .network:
            var list: [(String, String, String?, String?)] = []
            let pub = addressService.publicIP ?? (addressService.isLoadingPublicIP ? "…" : "—")
            list.append(("Public IP", pub, nil, addressService.publicIP))

            let addrs = NetworkAddressService.readLocalAddresses()
            let ifaceName: String
            let fullLocalIP: String
            if let local = addrs.first {
                let parts = local.components(separatedBy: " ")
                fullLocalIP = parts.first ?? local
                ifaceName = local.contains("(") ? (local.components(separatedBy: "(").last?.replacingOccurrences(of: ")", with: "") ?? "Wi-Fi") : "Wi-Fi"
            } else {
                fullLocalIP = "127.0.0.1"
                ifaceName = "Wi-Fi"
            }
            let suffix = "." + (fullLocalIP.components(separatedBy: ".").last ?? fullLocalIP)
            list.append(("Local IP (\(ifaceName))", suffix, nil, fullLocalIP))
            return list
        case .disk:
            var list: [(String, String, String?, String?)] = []
            let isAPFS = currentDisk?.fileSystem?.localizedCaseInsensitiveContains("apfs") == true
            if isAPFS, let purgeable = currentDisk?.purgeableBytes {
                list.append(("Purgeable", MetricFormat.diskBytes(purgeable), nil, nil))
            }
            if let smart = currentDisk?.smart {
                if let cycles = smart.powerCycles {
                    list.append(("Disk cycle count", cycles.formatted(), nil, nil))
                }
                if let hours = smart.powerOnHours {
                    list.append(("Power-on hours", hours.formatted() + " h", nil, nil))
                }
            }
            return list
        case .power:
            return [
                ("System", snapshot.power?.systemWatts.map(MetricFormat.watts) ?? "-", nil, nil),
                ("Adapter", adapterText(snapshot.power), nil, nil),
                ("Battery", batteryFlowText(snapshot.power), nil, nil)
            ]
        case .fan:
            return snapshot.fanSpeeds.enumerated().map { index, rpm in
                ("Fan \(index + 1)", "\(Int(rpm.rounded())) RPM", nil, nil)
            }
        case .connectedDevices:
            return snapshot.connectedDevices.prefix(3).map { device in
                (device.name.isEmpty ? "Device" : device.name, device.vendorName ?? "USB", nil, nil)
            }
        }
    }

    private func menuPanelFacts(_ snapshot: SystemSnapshot) -> [(String, String, String?, String?)]? {
        switch kind {
        case .cpu:
            return [("Temp", snapshot.cpuTemperature.map(formatTemperature) ?? "-", nil, nil),
                    ("Performance", snapshot.cpuUsage.map(MetricFormat.percent) ?? "-", nil, nil),
                    ("Uptime", SystemInfo.uptimeString(), nil, nil)]
        case .gpu:
            return [("Temp", snapshot.gpuTemperature.map(formatTemperature) ?? "-", nil, nil),
                    ("Top app", processRows.first?.name ?? "-", nil, nil),
                    ("Usage", snapshot.gpuUsage.map(MetricFormat.percent) ?? "-", nil, nil)]
        case .memory:
            let pressure: String
            switch snapshot.memoryPressure {
            case .normal: pressure = l10n.s.pressureNormal
            case .warning: pressure = l10n.s.pressureWarning
            case .critical: pressure = l10n.s.pressureCritical
            case .unknown: pressure = "-"
            }
            return [("Pressure", pressure, nil, nil),
                    ("Compressed", snapshot.memoryCompressed.map(formatMemory) ?? "-", nil, nil),
                    ("Cached", snapshot.memoryCached.map(formatMemory) ?? "-", nil, nil),
                    ("Swap", snapshot.memorySwapUsed.map(formatMemory) ?? "-", nil, nil)]
        default:
            return nil
        }
    }

    private var moreDetails: [(String, String)] {
        let snapshot = monitor.snapshot
        if !usesWidgetDesign {
            switch kind {
            case .cpu:
                #if arch(arm64)
                let architecture = "Apple Silicon"
                #else
                let architecture = "Intel (x86_64)"
                #endif
                return [("Cores", "\(ProcessInfo.processInfo.processorCount) cores"),
                        ("Active cores", "\(ProcessInfo.processInfo.activeProcessorCount) cores"),
                        ("Architecture", architecture)]
            case .gpu:
                return [("Renderer", SystemWidgetHardware.gpu.model ?? l10n.s.gpuLabel)]
            case .memory:
                var details: [(String, String)] = []
                if let wired = snapshot.memoryWired { details.append(("Wired", formatMemory(wired))) }
                if let swap = snapshot.memorySwapUsed { details.append(("Swap used", formatMemory(swap))) }
                return details
            default:
                break
            }
        }
        return SystemWidgetDetailContent.detailRows(for: kind, snapshot: snapshot, disk: currentDisk,
                                                    widgetDesign: usesWidgetDesign, formatTemperature: formatTemperature)
    }

    private var heroPrimaryValue: String {
        let snapshot = monitor.snapshot
        if isWidgetEnergy {
            return isDesktopEnergy
                ? snapshot.power?.systemWatts.map { String(format: "%.0f", locale: MetricFormat.locale, $0) } ?? "-"
                : snapshot.power?.chargePercent.map { "\($0)%" } ?? "-"
        }
        switch kind {
        case .cpu:
            return snapshot.cpuUsage.map(MetricFormat.percent) ?? "-"
        case .gpu:
            return snapshot.gpuUsage.map(MetricFormat.percent) ?? "-"
        case .memory:
            return memoryRatio.map(MetricFormat.percent) ?? "-"
        case .network:
            let down = snapshot.netDownBytesPerSec ?? 0
            let inBits = speedUnit == .bits
            return "↓ " + MetricFormat.networkRateCompact(down, inBits: inBits)
        case .disk:
            return currentDisk.map { MetricFormat.percent($0.usedFraction) } ?? "-"
        case .battery:
            if PowerSampler.hasInternalBattery {
                return snapshot.power?.chargePercent.map { "\($0)%" } ?? "-"
            }
            return PeripheralBatterySupport.sorted(snapshot.peripheralBatteries).first
                .map { "\($0.percent)%" } ?? "-"
        case .power:
            return snapshot.power?.systemWatts.map(MetricFormat.wattsCompact) ?? "-"
        case .fan:
            guard let rpm = snapshot.fanSpeeds.first else { return "-" }
            return String(format: FeatureStrings.fanControl(l10n.language).rpmFormat, Int(rpm.rounded()))
        case .connectedDevices:
            return "\(snapshot.connectedDevices.count)"
        }
    }

    private var heroSubtitle: String {
        let snapshot = monitor.snapshot
        if isWidgetEnergy {
            return isDesktopEnergy ? "Plugged in" : SystemWidgetDetailContent.batterySubtitle(snapshot.power)
        }
        switch kind {
        case .cpu:
            if !usesWidgetDesign {
                let cores = "\(ProcessInfo.processInfo.activeProcessorCount) cores"
                return snapshot.cpuTemperature.map { "\(formatTemperature($0)) · \(cores)" } ?? cores
            }
            let model = SystemWidgetHardware.cpuModel ?? l10n.s.cpuLabel
            return "\(model) • \(SystemWidgetHardware.cpuCoreCount) cores"
        case .gpu:
            if !usesWidgetDesign { return snapshot.gpuTemperature.map(formatTemperature) ?? l10n.s.gpuLabel }
            let hardware = SystemWidgetHardware.gpu
            let model = hardware.model ?? l10n.s.gpuLabel
            return hardware.coreCount.map { "\(model) • \($0) cores" } ?? model
        case .memory:
            let used = snapshot.memoryUsed ?? 0
            let total = snapshot.memoryTotal ?? 0
            return "\(formatMemory(used)) of \(formatMemory(total))"
        case .network:
            let up = snapshot.netUpBytesPerSec ?? 0
            let inBits = speedUnit == .bits
            return "KB/s · ↑ \(MetricFormat.networkRateCompact(up, inBits: inBits)) · Active"
        case .disk:
            guard let disk = currentDisk else { return l10n.s.diskNoDisks }
            let capacity = "\(MetricFormat.diskBytes(disk.freeBytes)) free of \(MetricFormat.diskBytes(disk.totalBytes))"
            if let fs = disk.fileSystem, !fs.isEmpty {
                return "\(capacity) · \(fs)"
            }
            return capacity
        case .battery:
            guard let power = snapshot.power, power.hasBattery else {
                return powerSubtitle(snapshot.power)
            }
            let charge = Double(power.chargePercent ?? 100) / 100.0
            let mins = power.timeRemainingSeconds.map { max(1, Int(round($0 / 60))) }
                ?? (power.isCharging ? max(1, Int(round((1.0 - charge) * 90))) : max(1, Int(round(charge * 140))))
            if power.isCharging {
                return "Charging · \(mins) min to full"
            } else if power.externalConnected {
                return (power.chargePercent ?? 0) >= 100 ? "Connected · Fully Charged" : "Connected · Not Charging"
            } else {
                return "On battery · \(mins) min left"
            }
        case .power:
            return powerSubtitle(snapshot.power)
        case .fan:
            let strings = FeatureStrings.fanControl(l10n.language)
            return snapshot.fanSpeeds.isEmpty ? strings.menuBarTitle : String(format: strings.fanNameFormat, 1)
        case .connectedDevices:
            return FeatureStrings.connectedDevices(l10n.language).formattedCount(snapshot.connectedDevices.count)
        }
    }

    private var heroAuxLines: [String]? {
        guard !isWidgetEnergy, kind == .battery, let power = monitor.snapshot.power, power.hasBattery else { return nil }
        var lines: [String] = []
        if let health = power.healthPercent {
            lines.append("Health \(Int(health.rounded()))%")
        }
        if let cycles = power.cycleCount {
            lines.append("\(cycles) cycles")
        }
        return lines.isEmpty ? nil : lines
    }

    private var graphUnit: String {
        if isWidgetEnergy { return isDesktopEnergy ? "Power draw, last hour" : "Last hour" }
        switch kind {
        case .cpu, .gpu:
            return "Last \(UsageMetricHistory.windowSeconds) s"
        case .memory:
            return "Last 60 s"
        case .battery:
            return "Last hour"
        case .network:
            let down = monitor.snapshot.netDownHistory
            let up = monitor.snapshot.netUpHistory
            let peak = max(down.max() ?? 0, up.max() ?? 0, 1024)
            return "\(MetricFormat.networkRateCompact(peak, inBits: speedUnit == .bits)) scale"
        case .disk:
            return "Read / write"
        case .power:
            let peak = monitor.snapshot.systemPowerHistory.max() ?? 0
            return "\(MetricFormat.watts(peak)) scale"
        case .fan, .connectedDevices:
            return ""
        }
    }

    private var emptyProcessText: String {
        if isWidgetEnergy { return "No app CPU power readings" }
        switch kind {
        case .power, .battery: return l10n.s.energyAppsIdle
        case .network: return l10n.s.networkAppsIdle
        case .disk: return "No disk activity"
        default: return "No apps to show"
        }
    }

    private var processCardHeaderTitle: String {
        if isWidgetEnergy { return "CPU power by app" }
        switch kind {
        case .cpu: return "Using CPU"
        case .gpu: return "Using GPU"
        case .memory: return "Using memory"
        case .battery, .power: return "Using energy"
        case .network: return "Using network"
        case .disk: return "Using disk"
        case .fan, .connectedDevices: return "Processes"
        }
    }

    private func refreshProcessRows(force: Bool, delay: TimeInterval = 0) {
        guard let processKind else { return }
        let service = ProcessUsageService.shared
        if force {
            let cached = service.cachedTop(processKind, limit: processLimit)
            let warmingNetwork = processKind == .network && service.networkMonitoringIsWarmingUp
            updateProcessRows(cached ?? [], loading: cached == nil || (cached?.isEmpty == true && warmingNetwork))
        }
        guard force || Date().timeIntervalSince(lastProcessRefresh) >= processKind.processRefreshInterval(
            configuredMonitorInterval: monitorInterval
        ) * 0.8
        else { return }

        refreshSerial &+= 1
        let serial = refreshSerial
        let sampleInterval = percentageSampleInterval
        let cpuPercentage = monitor.snapshot.cpuUsage.map { $0 * 100 }
        let gpuPercentage = monitor.snapshot.gpuUsage.map { $0 * 100 }
        let run = {
            guard self.refreshSerial == serial,
                  self.processKind == processKind else { return }
            self.lastProcessRefresh = Date()
            DispatchQueue.global(qos: .utility).async {
                let rows = service.top(processKind, limit: self.processLimit,
                                       sampleInterval: sampleInterval,
                                       cpuPercentage: cpuPercentage,
                                       gpuPercentage: gpuPercentage)
                // CPU and GPU can return an empty array while establishing a
                // baseline. A cached empty sample means measuring finished.
                let warmingNetwork = processKind == .network && service.networkMonitoringIsWarmingUp
                let loading = rows.isEmpty && (processKind == .network
                    ? warmingNetwork
                    : service.cachedTop(processKind, limit: 1) == nil)
                DispatchQueue.main.async {
                    guard self.refreshSerial == serial,
                          self.processKind == processKind,
                          !self.usesWidgetDesign || self.navigation.selectedMetric == self.kind else { return }
                    self.updateProcessRows(rows, loading: loading)
                    if rows.isEmpty && warmingNetwork {
                        self.refreshProcessRows(force: true, delay: 1.0)
                    }
                }
            }
        }
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: run)
        } else {
            run()
        }
    }

    private func updateProcessRows(_ rows: [ProcessUsage], loading: Bool) {
        processRows = rows
        processRowsLoading = loading
        navigation.updateProcessCount(rows.count, loading: loading)
    }

    private var percentageSampleInterval: TimeInterval {
        TimeInterval(Defaults.sanitizedMonitorInterval(monitorInterval))
    }

    private func startNetworkMonitoringIfNeeded() {
        guard !networkMonitoringActive else { return }
        networkMonitoringActive = true
        ProcessUsageService.shared.startNetworkMonitoring()
    }

    private func stopNetworkMonitoringIfNeeded() {
        guard networkMonitoringActive else { return }
        networkMonitoringActive = false
        ProcessUsageService.shared.stopNetworkMonitoring()
    }

    private func processValue(_ row: ProcessUsage) -> String {
        if isWidgetEnergy {
            return row.value < 1
                ? String(format: "%.0f mW", locale: MetricFormat.locale, row.value * 1000)
                : MetricFormat.watts(row.value)
        }
        switch kind {
        case .memory:
            return formatMemory(UInt64(row.value))
        case .network:
            let down = row.networkDownBytesPerSec ?? 0
            let up = row.networkUpBytesPerSec ?? 0
            return "↓\(MetricFormat.networkRateCompact(down)) ↑\(MetricFormat.networkRateCompact(up))"
        case .disk:
            return MetricFormat.bytesPerSec(row.value)
        default:
            return String(format: "%.1f%%", locale: MetricFormat.locale, row.value)
        }
    }

    private func primaryDisk(from reading: DiskReading?) -> DiskDeviceReading? {
        guard let devices = reading?.devices, !devices.isEmpty else { return nil }
        return devices.first(where: { $0.isInternal }) ?? devices.first
    }

    private func diskActivity(from reading: DiskReading?) -> (read: Double, write: Double)? {
        let devices = reading?.uniqueIODevices ?? []
        guard !devices.isEmpty else { return nil }
        let readValues = devices.compactMap(\.readBytesPerSec)
        let writeValues = devices.compactMap(\.writeBytesPerSec)
        guard !readValues.isEmpty || !writeValues.isEmpty else { return nil }
        return (readValues.reduce(0, +), writeValues.reduce(0, +))
    }

    private func formatTemperature(_ celsius: Double) -> String {
        MetricFormat.temperature(celsius, unit: displayTemperatureUnit)
    }

    private var displayTemperatureUnit: TemperatureUnit {
        TemperatureUnit(rawValue: temperatureUnit) ?? .celsius
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        Self.memoryFormatter.string(fromByteCount: Int64(bytes))
    }

    private var memoryRatio: Double? {
        let snapshot = monitor.snapshot
        guard let used = snapshot.memoryUsed, let total = snapshot.memoryTotal, total > 0 else { return nil }
        return Double(used) / Double(total)
    }

    private func coreUsage(_ name: String) -> String {
        SystemWidgetHardware.coreUsage(name, readings: monitor.snapshot.cpuCoreUsage)
            .map(MetricFormat.percent) ?? "-"
    }

    private func sessionNetworkText(_ snapshot: SystemSnapshot) -> String {
        guard let down = snapshot.netTotalDown, let up = snapshot.netTotalUp else { return "-" }
        return "↓\(MetricFormat.bytes(down))  ↑\(MetricFormat.bytes(up))"
    }

    private func adapterText(_ power: PowerReading?) -> String {
        guard let power else { return "-" }
        if power.externalConnected, let adapter = power.adapterWatts {
            return MetricFormat.watts(adapter)
        }
        if power.externalConnected { return l10n.s.powerPluggedIn }
        return "-"
    }

    private func batteryFlowText(_ power: PowerReading?) -> String {
        guard let flow = power?.batteryWatts else { return "-" }
        let label = flow >= 0 ? l10n.s.powerCharging : l10n.s.powerOnBattery
        return "\(MetricFormat.watts(abs(flow))) · \(label)"
    }

    private func powerSubtitle(_ power: PowerReading?) -> String {
        guard let power else { return l10n.s.powerUnavailable }
        if power.externalConnected { return l10n.s.powerPluggedIn }
        if power.hasBattery { return l10n.s.powerOnBattery }
        return l10n.s.powerUnavailable
    }

    private func powerStateText(_ state: BatteryPowerSupport.State) -> String {
        switch state {
        case .charging: return l10n.s.powerCharging
        case .externalPower: return l10n.s.powerPluggedIn
        case .onBattery: return l10n.s.powerOnBattery
        case .unavailable: return l10n.s.powerUnavailable
        }
    }

    private func mbps(_ value: Double) -> String {
        value >= 100 ? String(format: "%.0f", locale: MetricFormat.locale, value)
                     : String(format: "%.1f", locale: MetricFormat.locale, value)
    }

    private static let memoryFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter
    }()
}

private struct CopyButton: View {
    let value: String
    @State private var copied = false
    @State private var copyTask: Task<Void, Never>?

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            copied = true
            copyTask?.cancel()
            copyTask = Task {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                copied = false
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "square.on.square")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(copied ? Color(red: 0.19, green: 0.82, blue: 0.35) : Color(red: 0.54, green: 0.54, blue: 0.58))
        }
        .buttonStyle(.plain)
        .help(copied ? "Copied" : "Copy")
    }
}
