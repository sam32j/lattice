// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// Sizes shared by a row, its helpers and the divider between rows.
struct KillProcessRowMetrics {
    let compact: Bool

    var iconSize: CGFloat { compact ? 22 : 28 }
    var spacing: CGFloat { compact ? 8 : 10 }
    var horizontalPadding: CGFloat { compact ? 8 : 12 }
    var dividerInset: CGFloat { horizontalPadding + iconSize + spacing }
    var nameSize: CGFloat { compact ? 11.5 : 13 }
    var metadataSize: CGFloat { compact ? 10 : 11 }
    /// The rightmost column: the row's ••• menu, and under it each helper's
    /// or port's Stop, so the columns to its left share one grid line.
    /// The ••• menu's column. Helper and port stats end on its right edge.
    var trailingColumn: CGFloat { 28 }
    /// Room for Stop or Confirm left of a helper's stats, so switching
    /// between them never moves anything.
    var subrowActionWidth: CGFloat { compact ? 56 : 62 }
}

/// One row: icon, name with at most one chip, a metadata line, then one
/// primary button and the More menu. Helpers open beneath it.
///
/// Every value it shows comes in from the list, and it compares equal when
/// they do, so a live refresh only redraws the rows that changed.
struct KillProcessRow: View, Equatable {
    let item: KillProcessItem
    let surface: KillProcessSurface
    let strings: KillProcessListStrings
    let chip: KillProcessChip?
    let primary: KillProcessPrimaryAction?
    let progress: KillProcessPrimaryAction?
    let menu: [KillProcessMenuEntry]
    let isKept: Bool
    let isAlwaysKept: Bool
    let helpersExpanded: Bool
    let helpersInProgress: Set<pid_t>
    /// Just quit: the row stays, greyed out, with Reopen for a few seconds.
    let isRecentlyQuit: Bool
    /// Set in the Ports section: the row opens its listening ports instead
    /// of its helpers.
    let ports: [KillProcessPort]?
    let onToggleHelpers: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsAllHelpers = false

