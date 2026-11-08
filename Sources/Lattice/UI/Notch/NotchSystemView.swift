// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

struct NotchSystemView: View {
    let select: (MetricDetailKind) -> Void
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.notchSettingsPreview) private var isSettingsPreview
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(DefaultsKey.networkSpeedUnit) private var networkSpeedUnit = NetworkSpeedUnit.bytes
    @AppStorage(DefaultsKey.monitorInterval) private var monitorInterval = 2
    @State private var topApps: [MetricDetailKind: String] = [:]
    @State private var lastAppRefresh: Date = .distantPast
    @State private var samplingApps = false

    private static func isLoading(_ snapshot: SystemSnapshot) -> Bool {
        snapshot.cpuUsage == nil && snapshot.gpuUsage == nil && snapshot.memoryUsed == nil
            && snapshot.disk == nil && snapshot.power == nil && snapshot.netDownBytesPerSec == nil
            && snapshot.fanSpeeds.isEmpty && snapshot.connectedDevices.isEmpty
    }

    private static func visibleKinds(in snapshot: SystemSnapshot) -> Set<MetricDetailKind> {
        var kinds: Set<MetricDetailKind> = []
        if AppFeature.monitorCPU.isAvailable { kinds.insert(.cpu) }
        if AppFeature.monitorGPU.isAvailable { kinds.insert(.gpu) }
        if AppFeature.monitorMemory.isAvailable { kinds.insert(.memory) }
        if AppFeature.monitorNetwork.isAvailable { kinds.insert(.network) }
        if AppFeature.monitorDisk.isAvailable { kinds.insert(.disk) }
        if AppFeature.monitorPower.isAvailable {
            kinds.insert(PowerSampler.hasInternalBattery ? .battery : .power)
        }
        if AppFeature.fanControl.isAvailable, !snapshot.fanSpeeds.isEmpty { kinds.insert(.fan) }
        if AppFeature.connectedDevices.isAvailable, !snapshot.connectedDevices.isEmpty {
            kinds.insert(.connectedDevices)
        }
        return kinds
    }

    static func contentHeight(for snapshot: SystemSnapshot) -> CGFloat {
        let count = isLoading(snapshot) ? 6 : visibleKinds(in: snapshot).count
        return SystemWidgetLayout.summaryHeight(tileCount: count)
    }

    struct TileMetric: Identifiable {
        let kind: MetricDetailKind
        let title: String
        let short: String
        let progress: Double
        let severity: Int
        let hint: String?
        var downRate: (n: String, u: String)? = nil
        var upRate: (n: String, u: String)? = nil
        var isStale: Bool = false
        var id: String { kind.rawValue }
    }

    private static var lastKnownPercentages: [MetricDetailKind: Double] = [:]

    private func resolvedPercent(for kind: MetricDetailKind, current: Double?, snapshotFallback: Double? = nil) -> (value: Double?, isStale: Bool) {
        if let current, current.isFinite {
            Self.lastKnownPercentages[kind] = current
            return (current, false)
        }
        if let fallback = snapshotFallback ?? Self.lastKnownPercentages[kind] {
            Self.lastKnownPercentages[kind] = fallback
            return (fallback, true)
        }
        return (nil, false)
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

    private func tiles(in snapshot: SystemSnapshot) -> [TileMetric] {
        let kinds = Self.visibleKinds(in: snapshot)
        var items: [TileMetric] = []

        // 1. CPU
        if kinds.contains(.cpu) {
            let (usage, isStale) = resolvedPercent(for: .cpu, current: snapshot.cpuUsage, snapshotFallback: snapshot.lastKnownCPUUsage)
            let s = isStale ? 0 : severity(for: usage ?? 0)
            let hint = s > 0 ? (topApps[.cpu] ?? ProcessUsageService.shared.cachedTop(.cpu, limit: 1)?.first?.name) : nil
            items.append(TileMetric(
                kind: .cpu,
                title: l10n.s.cpuLabel,
                short: percentString(usage),
                progress: usage ?? 0,
                severity: s,
                hint: hint,
                isStale: isStale
            ))
        }

        // 2. GPU
        if kinds.contains(.gpu) {
            let (usage, isStale) = resolvedPercent(for: .gpu, current: snapshot.gpuUsage, snapshotFallback: snapshot.lastKnownGPUUsage)
            let s = isStale ? 0 : severity(for: usage ?? 0)
            let hint = s > 0 ? (topApps[.gpu] ?? ProcessUsageService.shared.cachedTop(.gpu, limit: 1)?.first?.name) : nil
            items.append(TileMetric(
                kind: .gpu,
                title: l10n.s.gpuLabel,
                short: percentString(usage),
                progress: usage ?? 0,
                severity: s,
                hint: hint,
                isStale: isStale
            ))
        }

        // 3. Memory
        if kinds.contains(.memory) {
            let currentRatio = snapshot.memoryUsed.flatMap { used in
                snapshot.memoryTotal.flatMap { total in total > 0 ? Double(used) / Double(total) : nil }
            }
            let (ratio, isStale) = resolvedPercent(for: .memory, current: currentRatio)
            let val = ratio ?? 0
            let s = isStale ? 0 : severity(for: val)
            let hint = s > 0 ? (topApps[.memory] ?? ProcessUsageService.shared.cachedTop(.memory, limit: 1)?.first?.name) : nil
            items.append(TileMetric(
                kind: .memory,
                title: l10n.s.memorySection,
                short: percentString(ratio),
                progress: val,
                severity: s,
                hint: hint,
                isStale: isStale
            ))
        }

        // 4. Battery on laptops, system energy on desktops.
        let power = snapshot.power
        if kinds.contains(.battery) {
            let charge = power?.chargePercent.map { Double($0) / 100 }
            let discharging = power.map(SystemWidgetDetailContent.batteryIsDischarging) ?? false
            let level = discharging ? charge.map { severity(for: $0, inverted: true) } ?? 0 : 0
            let hint = power?.timeRemainingSeconds.map { "\(Int($0 / 60)) min left" }
            items.append(TileMetric(kind: .battery, title: l10n.s.batteryLabel,
                                    short: percentString(charge), progress: charge ?? 0,
                                    severity: level, hint: hint))
        } else if kinds.contains(.power) {
            let watts = power?.systemWatts
            items.append(TileMetric(kind: .power, title: "Energy",
                                    short: watts.map(MetricFormat.wattsCompact) ?? "—",
                                    progress: min(1, (watts ?? 0) / 100), severity: 0, hint: nil))
        }

        // 5. Network
        if kinds.contains(.network) {
            let down = Double(snapshot.netDownBytesPerSec ?? 0)
            let up = Double(snapshot.netUpBytesPerSec ?? 0)
            let downFmt = Self.formatRate(down)
            let upFmt = Self.formatRate(up)
            items.append(TileMetric(
                kind: .network,
                title: l10n.s.networkSection,
                short: "↓\(downFmt.n) \(downFmt.u)",
                progress: 0,
                severity: 0,
                hint: nil,
                downRate: downFmt,
                upRate: upFmt
            ))
        }

        // 6. Storage (Disk)
        if kinds.contains(.disk) {
            let disk = snapshot.disk?.devices.first(where: { $0.mountPath == "/" })
                ?? snapshot.disk?.devices.first(where: \.isInternal)
                ?? snapshot.disk?.devices.first
            let used = disk?.usedFraction ?? 0
            let s = severity(for: used)
            let free = disk.map { MetricFormat.diskBytes($0.freeBytes) } ?? ""
            let hint = s > 0 ? "\(free) free" : nil
            items.append(TileMetric(
                kind: .disk,
                title: l10n.s.diskStorageSettings,
                short: percentString(used),
                progress: used,
                severity: s,
                hint: hint
            ))
        }

        // Optional fan speed if available and reported
        if kinds.contains(.fan) {
            let rpm = snapshot.fanSpeeds.first ?? 0
            let strings = FeatureStrings.fanControl(l10n.language)
            items.append(TileMetric(
                kind: .fan,
                title: strings.title,
                short: "\(Int(rpm.rounded()))",
                progress: min(1.0, rpm / 6000.0),
                severity: rpm >= 5000 ? 1 : 0,
                hint: nil
            ))
        }

        // Optional connected devices
        if kinds.contains(.connectedDevices) {
            let count = snapshot.connectedDevices.count
            let strings = FeatureStrings.connectedDevices(l10n.language)
            items.append(TileMetric(
                kind: .connectedDevices,
                title: strings.title,
                short: "\(count)",
                progress: min(1.0, Double(count) / 5.0),
                severity: 0,
                hint: nil
            ))
        }

        return items
    }

    @State private var skeletonPulse = false

    var body: some View {
        let snapshot = monitor.snapshot
        let isLoading = Self.isLoading(snapshot)
        let tiles = tiles(in: snapshot)

        Group {
            if isLoading {
                systemSkeletonView
            } else if tiles.isEmpty {
                NotchEmptyView(symbol: "cpu", message: l10n.s.monitorUnavailable)
                    .frame(height: SystemWidgetLayout.summaryEmptyHeight)
            } else {
                VStack(spacing: SystemWidgetLayout.summarySpacing) {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: SystemWidgetLayout.summarySpacing),
                        GridItem(.flexible(), spacing: SystemWidgetLayout.summarySpacing),
                        GridItem(.flexible(), spacing: SystemWidgetLayout.summarySpacing)
                    ], spacing: SystemWidgetLayout.summarySpacing) {
                        ForEach(tiles) { tile in
                            SystemTileButton(tile: tile, skeletonPulse: skeletonPulse) {
                                select(tile.kind)
                            }
                        }
                    }

                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(red: 0.19, green: 0.82, blue: 0.35))
                            .frame(width: 6, height: 6)
                        Text("Up for \(SystemInfo.uptimeString())")
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color(red: 0.19, green: 0.82, blue: 0.35))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Color(red: 0.19, green: 0.82, blue: 0.35).opacity(0.12), in: Capsule())
                    .frame(height: SystemWidgetLayout.summaryFooterHeight, alignment: .center)
                }
                .padding(.horizontal, 10)
                .padding(.top, SystemWidgetLayout.summaryTopInset)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .onAppear {
            monitor.panelDidAppear()
            monitor.setNotchVisible(true)
            monitor.refreshNow()
            monitor.scheduleCPUWarmUpIfNeeded()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                monitor.refreshNow()
            }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                skeletonPulse = true
            }
        }
        .onReceive(monitor.$snapshot) { snapshot in refreshTopApps(snapshot: snapshot) }
        .onDisappear {
            monitor.panelDidDisappear()
            monitor.setNotchVisible(false)
        }
    }

    private var systemSkeletonView: some View {
        VStack(spacing: SystemWidgetLayout.summarySpacing) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: SystemWidgetLayout.summarySpacing),
                GridItem(.flexible(), spacing: SystemWidgetLayout.summarySpacing),
                GridItem(.flexible(), spacing: SystemWidgetLayout.summarySpacing)
            ], spacing: SystemWidgetLayout.summarySpacing) {
                ForEach(0..<6, id: \.self) { index in
                    VStack(spacing: 6) {
                        if index == 4 {
                            NetworkMetricSkeleton(pulse: skeletonPulse)
                        } else {
                            Circle()
                                .stroke(colorScheme == .dark ? Color.white.opacity(skeletonPulse ? 0.14 : 0.06) : Color.primary.opacity(skeletonPulse ? 0.14 : 0.06), lineWidth: 5)
                                .frame(width: 50, height: 50)
                                .frame(width: 58, height: 58)
                        }
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white.opacity(skeletonPulse ? 0.10 : 0.04) : Color.primary.opacity(skeletonPulse ? 0.10 : 0.04))
                            .frame(width: 44, height: 12)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.clear)
                            .frame(height: 14)
                    }
                    .padding(.horizontal, 6)
                    .frame(maxWidth: .infinity)
                    .frame(height: SystemWidgetLayout.summaryTileHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.04) : Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
            }

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(colorScheme == .dark ? Color.white.opacity(skeletonPulse ? 0.08 : 0.03) : Color.primary.opacity(skeletonPulse ? 0.08 : 0.03))
                .frame(width: 80, height: 12)
                .frame(height: SystemWidgetLayout.summaryFooterHeight, alignment: .top)
        }
        .padding(.horizontal, 10)
        .padding(.top, SystemWidgetLayout.summaryTopInset)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func refreshTopApps(snapshot: SystemSnapshot) {
        let interval = TimeInterval(Defaults.sanitizedMonitorInterval(monitorInterval))
        guard !isSettingsPreview, !samplingApps,
              Date().timeIntervalSince(lastAppRefresh) >= interval * 0.8 else { return }
        let metrics = tiles(in: snapshot).filter { $0.severity > 0 && [.cpu, .gpu, .memory].contains($0.kind) }.map(\.kind)
        guard !metrics.isEmpty else { return }
        samplingApps = true
        lastAppRefresh = Date()
        DispatchQueue.global(qos: .utility).async {
            let service = ProcessUsageService.shared
            var apps: [MetricDetailKind: String] = [:]
            for metric in metrics {
                guard let kind = metric.processKind else { continue }
                apps[metric] = service.top(kind, limit: 15, sampleInterval: interval,
                                           cpuPercentage: snapshot.cpuUsage.map { $0 * 100 },
                                           gpuPercentage: snapshot.gpuUsage.map { $0 * 100 }).first?.name
            }
            DispatchQueue.main.async {
                topApps = apps
                samplingApps = false
            }
        }
    }

    static func formatRate(_ bytesPerSec: Double) -> (n: String, u: String) {
        var b = max(0, bytesPerSec)
        var i = 0
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        while b >= 1024 && i < 3 {
            b /= 1024
            i += 1
        }
        let n: String
        if i == 0 || b >= 100 {
            n = "\(Int(b.rounded()))"
        } else if b >= 10 {
            n = String(format: "%.0f", locale: MetricFormat.locale, b)
        } else {
            n = String(format: "%.1f", locale: MetricFormat.locale, b)
        }
        return (n, units[i])
    }

    private func percentString(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "—" }
        return "\(Int((min(1, max(0, value)) * 100).rounded()))%"
    }
}

