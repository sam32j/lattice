// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

enum SystemWidgetDetailContent {
    static func hasGraph(for kind: MetricDetailKind, widgetDesign: Bool = true) -> Bool {
        switch kind {
        case .battery: return widgetDesign || PowerSampler.hasInternalBattery
        case .fan, .connectedDevices: return false
        default: return true
        }
    }

    static func disk(in snapshot: SystemSnapshot, index: Int) -> DiskDeviceReading? {
        guard let devices = snapshot.disk?.devices else { return nil }
        if devices.indices.contains(index) { return devices[index] }
        return devices.first(where: { $0.mountPath == "/" }) ?? devices.first(where: \.isInternal) ?? devices.first
    }

    static func factCount(for kind: MetricDetailKind, snapshot: SystemSnapshot, disk: DiskDeviceReading? = nil) -> Int {
        switch kind {
        case .disk:
            var count = 0
            let isAPFS = disk?.fileSystem?.localizedCaseInsensitiveContains("apfs") == true
            if isAPFS && disk?.purgeableBytes != nil { count += 1 }
            if disk?.smart?.powerCycles != nil { count += 1 }
            if disk?.smart?.powerOnHours != nil { count += 1 }
            return count
        case .battery, .power: return PowerSampler.hasInternalBattery ? 3 : 0
        case .memory: return 4
        case .network: return 2
        case .fan: return snapshot.fanSpeeds.count
        case .connectedDevices: return min(3, snapshot.connectedDevices.count)
        default: return 3
        }
    }

    static func batteryIsDischarging(_ power: PowerReading) -> Bool {
        !power.isCharging && (!power.externalConnected || (power.batteryWatts ?? 0) < 0)
    }

    static func batterySubtitle(_ power: PowerReading?) -> String {
        guard let power, power.hasBattery else { return "Reading battery…" }
        if power.isCharging {
            return power.timeToFullSeconds.map { "Charging · \(Int($0 / 60)) min to full" } ?? "Charging"
        }
        if batteryIsDischarging(power) {
            if power.externalConnected { return "Discharging" }
            return power.timeRemainingSeconds.map { "On battery · \(Int($0 / 60)) min left" } ?? "On battery"
        }
        return "Plugged in"
    }

    static func energyFacts(power: PowerReading?, hasBattery: Bool,
                            temperature: String?) -> [(String, String, String?, String?)] {
        guard hasBattery else { return [] }
        if let power, !batteryIsDischarging(power) {
            let charge = power.batteryWatts.flatMap { $0 > 0 ? $0 : nil }
            return [("Charger", power.adapterWatts.map(MetricFormat.watts) ?? "-", nil, nil),
                    ("To battery", charge.map(MetricFormat.watts) ?? "-", nil, nil),
                    ("System", power.systemWatts.map(MetricFormat.watts) ?? "-", nil, nil)]
        }
        let health = power?.healthPercent.map { "\(Int($0.rounded()))%" } ?? "-"
        let cycles = power?.cycleCount.map { $0.formatted() + " cycles" }
        let draw = power?.batteryWatts.flatMap { $0 < 0 ? -$0 : nil } ?? power?.systemWatts
        return [("Health", health, cycles, nil),
                ("Draw", draw.map(MetricFormat.watts) ?? "-", nil, nil),
                ("Battery temp", temperature ?? "-", nil, nil)]
    }

    static func detailRows(for kind: MetricDetailKind, snapshot: SystemSnapshot, disk: DiskDeviceReading?,
                           widgetDesign: Bool = true,
                           formatTemperature: (Double) -> String = { _ in "" }) -> [(String, String)] {
        if widgetDesign, SystemWidgetLayout.isEnergyMetric(kind) { return [] }
        switch kind {
        case .cpu, .gpu, .memory:
            return []
        case .battery:
            guard let power = snapshot.power else { return [] }
            var list: [(String, String)] = []
            if let health = power.healthPercent {
                list.append(("Health", "\(Int(health.rounded()))%"))
            }
            if let temp = snapshot.batteryTemperature {
                list.append(("Temp", formatTemperature(temp)))
            }
            if let cycles = power.cycleCount {
                list.append(("Power cycles", "\(cycles)"))
            }
            return list
        case .network:
            var list: [(String, String)] = []
            list.append(("Session downloads", MetricFormat.bytes(snapshot.netTotalDown ?? 0)))
            list.append(("Session uploads", MetricFormat.bytes(snapshot.netTotalUp ?? 0)))
            return list
        case .disk:
            guard let disk = disk, let smart = disk.smart else { return [] }
            var list: [(String, String)] = []
            if let h = smart.healthPercent {
                list.append(("Health", "\(h)%"))
            }
            if let t = smart.temperatureCelsius {
                list.append(("Drive temp", formatTemperature(t)))
            }
            return list
        case .power:
            var list: [(String, String)] = []
            if let maxW = snapshot.power?.adapterMaxWatts {
                list.append(("Charger rating", MetricFormat.watts(maxW)))
            }
            return list
        case .fan, .connectedDevices:
            return []
        }
    }

}

extension SystemNavigationState {
    func height(for snapshot: SystemSnapshot) -> CGFloat {
        guard let kind = selectedMetric else {
            return NotchSystemView.contentHeight(for: snapshot)
        }
        let disk = SystemWidgetDetailContent.disk(in: snapshot, index: selectedDiskIndex)
        return SystemWidgetLayout.detailHeight(
            kind: kind,
            hasGraph: SystemWidgetDetailContent.hasGraph(for: kind),
            factCount: SystemWidgetDetailContent.factCount(for: kind, snapshot: snapshot, disk: disk),
            detailsCount: SystemWidgetDetailContent.detailRows(for: kind, snapshot: snapshot, disk: disk).count,
            hasDiskPicker: kind == .disk && (snapshot.disk?.devices.contains(where: { !$0.isInternal }) == true),
            navigation: self
        )
    }

    var effectiveHeight: CGFloat { height(for: SystemMonitor.shared.snapshot) }
}