    /// Helpers shown before "Show N more".
    static let helperPreviewCount = 6

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.item == rhs.item && lhs.surface == rhs.surface && lhs.chip == rhs.chip
            && lhs.primary == rhs.primary && lhs.progress == rhs.progress && lhs.menu == rhs.menu
            && lhs.isKept == rhs.isKept && lhs.isAlwaysKept == rhs.isAlwaysKept
            && lhs.helpersExpanded == rhs.helpersExpanded && lhs.helpersInProgress == rhs.helpersInProgress
            && lhs.isRecentlyQuit == rhs.isRecentlyQuit && lhs.ports == rhs.ports
            && lhs.strings.quit == rhs.strings.quit && lhs.strings.cpuFormat == rhs.strings.cpuFormat
    }

    private var activity: KillProcessActivity { .shared }
    private var metrics: KillProcessRowMetrics { KillProcessRowMetrics(compact: surface.isCompact) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: metrics.spacing) {
                Image(nsImage: ResponsibleProcess.icon(for: item.pid, pointSize: metrics.iconSize))
                    .resizable()
                    .frame(width: metrics.iconSize, height: metrics.iconSize)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.system(size: metrics.nameSize, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if KillProcessCatalog.hasDescription(item, language: L10n.shared.language) {
                            let description = KillProcessDescriptions.description(for: item.name,
                                                                                  language: L10n.shared.language)
                            Image(systemName: "info.circle")
                                .font(.system(size: metrics.nameSize - 2))
                                .foregroundStyle(.tertiary)
                                .frame(width: metrics.nameSize, height: metrics.nameSize)
                                .contentShape(Rectangle())
                                // The app's own hint: shows on hover, or at once on click.
                                .overlay { StatusTooltip(message: description, opensOnClick: true,
                                                         showsInInactiveApp: true) }
                                .accessibilityLabel(description)
                        }
                        if let chip {
                            KillProcessChipView(chip: chip, strings: strings, compact: surface.isCompact)
                        }
                    }
                    metadata
                }
                .layoutPriority(1)
                .opacity(isRecentlyQuit ? 0.45 : 1)
                Spacer(minLength: 6)
                if isRecentlyQuit {
                    Button(strings.reopen) { activity.reopen(item) }
                        .buttonStyle(.bordered)
                        .controlSize(surface.isCompact ? .mini : .small)
                        .fixedSize()
                        .transition(reduceMotion ? .identity : .opacity)
                } else {
                    primaryButton
                }
                moreMenu
                    .disabled(isRecentlyQuit)
                    .opacity(isRecentlyQuit ? 0.45 : 1)
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.vertical, surface.isCompact ? 6 : 9)
            .opacity(progress == nil ? 1 : 0.55)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isRecentlyQuit)

            if let ports, helpersExpanded, !ports.isEmpty, !isRecentlyQuit {
                portList(ports)
                    .transition(reduceMotion ? .identity : .opacity)
            } else if ports == nil, helpersExpanded && !item.helpers.isEmpty && !isRecentlyQuit {
                helperList
                    .transition(reduceMotion ? .identity : .opacity)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
    }

    // MARK: Metadata

    private var metadata: some View {
        HStack(spacing: 0) {
            Text(String(format: strings.cpuFormat, KillProcessFormat.percent(item.cpuPercent)))
                .foregroundStyle(item.cpuPercent >= KillProcessCatalog.highCPUThreshold
                                 ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.secondary))
            Text(" · " + KillProcessFormat.bytes(item.memoryBytes))
                .foregroundStyle(.secondary)
            if disclosureCount > 0 && !isRecentlyQuit {
                Text(" · ").foregroundStyle(.secondary)
                Button(action: onToggleHelpers) {
                    HStack(spacing: 3) {
                        Text(disclosureTitle)
                        Image(systemName: "chevron.right")
                            .font(.system(size: metrics.metadataSize - 2.5, weight: .semibold))
                            .rotationEffect(.degrees(helpersExpanded ? 90 : 0))
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: helpersExpanded)
                    }
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(helpersExpanded ? strings.helpersExpanded : strings.helpersCollapsed)
            }
        }
        .font(.system(size: metrics.metadataSize).monospacedDigit())
        .lineLimit(1)
    }

    // MARK: Helpers and ports

    /// Ports in the Ports section, helpers everywhere else.
    private var disclosureCount: Int { ports?.count ?? item.helpers.count }

    private var disclosureTitle: String {
        if let ports {
            return strings.count(ports.count, one: strings.portCountOne, other: strings.portCountOther)
        }
        return strings.count(item.helpers.count, one: strings.helperCountOne, other: strings.helperCountOther)
    }

    /// Listening ports, hung from the same guide line as helpers.
    private func portList(_ ports: [KillProcessPort]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(ports) { port in
                KillProcessPortRow(port: port, owner: item, surface: surface, strings: strings,
                                   stopping: helpersInProgress.contains(port.pid))
            }
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 1)
                .padding(.vertical, 3)
                .accessibilityHidden(true)
        }
        .padding(.leading, metrics.dividerInset)
        .padding(.trailing, metrics.horizontalPadding)
        .padding(.bottom, surface.isCompact ? 6 : 9)
    }

    /// Helpers under the app's name, hung from a thin guide line: one quiet
    /// line each, CPU and memory in aligned columns, and Stop on hover. Long
    /// lists show the busiest few and a "Show N more".
    private var helperList: some View {
        let shown = showsAllHelpers ? item.helpers : Array(item.helpers.prefix(Self.helperPreviewCount))
        let hidden = item.helpers.count - shown.count
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(shown) { helper in
                KillProcessHelperRow(helper: helper, surface: surface, strings: strings,
                                     stopping: helpersInProgress.contains(helper.pid))
            }
            if hidden > 0 || showsAllHelpers && item.helpers.count > Self.helperPreviewCount {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { showsAllHelpers.toggle() }
                } label: {
                    Text(hidden > 0 ? String(format: strings.showMoreFormat, hidden) : strings.showLess)
                        .font(.system(size: surface.isCompact ? 10 : 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 10)
                .padding(.vertical, 4)
            }
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.primary.opacity(0.12))
                .frame(width: 1)
                .padding(.vertical, 3)
                .accessibilityHidden(true)
        }
        .padding(.leading, metrics.dividerInset)
        .padding(.trailing, metrics.horizontalPadding)
        .padding(.bottom, surface.isCompact ? 6 : 9)
    }

    // MARK: Primary button

    @ViewBuilder
    private var primaryButton: some View {
        if let primary {
            let title: String = {
                switch progress {
                case .quit?: return strings.quitting
                case .stop?, .forceQuit?: return strings.stopping
                case nil: break
                }
                switch primary {
                case .quit: return strings.quit
                case .stop: return strings.stop
                case .forceQuit: return strings.forceQuit
                }
            }()
            let symbol: String = {
                switch primary {
                case .quit: return "power"
                case .stop: return "stop.fill"
                case .forceQuit: return "bolt.fill"
                }
            }()
            // In Ports, Stop acts on the processes holding the ports, so it
            // is gated on them, not on the app, and a change in who holds
            // them asks again before anything is stopped.
            let portTargets = ports.map(Self.stopTargets)
            KillProcessConfirmButton(title: title, symbol: symbol,
                                     confirmTitle: strings.confirm,
                                     controlSize: surface.isCompact ? .mini : .small,
                                     destructive: primary == .forceQuit,
                                     isDisabled: progress != nil
                                        || (portTargets.map(\.isEmpty) ?? (item.startedAt == nil)),
                                     armingKey: portTargets ?? []) {
                // In Ports, Stop ends the processes holding the ports, not the app.
                if let ports { activity.stopPorts(ports, of: item) } else { activity.perform(primary, on: item) }
            }
        }
    }

    /// The verified processes a Ports row's Stop would end, as stable keys.
    static func stopTargets(_ ports: [KillProcessPort]) -> [String] {
        let stoppable = KillProcessCatalog.stoppablePorts(ports, ownPID: ProcessInfo.processInfo.processIdentifier)
        return Set(stoppable.map { "\($0.pid):\($0.startedAt ?? 0)" }).sorted()
    }

    // MARK: More menu

    private var moreMenu: some View {
        Menu {
            ForEach(menu, id: \.action) { entry in
                menuEntry(entry.action)
                    .disabled(!entry.isEnabled)
                if entry.action == .relaunch || entry.action == .keepRunning { Divider() }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: surface.isCompact ? 11 : 12, weight: .semibold))
                .foregroundStyle(surface == .island ? Color.white.opacity(0.8) : Color.secondary)
                .frame(width: metrics.trailingColumn, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        // A borderless menu sizes to its dots; a fixed column keeps the
        // helper and port stats below ending on its right edge.
        .frame(width: metrics.trailingColumn)
        .disabled(progress != nil)
        .help(String(format: strings.moreActionsFormat, item.name))
        .accessibilityLabel(String(format: strings.moreActionsFormat, item.name))
    }

    @ViewBuilder
    private func menuEntry(_ action: KillProcessMenuAction) -> some View {
        switch action {
        case .forceQuit:
            Button(strings.forceQuit, role: .destructive) { activity.forceQuit(item) }
        case .relaunch:
            Button(strings.relaunch) {
                if item.kind == .macOSAgent { activity.restartAgent(item) } else { activity.relaunch(item) }
            }
        case .keepRunning:
            Toggle(strings.keepRunning, isOn: Binding(
                get: { isKept },
                set: { activity.setKeepRunning($0, for: item) }))
                .disabled(isAlwaysKept)
        case .showInFinder:
            Button(strings.showInFinder) { activity.showInFinder(item) }
        case .copyPID:
            Button(strings.copyPID) { activity.copyPID(item.pid) }
                .accessibilityLabel(String(format: strings.copyPIDLabelFormat, Int(item.pid)))
        }
    }
}