private struct SystemMetricFlow: View {
    let down: (n: String, u: String)
    let up: (n: String, u: String)
    @Environment(\.colorScheme) private var colorScheme

    private var downColor: Color {
        colorScheme == .dark ? Color(red: 0.37, green: 0.66, blue: 1.0) : Color(red: 0.10, green: 0.50, blue: 0.95)
    }

    private var upColor: Color {
        colorScheme == .dark ? Color(red: 0.19, green: 0.82, blue: 0.35) : Color(red: 0.12, green: 0.65, blue: 0.28)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 3) {
            rateRow(arrow: "↓", arrowColor: downColor, rate: down)
            rateRow(arrow: "↑", arrowColor: upColor, rate: up)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
    }

    private func rateRow(arrow: String, arrowColor: Color, rate: (n: String, u: String)) -> some View {
        HStack(spacing: 2) {
            Text(arrow)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(arrowColor)
            Text(rate.n)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(colorScheme == .dark ? .white : .primary)
                .contentTransition(.numericText())
                .lineLimit(1)
            Text(rate.u)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundColor(colorScheme == .dark ? Color(red: 0.54, green: 0.54, blue: 0.58) : .secondary)
                .lineLimit(1)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}

private struct SystemMetricRing: View {
    let progress: Double
    let text: String
    let severity: Int
    var isStale: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var strokeColor: Color {
        if isStale {
            return colorScheme == .dark
                ? Color.white.opacity(0.22)
                : Color.primary.opacity(0.22)
        }
        switch severity {
        case 2: return Color(red: 1.0, green: 0.27, blue: 0.23) // #ff453a
        case 1:
            return colorScheme == .dark
                ? Color(red: 1.0, green: 0.62, blue: 0.04) // #ff9f0a
                : Color(red: 0.88, green: 0.48, blue: 0.0)
        default:
            return colorScheme == .dark
                ? Color(red: 0.91, green: 0.91, blue: 0.93) // #e8e8ee
                : Color(red: 0.14, green: 0.14, blue: 0.16)
        }
    }

    private var textColor: Color {
        if isStale {
            return colorScheme == .dark ? Color(red: 0.54, green: 0.54, blue: 0.58) : Color.secondary
        }
        return colorScheme == .dark ? .white : Color.primary
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(colorScheme == .dark ? Color.white.opacity(0.08) : Color.primary.opacity(0.08), lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(min(1.0, max(0.001, progress))))
                .stroke(strokeColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(progress > 0.002 ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.82), value: progress)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: strokeColor)
            Text(text)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(textColor)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.82), value: text)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isStale)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .padding(.horizontal, 4)
        }
        .frame(width: 58, height: 58)
    }
}

