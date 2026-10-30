// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

struct HubStayAwakePopover: View {
    @ObservedObject private var awake = KeepAwakeManager.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss
    @State private var pickingTime = false
    @State private var selectedTime = Date().addingTimeInterval(3600)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Label(l10n.s.keepAwakeTitle, systemImage: "bolt.badge.clock")
                        .font(.headline)
                    Spacer(minLength: 4)
                    statusChip(now: context.date)
                }
                if awake.assertionFailed {
                    Text(awake.isActive ? "Couldn’t restore normal sleep. Try Stop again."
                         : "Couldn’t update sleep prevention. Please try again.")
                        .font(.caption).foregroundStyle(.red)
                }
                HStack(spacing: 6) {
                    ForEach([15, 30, 60, 240], id: \.self) { minutes in
                        sessionButton(minutes < 60 ? "+\(minutes)min" : "+\(minutes / 60)hr") {
                            pickingTime = false
                            awake.addHubDuration(minutes: minutes)
                        }
                    }
                }
                HStack(spacing: 8) {
                    sessionButton("Stay On", symbol: "infinity",
                                  selected: !pickingTime && awake.isActive && awake.endDate == nil) {
                        pickingTime = false
                        awake.activate(minutes: 0)
                    }
                    sessionButton("Set End Time...", symbol: "clock",
                                  selected: pickingTime || (awake.isActive && awake.endDate != nil && !awake.hubIsTimed)) {
                        if !pickingTime { selectedTime = awake.endDate ?? Date().addingTimeInterval(3600) }
                        pickingTime.toggle()
                    }
                }
                if pickingTime { timePicker(now: context.date) }
                Divider()
                HStack(spacing: 12) {
                    Text("Prevent sleep with lid closed").font(.callout)
                    Spacer(minLength: 0)
                    Toggle("Prevent sleep with lid closed", isOn: $awake.clamshellPreferred)
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                        .disabled(!PowerSampler.hasInternalBattery || awake.clamshellSetupInProgress)
                        .accessibilityHint(PowerSampler.hasInternalBattery ? ""
                            : "This Mac does not have a supported built-in lid.")
                }
                if awake.clamshellSetupInProgress {
                    ProgressView(l10n.s.configuring).controlSize(.small)
                }
                if awake.clamshellSetupFailed {
                    Text(l10n.s.sudoersFailed).font(.caption).foregroundStyle(.red)
                }
            }
            .padding(16)
            .frame(width: 320)
        }
        .onAppear { awake.reconcileHubSession() }
        .onExitCommand { dismiss() }
    }

    private func statusChip(now: Date) -> some View {
        Group {
            if awake.isActive {
                Button {
                    pickingTime = false
                    awake.toggle()
                    Self.announce(awake, l10n: l10n)
                } label: {
                    HStack(spacing: 6) {
                        Text(awake.endDate == nil ? "On" : HubStayAwakeSupport.compact(end: awake.endDate, now: now)).monospacedDigit()
                        Image(systemName: "stop.fill").font(.system(size: 8))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Color.orange.opacity(0.13), in: Capsule())
                }
                .buttonStyle(.plain)
                .help("Stop Stay Awake: \(Self.status(awake, now: now, l10n: l10n))")
                .accessibilityLabel("Stop Stay Awake")
                .accessibilityValue(Self.status(awake, now: now, l10n: l10n))
            } else {
                Text("Off").foregroundStyle(.secondary)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
        }
        .font(.system(size: 11, weight: .medium))
        .fixedSize()
    }

    private func sessionButton(_ title: String, symbol: String? = nil, selected: Bool = false,
                               action: @escaping () -> Void) -> some View {
        Button {
            action()
            Self.announce(awake, l10n: l10n)
        } label: {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol).frame(width: 16) }
                Text(title).lineLimit(1)
                if symbol != nil { Spacer(minLength: 0) }
            }
            .font(.system(size: symbol == nil ? 11 : 12, weight: .medium))
            .padding(.horizontal, symbol == nil ? 6 : 10)
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .background(selected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06),
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? Color.accentColor.opacity(0.7) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func timePicker(now: Date) -> some View {
        let end = HubStayAwakeSupport.nextOccurrence(of: selectedTime, now: now)
        return HStack {
            Text("End time").font(.callout)
            if !Calendar.current.isDate(end, inSameDayAs: now) {
                Text("Tomorrow").font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            DatePicker("End time", selection: liveEndTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.field).labelsHidden().fixedSize()
        }
        .help(end.formatted(date: .abbreviated, time: .shortened))
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    /// Only edits from the picker apply a session. Preparing its initial
    /// value when opening the editor leaves the current session untouched.
    private var liveEndTime: Binding<Date> {
        Binding(get: { selectedTime }, set: { time in
            selectedTime = time
            awake.activate(until: HubStayAwakeSupport.nextOccurrence(of: time, now: Date()))
            Self.announce(awake, l10n: l10n)
        })
    }

    static func announce(_ awake: KeepAwakeManager, l10n: L10n) {
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: status(awake, now: Date(), l10n: l10n),
                                        .priority: NSAccessibilityPriorityLevel.medium.rawValue])
    }

    static func status(_ awake: KeepAwakeManager, now: Date, l10n: L10n) -> String {
        if awake.assertionFailed { return "Couldn’t update Stay Awake" }
        if awake.sessionPausedForScreenLock { return "Paused while the screen is locked" }
        guard awake.isActive else { return "Off" }
        guard let end = awake.endDate else { return l10n.s.keepAwakeUntilDisabled }
        if awake.sessionMinutes == nil {
            return "On until \(end.formatted(date: Calendar.current.isDateInToday(end) ? .omitted : .abbreviated, time: .shortened))"
        }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        formatter.calendar = Calendar.current
        let text = formatter.string(from: TimeInterval(max(1, Int(ceil(end.timeIntervalSince(now) / 60))) * 60)) ?? ""
        return "\(l10n.s.keepAwakeEndsIn) \(text)"
    }
}