/// One helper line: name, then CPU and memory in fixed columns so they line
/// up down the list. Stop appears while the pointer is on the line; a helper
/// Lattice cannot verify never offers it.
struct KillProcessHelperRow: View {
    let helper: KillProcessItem
    let surface: KillProcessSurface
    let strings: KillProcessListStrings
    let stopping: Bool

    @State private var isHovering = false

    var body: some View {
        let compact = surface.isCompact
        HStack(spacing: 8) {
            Text(helper.name)
                .font(.system(size: compact ? 10.5 : 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            KillProcessSubrowTrailing(compact: compact, strings: strings, canStop: helper.startedAt != nil,
                                      stopping: stopping, isHovering: isHovering) {
                HStack(spacing: 8) {
                    Text(KillProcessFormat.percent(helper.ownCPUPercent))
                        .foregroundStyle(helper.ownCPUPercent >= KillProcessCatalog.highCPUThreshold
                                         ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.tertiary))
                        .frame(minWidth: compact ? 36 : 42, alignment: .trailing)
                    Text(KillProcessFormat.bytes(helper.ownMemoryBytes))
                        .foregroundStyle(.tertiary)
                        .frame(minWidth: compact ? 50 : 58, alignment: .trailing)
                }
                .font(.system(size: compact ? 9.5 : 10.5).monospacedDigit())
            } action: {
                KillProcessActivity.shared.stopHelper(helper)
            }
        }
        .padding(.leading, 10)
        .padding(.vertical, compact ? 2 : 3)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .opacity(stopping ? 0.55 : 1)
    }
}

/// One listening port: the port, its protocol and address, a mark when it
/// is open to the whole network, and which helper holds it. Stop on hover
/// ends just the process holding this port; the row's Stop ends all of them.
struct KillProcessPortRow: View {
    let port: KillProcessPort
    let owner: KillProcessItem
    let surface: KillProcessSurface
    let strings: KillProcessListStrings
    let stopping: Bool