private struct NetworkMetricSkeleton: View {
    var pulse: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            HStack(spacing: 4) {
                Text("↓")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor((colorScheme == .dark ? Color(red: 0.37, green: 0.66, blue: 1.0) : Color(red: 0.10, green: 0.50, blue: 0.95)).opacity(pulse ? 0.8 : 0.4))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill((colorScheme == .dark ? Color.white : Color.primary).opacity(pulse ? 0.14 : 0.06))
                    .frame(width: 32, height: 11)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill((colorScheme == .dark ? Color.white : Color.primary).opacity(pulse ? 0.09 : 0.04))
                    .frame(width: 22, height: 9)
            }
            HStack(spacing: 4) {
                Text("↑")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor((colorScheme == .dark ? Color(red: 0.19, green: 0.82, blue: 0.35) : Color(red: 0.12, green: 0.65, blue: 0.28)).opacity(pulse ? 0.8 : 0.4))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill((colorScheme == .dark ? Color.white : Color.primary).opacity(pulse ? 0.14 : 0.06))
                    .frame(width: 32, height: 11)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill((colorScheme == .dark ? Color.white : Color.primary).opacity(pulse ? 0.09 : 0.04))
                    .frame(width: 22, height: 9)
            }
        }
        .frame(height: 58)
    }
}

