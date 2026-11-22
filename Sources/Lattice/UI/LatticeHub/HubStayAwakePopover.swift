// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

struct HubStayAwakePopover: View {
    @ObservedObject private var awake = KeepAwakeManager.shared
    @ObservedObject private var l10n = L10n.shared
    private var text: KeepAwakeHubStrings { FeatureStrings.keepAwakeHub(l10n.language) }
    private var locale: Locale { l10n.language.formattingLocale() }
    @Environment(\.dismiss) private var dismiss
    @State private var pickingTime = false
    @State private var selectedTime = Date().addingTimeInterval(3600)
    /// Lid-sleep setup usually finishes within milliseconds. Showing its
    /// progress row and disabling the switch for that instant resized the
    /// popover twice and flashed it black, so both wait until setup has run
    /// long enough to be worth showing.
    @State private var showsSetupProgress = false
    private static let setupProgressDelay: TimeInterval = 0.4

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
                    Text(awake.isActive ? text.restoreFailed
                         : text.activationFailed)
                        .font(.caption).foregroundStyle(.red)
                }
                HStack(spacing: 6) {
                    ForEach([15, 30, 60, 240], id: \.self) { minutes in
                        sessionButton(KeepAwakeTimeFormat.increment(minutes: minutes, locale: locale)) {
                            pickingTime = false
                            awake.addHubDuration(minutes: minutes)
                        }
                    }
                }
                HStack(spacing: 8) {
                    sessionButton(text.stayOn, symbol: "infinity",
                                  selected: !pickingTime && awake.isActive && awake.endDate == nil) {
                        pickingTime = false
                        awake.activate(minutes: 0)
                    }
                    sessionButton(text.setEndTime, symbol: "clock",
                                  selected: pickingTime || (awake.isActive && awake.endDate != nil && !awake.hubIsTimed)) {
                        if !pickingTime { selectedTime = awake.endDate ?? Date().addingTimeInterval(3600) }
                        pickingTime.toggle()
                    }
                }
                if pickingTime { timePicker(now: context.date) }
                Divider()
                HStack(spacing: 12) {
                    Text(text.preventLidSleep).font(.callout)
                    Spacer(minLength: 0)
                    Toggle(text.preventLidSleep, isOn: $awake.clamshellPreferred)
                        .labelsHidden().toggleStyle(HubPopoverSwitchStyle())
                        .disabled(!PowerSampler.hasInternalBattery || showsSetupProgress)
                        .accessibilityHint(PowerSampler.hasInternalBattery ? ""
                            : text.unsupportedLid)
                }
                if showsSetupProgress {
                    ProgressView(l10n.s.configuring).controlSize(.small)
                }
                if awake.clamshellSetupFailed {
                    Text(l10n.s.sudoersFailed).font(.caption).foregroundStyle(.red)
                }
            }
            .padding(16)
            .frame(width: 320)
        }
        .onAppear {
            awake.reconcileHubSession()
            if awake.clamshellSetupInProgress { scheduleSetupProgress() }
        }
        .onChange(of: awake.clamshellSetupInProgress) { _, inProgress in
            if inProgress { scheduleSetupProgress() } else { showsSetupProgress = false }
        }
        .onExitCommand { dismiss() }
    }

    private func scheduleSetupProgress() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.setupProgressDelay) {
            if awake.clamshellSetupInProgress { showsSetupProgress = true }
        }
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
                        Text(awake.endDate == nil ? text.on : HubStayAwakeSupport.compact(end: awake.endDate, now: now, locale: locale)).monospacedDigit()
                        Image(systemName: "stop.fill").font(.system(size: 8))
                    }
                    .foregroundStyle(KeepAwakeAppearance.indicatorColor)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(KeepAwakeAppearance.indicatorColor.opacity(0.13), in: Capsule())
                }
                .buttonStyle(.plain)
                .help(String(format: text.stopStatus, Self.status(awake, now: now, l10n: l10n)))
                .accessibilityLabel(text.stop)
                .accessibilityValue(Self.status(awake, now: now, l10n: l10n))
            } else {
                Text(text.off).foregroundStyle(.secondary)
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
                Text(title).lineLimit(1).minimumScaleFactor(0.75)
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
            Text(text.endTime).font(.callout)
            if !Calendar.current.isDate(end, inSameDayAs: now) {
                Text(text.tomorrow).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            DatePicker(text.endTime, selection: liveEndTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.field).labelsHidden().fixedSize()
                .environment(\.locale, locale)
        }
        .help(end.formatted(.dateTime.locale(locale)))
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
        KeepAwakeHubStatus.text(active: awake.isActive, failed: awake.assertionFailed,
                                paused: awake.sessionPausedForScreenLock, end: awake.endDate,
                                sessionMinutes: awake.sessionMinutes, now: now, language: l10n.language)
    }
}

/// A switch drawn in SwiftUI. The native one repaints with its window's key
/// state, and this popover's window takes and gives up key status around a
/// click, so the native switch flashed between the accent colour and a dark
/// inactive grey every time it was flipped.
struct HubPopoverSwitchStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Color.accentColor : Color.primary.opacity(0.18))
                // A fixed size, so the ZStack's alignment can move it between
                // the ends; a free circle fills the track and stays centred.
                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.25), radius: 0.8, y: 0.5)
                    .padding(1.5)
            }
            .frame(width: 30, height: 17)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.easeOut(duration: 0.16), value: configuration.isOn)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}