    @State private var isHovering = false

    private var helper: KillProcessItem? { owner.helpers.first { $0.pid == port.pid } }
    /// What the port is for when Lattice can tell; otherwise the process
    /// holding it, when that is not the row's own.
    private var label: String {
        if let service = port.service { return strings.serviceName(service) }
        return port.pid == owner.pid ? "" : (helper?.name ?? port.processName)
    }
    /// Any port can be stopped on its own, except one Lattice holds or whose
    /// process could not be verified.
    private var canStop: Bool {
        owner.kind != .system && owner.kind != .lattice
            && !KillProcessCatalog.stoppablePorts([port], ownPID: ProcessInfo.processInfo.processIdentifier).isEmpty
    }

    var body: some View {
        let compact = surface.isCompact
        let exposed = KillProcessPortSupport.listensOnAllInterfaces(port.address)
        HStack(spacing: 8) {
            Text(":" + String(port.port))
                .font(.system(size: compact ? 10.5 : 11.5, weight: .semibold).monospacedDigit())
            Text(port.protocolName + " · " + port.address)
                .font(.system(size: compact ? 9.5 : 10.5).monospacedDigit())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
            if exposed {
                Image(systemName: "globe")
                    .font(.system(size: compact ? 9.5 : 10.5, weight: .semibold))
                    .foregroundStyle(.orange)
                    .overlay { StatusTooltip(message: strings.allInterfacesHelp, opensOnClick: true,
                                             showsInInactiveApp: true) }
                    .accessibilityLabel(strings.allInterfaces)
            }
            Spacer(minLength: 6)
            KillProcessSubrowTrailing(compact: compact, strings: strings, canStop: canStop,
                                      stopping: stopping, isHovering: isHovering) {
                Text(label)
                    .font(.system(size: compact ? 9.5 : 10.5))
                    .foregroundStyle(.tertiary)
                    .truncationMode(.tail)
            } action: {
                KillProcessActivity.shared.stopPorts([port], of: owner)
            }
            // What the port is for matters more than its full address, which
            // shortens first.
            .layoutPriority(1)
        }
        .padding(.leading, 10)
        .padding(.vertical, compact ? 2 : 3)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .opacity(stopping ? 0.55 : 1)
    }
}

/// The right side of a helper or port line: its stats end flush right, on
/// the ••• menu's edge, and a quiet red Stop appears to their left while the
/// pointer is on the line. The first click turns Stop into a red Confirm in
/// the same fixed slot, so nothing moves; it settles back the same way the
/// row buttons do.
struct KillProcessSubrowTrailing<Details: View>: View {
    let compact: Bool
    let strings: KillProcessListStrings
    let canStop: Bool
    let stopping: Bool
    let isHovering: Bool
    @ViewBuilder let details: () -> Details
    let action: () -> Void