private struct SystemTileButton: View {
    let tile: NotchSystemView.TileMetric
    var skeletonPulse: Bool = false
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var backgroundColor: Color {
        if tile.isStale {
            return isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04)
        }
        switch tile.severity {
        case 2:
            return Color.red.opacity(isHovered ? (colorScheme == .dark ? 0.18 : 0.14) : (colorScheme == .dark ? 0.12 : 0.08))
        case 1:
            return Color.orange.opacity(isHovered ? (colorScheme == .dark ? 0.16 : 0.12) : (colorScheme == .dark ? 0.09 : 0.07))
        default:
            return isHovered ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04)
        }
    }

    private var borderColor: Color {
        if tile.isStale {
            return colorScheme == .dark
                ? Color.white.opacity(isHovered ? 0.12 : 0.04)
                : Color.primary.opacity(isHovered ? 0.12 : 0.06)
        }
        switch tile.severity {
        case 2:
            return Color.red.opacity(isHovered ? 0.40 : (colorScheme == .dark ? 0.22 : 0.30))
        case 1:
            return Color.orange.opacity(isHovered ? 0.35 : (colorScheme == .dark ? 0.18 : 0.25))
        default:
            return colorScheme == .dark
                ? Color.white.opacity(isHovered ? 0.12 : 0.04)
                : Color.primary.opacity(isHovered ? 0.12 : 0.06)
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                if tile.short == "—" {
                    if tile.kind == .network {
                        NetworkMetricSkeleton(pulse: skeletonPulse)
                    } else {
                        ZStack {
                            Circle()
                                .stroke((colorScheme == .dark ? Color.white : Color.primary).opacity(skeletonPulse ? 0.14 : 0.06), lineWidth: 5)
                            Text("—")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor((colorScheme == .dark ? Color.white : Color.primary).opacity(skeletonPulse ? 0.5 : 0.25))
                        }
                        .frame(width: 58, height: 58)
                    }
                } else if tile.kind == .network, let down = tile.downRate, let up = tile.upRate {
                    SystemMetricFlow(down: down, up: up)
                } else {
                    SystemMetricRing(progress: tile.progress, text: tile.short, severity: tile.severity, isStale: tile.isStale)
                }
                Text(tile.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? Color(red: 0.63, green: 0.63, blue: 0.66) : Color.primary.opacity(0.70))
                    .lineLimit(1)
                Text(tile.hint ?? "")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(tile.severity == 0 ? Color.secondary : tile.severity == 2 ? Color(red: 1.0, green: 0.27, blue: 0.23) : (colorScheme == .dark ? Color(red: 1.0, green: 0.62, blue: 0.04) : Color(red: 0.85, green: 0.45, blue: 0.0)))
                    .lineLimit(1)
                    .frame(height: 14)
            }
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity)
            .frame(height: SystemWidgetLayout.summaryTileHeight)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: tile.severity)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: tile.isStale)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(tile.title)
        .accessibilityValue(tile.short)
    }
}
