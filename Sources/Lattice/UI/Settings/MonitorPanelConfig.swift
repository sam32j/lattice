// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Panel configuration tiles, with one master per block and per-item options.
struct MonitorPanelConfig: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var l10n = L10n.shared
    @State private var selectedBlock: PanelConfigBlock?

    @AppStorage(DefaultsKey.monitorShowSystem) private var showSystem = true
    @AppStorage(DefaultsKey.monitorSysTemps) private var sysTemps = true
    @AppStorage(DefaultsKey.monitorSysCPU) private var sysCPU = true
    @AppStorage(DefaultsKey.monitorSysCPUCores) private var sysCPUCores = true
    @AppStorage(DefaultsKey.monitorSysGPU) private var sysGPU = true
    @AppStorage(DefaultsKey.monitorPwrTemperature) private var pwrTemperature = true
    @AppStorage(DefaultsKey.monitorSysBattery) private var sysBattery = true
    @AppStorage(DefaultsKey.monitorSysMemory) private var sysMemory = true
    @AppStorage(DefaultsKey.monitorSysUptime) private var sysUptime = true
    @AppStorage(DefaultsKey.monitorSysConnectedDevices) private var sysConnectedDevices = true

    @AppStorage(DefaultsKey.monitorShowNetwork) private var showNetwork = true
    @AppStorage(DefaultsKey.monitorNetSpeed) private var netSpeed = true
    @AppStorage(DefaultsKey.monitorNetApps) private var netApps = true
    @AppStorage(DefaultsKey.monitorNetTotals) private var netTotals = true
    @AppStorage(DefaultsKey.monitorNetTest) private var netTest = true
    @AppStorage(DefaultsKey.monitorNetAddresses) private var netAddresses = true

    @AppStorage(DefaultsKey.monitorShowDisk) private var showDisk = true
    @AppStorage(DefaultsKey.monitorDiskUsage) private var diskUsage = true
    @AppStorage(DefaultsKey.monitorDiskActivity) private var diskActivity = true
    @AppStorage(DefaultsKey.monitorDiskSMART) private var diskSMART = true
    @AppStorage(DefaultsKey.monitorDiskProtection) private var diskProtection = true
    @AppStorage(DefaultsKey.monitorDiskTools) private var diskTools = true

    @AppStorage(DefaultsKey.monitorShowPower) private var showPower = true
    @AppStorage(DefaultsKey.monitorPwrSystem) private var pwrSystem = true
    @AppStorage(DefaultsKey.monitorPwrAdapter) private var pwrAdapter = true
    @AppStorage(DefaultsKey.monitorPwrBattery) private var pwrBattery = true
    @AppStorage(DefaultsKey.monitorPwrTimeRemaining) private var pwrTimeRemaining = true
    @AppStorage(DefaultsKey.monitorPwrHealth) private var pwrHealth = true

    @AppStorage(DefaultsKey.monitorShowMixer) private var showMixer = true

    @AppStorage(DefaultsKey.monitorGraphCPU) private var graphCPU = true
    @AppStorage(DefaultsKey.monitorGraphGPU) private var graphGPU = true
    @AppStorage(DefaultsKey.monitorGraphMemory) private var graphMemory = true
    @AppStorage(DefaultsKey.monitorGraphNetwork) private var graphNetwork = true
    @AppStorage(DefaultsKey.monitorGraphDisk) private var graphDisk = true
    @AppStorage(DefaultsKey.monitorGraphPower) private var graphPower = true
    @AppStorage(DefaultsKey.monitorGraphBattery) private var graphBattery = true

    var body: some View {
        tileLayout
    }

    // MARK: - Tiles

    private var availableBlocks: [PanelConfigBlock] {
        PanelConfigBlock.allCases.filter { $0.section.isAvailable }
    }

    private var currentBlock: PanelConfigBlock? {
        let blocks = availableBlocks
        if let selectedBlock, blocks.contains(selectedBlock) { return selectedBlock }
        return blocks.first
    }

    private var tileLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 175), spacing: 10)], spacing: 10) {
                ForEach(availableBlocks, id: \.self) { block in
                    MonitorToken(symbol: block.section.symbolName,
                                 title: block.section.title(l10n.s),
                                 included: master(block),
                                 selected: currentBlock == block,
                                 large: true) {
                        withAnimation(reduceMotion ? nil : .settingsExpansion) {
                            selectedBlock = block
                        }
                    }
                }
            }
            if let block = currentBlock, block != .mixer {
                Text(block.section.title(l10n.s))
                    .font(.subheadline.weight(.medium))
                LazyVGrid(columns: monitorLargeTokenColumns, spacing: 10) {
                    itemTiles(for: block)
                }
                .monitorTokenGroup()
            }
        }
    }

    private func master(_ block: PanelConfigBlock) -> Binding<Bool> {
        switch block {
        case .system: return $showSystem
        case .network: return $showNetwork
        case .disk: return $showDisk
        case .power: return $showPower
        case .mixer: return $showMixer
        }
    }

    /// The block's items as tiles, greyed while the whole block is hidden.
    @ViewBuilder
    private func itemTiles(for block: PanelConfigBlock) -> some View {
        let available = master(block).wrappedValue
        switch block {
        case .system:
            if AppFeature.monitorCPU.isAvailable || AppFeature.monitorGPU.isAvailable {
                itemTile(l10n.s.temperatures, symbol: "thermometer.medium", value: $sysTemps, available: available)
            }
            if AppFeature.monitorCPU.isAvailable {
                itemTile(l10n.s.cpuLabel, symbol: MenuBarMetric.cpu.symbolName, value: $sysCPU, available: available,
                         options: AnyView(VStack(spacing: 10) {
                             chartOption($graphCPU)
                             MonitorTokenOption(symbol: "square.grid.3x2",
                                                title: FeatureStrings.cpuCores(l10n.language).perCore,
                                                isOn: $sysCPUCores)
                         }),
                         summary: summary([(l10n.s.monitorGraphsSection, graphCPU),
                                           (FeatureStrings.cpuCores(l10n.language).perCore, sysCPUCores)]))
            }
            if AppFeature.monitorGPU.isAvailable {
                itemTile(l10n.s.gpuLabel, symbol: MenuBarMetric.gpu.symbolName, value: $sysGPU, available: available,
                         options: AnyView(chartOption($graphGPU)), summary: chartSummary(graphGPU))
            }
            if AppFeature.monitorMemory.isAvailable {
                itemTile(l10n.s.memorySection, symbol: MenuBarMetric.memory.symbolName, value: $sysMemory, available: available,
                         options: AnyView(chartOption($graphMemory)), summary: chartSummary(graphMemory))
            }
            itemTile(l10n.s.monitorItemUptime, symbol: "clock", value: $sysUptime, available: available)
            if AppFeature.connectedDevices.isAvailable {
                itemTile(FeatureStrings.connectedDevices(l10n.language).title, symbol: "cable.connector",
                         value: $sysConnectedDevices, available: available)
            }
        case .network:
            itemTile(l10n.s.monitorItemNetSpeed, symbol: "speedometer", value: $netSpeed, available: available,
                     options: AnyView(chartOption($graphNetwork)), summary: chartSummary(graphNetwork))
            itemTile(l10n.s.networkApps, symbol: "app.badge", value: $netApps, available: available)
            itemTile(l10n.s.monitorItemNetTotals, symbol: "sum", value: $netTotals, available: available)
            itemTile(l10n.s.networkIPAddresses, symbol: "network", value: $netAddresses, available: available)
            itemTile(l10n.s.monitorItemNetTest, symbol: "gauge.with.needle", value: $netTest, available: available)
        case .disk:
            itemTile(l10n.s.monitorItemDiskUsage, symbol: "internaldrive", value: $diskUsage, available: available)
            itemTile(l10n.s.monitorItemDiskActivity, symbol: "arrow.up.arrow.down", value: $diskActivity, available: available,
                     options: AnyView(chartOption($graphDisk)), summary: chartSummary(graphDisk))
            itemTile(l10n.s.monitorItemDiskSMART, symbol: "heart.text.square", value: $diskSMART, available: available)
            itemTile(l10n.s.monitorItemDiskProtection, symbol: "shield", value: $diskProtection, available: available)
            itemTile(l10n.s.monitorItemDiskTools, symbol: "wrench.and.screwdriver", value: $diskTools, available: available)
        case .power:
            itemTile(l10n.s.powerSystem, symbol: "bolt", value: $pwrSystem, available: available,
                     options: AnyView(chartOption($graphPower)), summary: chartSummary(graphPower))
            itemTile(l10n.s.powerAdapter, symbol: "powerplug", value: $pwrAdapter, available: available)
            if PowerSampler.hasInternalBattery {
                itemTile(l10n.s.batteryCharge, symbol: "battery.75percent", value: $sysBattery, available: available,
                         options: AnyView(chartOption($graphBattery)), summary: chartSummary(graphBattery))
                itemTile(l10n.s.powerBattery, symbol: "battery.100percent.bolt", value: $pwrBattery, available: available)
                itemTile(FeatureStrings.batteryTime(l10n.language).title, symbol: "clock", value: $pwrTimeRemaining,
                         available: available)
                itemTile(l10n.s.monitorShowBatteryTemperature, symbol: "thermometer.medium", value: $pwrTemperature,
                         available: available)
                itemTile(l10n.s.powerHealth, symbol: "heart", value: $pwrHealth, available: available)
            }
        case .mixer:
            EmptyView()
        }
    }

    private func itemTile(_ title: String, symbol: String, value: Binding<Bool>, available: Bool,
                          options: AnyView? = nil, summary: String = "") -> some View {
        MonitorToken(symbol: symbol, title: title, included: value, available: available,
                     options: options, optionsSummary: summary, large: true)
    }

    /// The names of the options that are on, or a plain "options" when none is.
    private func summary(_ options: [(String, Bool)]) -> String {
        let on = options.filter(\.1).map(\.0)
        return on.isEmpty ? FeatureStrings.mouseClickDebounce(l10n.language).moreOptions : on.joined(separator: " · ")
    }

    private func chartSummary(_ isOn: Bool) -> String {
        summary([(l10n.s.monitorGraphsSection, isOn)])
    }

    private func chartOption(_ isOn: Binding<Bool>) -> some View {
        MonitorTokenOption(symbol: "chart.xyaxis.line", title: l10n.s.monitorGraphsSection, isOn: isOn)
    }

}

private enum PanelConfigBlock: CaseIterable, Hashable {
    case system, network, disk, power, mixer

    var section: PanelSectionID {
        switch self {
        case .system: return .system
        case .network: return .network
        case .disk: return .disk
        case .power: return .power
        case .mixer: return .mixer
        }
    }
}