    @State private var armedAt: Date?
    /// How long Confirm waits once the pointer is off the line: longer when
    /// armed from the accessibility action, which has no pointer to wait on.
    @State private var armedWindow = KillProcessConfirmButton.armedDuration
    @State private var generation = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isArmed: Bool { armedAt != nil }
    private var metrics: KillProcessRowMetrics { KillProcessRowMetrics(compact: compact) }
    private var fontSize: CGFloat { compact ? 9.5 : 10.5 }

    var body: some View {
        HStack(spacing: metrics.spacing) {
            // A fixed slot: the label is laid over it, trailing-aligned toward
            // the stats, so a longer translation grows left into the name's
            // free space instead of pushing the stats.
            Color.clear
                .frame(width: metrics.subrowActionWidth, height: 1)
                .overlay(alignment: .trailing) { label.fixedSize() }
            details()
                .lineLimit(1)
        }
        // Stop shows on hover; VoiceOver, Voice Control and keyboard users
        // reach the same two steps as a named action on the line.
        .accessibilityActions {
            if canStop && !stopping {
                Button(isArmed ? strings.confirm : strings.stop) {
                    if isArmed {
                        setArmed(false)
                        action()
                    } else {
                        setArmed(true, window: Self.accessibleArmedDuration)
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isArmed)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovering)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: stopping)
        .onChange(of: isHovering) { _, hovering in if !hovering { resetWhenDue() } }
        .onChange(of: stopping) { _, now in if now { setArmed(false) } }
    }

    private var swap: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.85, anchor: .trailing).combined(with: .opacity)
    }

    @ViewBuilder
    private var label: some View {
        if stopping {
            Text(strings.stopping)
                .font(.system(size: fontSize))
                .foregroundStyle(.secondary)
                .transition(.opacity)
        } else if isArmed {
            Button {
                setArmed(false)
                action()
            } label: {
                Text(strings.confirm)
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .transition(swap)
        } else if canStop && isHovering {
            Button {
                setArmed(true)
            } label: {
                Text(strings.stop)
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .transition(swap)
        }
    }

    static var accessibleArmedDuration: TimeInterval { 6 }

    private func setArmed(_ armed: Bool, window: TimeInterval = KillProcessConfirmButton.armedDuration) {
        generation += 1
        armedAt = armed ? Date() : nil
        armedWindow = window
        if armed {
            AccessibilityNotification.Announcement(strings.confirm).post()
            scheduleCheck(after: window)
        }
    }

    /// Settles back once the pointer is off the line and the gate has passed.
    private func resetWhenDue() {
        guard let armedAt, !isHovering else { return }
        let remaining = armedWindow - Date().timeIntervalSince(armedAt)
        if remaining <= 0 { setArmed(false) } else { scheduleCheck(after: remaining) }
    }

    private func scheduleCheck(after delay: TimeInterval) {
        let expected = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard generation == expected else { return }
            resetWhenDue()
        }
    }
}

struct KillProcessChipView: View {
    let chip: KillProcessChip
    let strings: KillProcessListStrings
    let compact: Bool

    var body: some View {
        let (title, tint): (String, Color) = {
            switch chip {
            case .notResponding: return (strings.chipNotResponding, .red)
            case .thisApp: return (strings.chipThisApp, .secondary)
            case .front: return (strings.chipFront, .accentColor)
            case .kept: return (strings.chipKept, .orange)
            }
        }()
        Text(title)
            .font(.system(size: compact ? 9 : 9.5, weight: .bold, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

struct KillProcessToastView: View {
    let toast: KillProcessToast
    let compact: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(toast.message)
                .font(.system(size: compact ? 11 : 12, weight: .medium))
                .lineLimit(2)
            Spacer(minLength: 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        .accessibilityElement(children: .contain)
    }
}

/// The floating HUD's header: tool icon, title and Refresh.
struct KillProcessHUDHeader: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = KillProcessService.shared
    /// Only a refresh asked for here turns the arrow, never the live timer's.
    @State private var isRefreshing = false

    var body: some View {
        let strings = FeatureStrings.killProcessList(l10n.language)
        HStack(spacing: 9) {
            Image(systemName: AppFeature.killProcess.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(FeatureStrings.killProcess(l10n.language).pageTitle)
                .font(.system(size: 13, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                isRefreshing = true
                service.refresh(force: true) { isRefreshing = false }
            } label: {
                Label { Text(strings.refresh) } icon: { RefreshArrow(isSpinning: isRefreshing) }
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isRefreshing)
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }
}

enum KillProcessFormat {
    static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", locale: MetricFormat.locale, value)
    }

    static func bytes(_ value: Double) -> String {
        MetricFormat.bytes(UInt64(max(0, value)))
    }
}

/// A Quit or Stop that asks twice. The first click turns it into a red
/// Confirm; the second runs the action. It settles back once the pointer has
/// left the button and `armedDuration` has passed since it was armed.
struct KillProcessConfirmButton: View {
    let title: String
    let symbol: String?
    let confirmTitle: String
    let controlSize: ControlSize
    let destructive: Bool
    let isDisabled: Bool
    /// What the action would act on. When it changes while armed, the
    /// button settles back and asks again.
    var armingKey: [String] = []
    let action: () -> Void

    static let armedDuration: TimeInterval = 1

    @State private var armedAt: Date?
    @State private var isHovering = false
    @State private var generation = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isArmed: Bool { armedAt != nil }

    var body: some View {
        Button {
            if isArmed {
                setArmed(false, animated: false)
                action()
            } else {
                setArmed(true, animated: true)
            }
        } label: {
            // Both labels size the button invisibly, so it keeps one width;
            // the visible label scales down and out as the other scales up in.
            ZStack {
                normalLabel.hidden()
                Text(confirmTitle).hidden()
                if isArmed {
                    Text(confirmTitle).transition(swap)
                } else {
                    normalLabel.transition(swap)
                }
            }
            .lineLimit(1)
            .clipped()
        }
        .buttonStyle(.bordered)
        .controlSize(controlSize)
        .tint(isArmed || destructive ? .red : nil)
        .disabled(isDisabled)
        .fixedSize()
        .onHover { inside in
            isHovering = inside
            if !inside { resetWhenDue() }
        }
        .onChange(of: isDisabled) { _, disabled in if disabled { setArmed(false, animated: false) } }
        .onChange(of: armingKey) { _, _ in setArmed(false, animated: false) }
        .accessibilityLabel(isArmed ? confirmTitle : title)
    }

    private var swap: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity)
    }

    @ViewBuilder
    private var normalLabel: some View {
        if let symbol {
            Label(title, systemImage: symbol).labelStyle(.titleAndIcon)
        } else {
            Text(title)
        }
    }

    private func setArmed(_ armed: Bool, animated: Bool) {
        generation += 1
        let animation: Animation? = reduceMotion || !animated
            ? nil
            : .snappy(duration: 0.22)
        withAnimation(animation) { armedAt = armed ? Date() : nil }
        if armed {
            AccessibilityNotification.Announcement(confirmTitle).post()
            scheduleCheck(after: Self.armedDuration)
        }
    }

    /// Settles back once the pointer is off the button and the gate has passed.
    private func resetWhenDue() {
        guard let armedAt, !isHovering else { return }
        let remaining = Self.armedDuration - Date().timeIntervalSince(armedAt)
        if remaining <= 0 { setArmed(false, animated: true) } else { scheduleCheck(after: remaining) }
    }

    private func scheduleCheck(after delay: TimeInterval) {
        let expected = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard generation == expected else { return }
            resetWhenDue()
        }
    }
}
