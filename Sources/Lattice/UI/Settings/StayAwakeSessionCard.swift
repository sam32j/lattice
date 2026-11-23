// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

/// The session itself: what runs now with a Stop button, the ways to start
/// or extend one, and the default duration and shortcut that start one
/// from elsewhere. Starting a session here never changes the default.
struct StayAwakeSessionCard: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @ObservedObject private var hotkeys = HotkeyManager.shared
    @AppStorage(DefaultsKey.defaultDuration) private var defaultDuration = 0
    @AppStorage(DefaultsKey.hotkeyEnabled) private var hotkeyEnabled = true
    /// Owned by the page, so its expansion animation can key on it.
    @Binding var pickingTime: Bool
    @State private var untilTime = Date().addingTimeInterval(3600)

    static let chipMinutes = [15, 30, 60, 240]

    private var strings: StayAwakeSettingsStrings { FeatureStrings.stayAwakeSettings(l10n.language) }
    private var hub: KeepAwakeHubStrings { FeatureStrings.keepAwakeHub(l10n.language) }
    private var locale: Locale { l10n.language.formattingLocale() }

    private var status: StayAwakeStatus {
        StayAwakeStatus.make(isActive: awake.isActive, automatic: awake.sessionTrigger == .automation,
                             end: awake.endDate, failed: awake.assertionFailed,
                             paused: awake.sessionPausedForScreenLock,
                             conditions: awake.activeAutomationConditions)
    }

    var body: some View {
        SettingsCard {
            statusRow
            VStack(alignment: .leading, spacing: 8) {
                Text(prompt)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 6) {
                    ForEach(Self.chipMinutes, id: \.self) { durationChip($0) }
                }
                HStack(spacing: 8) {
                    StayAwakeSessionButton(title: strings.untilOff, symbol: "infinity",
                                           selected: !pickingTime && awake.isActive
                                               && awake.sessionTrigger == .manual && awake.endDate == nil) {
                        pickingTime = false
                        awake.activate(minutes: 0)
                    }
                    StayAwakeSessionButton(title: strings.untilTime, symbol: "clock", selected: pickingTime) {
                        if !pickingTime { untilTime = awake.endDate ?? Date().addingTimeInterval(3600) }
                        pickingTime.toggle()
                    }
                }
                if pickingTime {
                    untilRow
                        .transition(.settingsReveal)
                }
            }
            Divider()
            SettingsRow(symbol: "timer", title: l10n.s.defaultDurationLabel, caption: strings.defaultDurationCaption) {
                Picker(l10n.s.defaultDurationLabel, selection: $defaultDuration) {
                    ForEach(DurationPicker.choices, id: \.self) { minutes in
                        Text(DurationPicker.title(for: minutes, l10n.s)).tag(minutes)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
            ShortcutPreferenceRow(role: .keepAwake, label: strings.shortcutTitle, help: strings.shortcutCaption,
                                  symbolName: "keyboard") {
                HotkeyManager.shared.syncWithPreferences()
            }
            if hotkeyEnabled, hotkeys.registrationFailed {
                Text(l10n.s.shortcutUnavailable)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.leading, settingsRowTextInset)
                    .transition(.settingsReveal)
            }
        }
        .onAppear { defaultDuration = Defaults.sanitizedDefaultDuration(defaultDuration) }
    }

    // MARK: Status

    @ViewBuilder
    private var statusRow: some View {
        // A countdown redraws every second only while there is one.
        if status.countdownEnd != nil {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                statusContent(now: context.date)
            }
        } else {
            statusContent(now: Date())
        }
    }

    private func statusContent(now: Date) -> some View {
        let status = status
        return HStack(spacing: 12) {
            StayAwakeRing(fraction: StayAwakeStatus.ringFraction(isActive: awake.isActive,
                                                                 start: awake.sessionStartDate,
                                                                 end: awake.endDate, now: now),
                          isActive: awake.isActive)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title(for: status))
                        .font(.headline)
                        .monospacedDigit()
                    if let pill = status.pill {
                        Text(pill == .automatic ? strings.automaticPill : strings.untilOffPill)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                }
                Text(caption(for: status.caption))
                    .font(.caption)
                    .foregroundStyle(status.caption.isError ? AnyShapeStyle(Color.red) : AnyShapeStyle(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 12)
            if awake.isActive {
                Button(hub.stop) {
                    pickingTime = false
                    awake.toggle()
                }
                .controlSize(.regular)
                .accessibilityLabel(hub.stop)
                .accessibilityValue(caption(for: status.caption))
            }
        }
    }

    private func title(for status: StayAwakeStatus) -> String {
        guard status.isAwake else { return strings.notRunning }
        guard let end = status.countdownEnd else { return strings.awake }
        return strings.awake + " · " + String(format: strings.leftFormat, DurationPicker.remainingText(until: end))
    }

    private func caption(for caption: StayAwakeStatus.Caption) -> String {
        switch caption {
        case .normalRules: return l10n.s.keepAwakeNormalRules
        case .endsAt(let end):
            return String(format: strings.endsAtFormat,
                          end.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)))
        case .untilDisabled: return l10n.s.keepAwakeUntilDisabled
        case .automatic(let conditions):
            return FeatureStrings.keepAwakeAutomation(l10n.language).activeStatus(for: conditions)
        case .paused: return hub.paused
        case .restoreFailed: return hub.restoreFailed
        case .activationFailed: return hub.activationFailed
        }
    }

    // MARK: Start

    private var prompt: String {
        switch StayAwakeStartPrompt.make(isActive: awake.isActive, isTimed: awake.hubIsTimed) {
        case .startSession: return strings.startSession
        case .addTime: return strings.addTime
        case .switchToTimed: return strings.switchToTimed
        }
    }

    private func durationChip(_ minutes: Int) -> some View {
        let extends = awake.hubIsTimed
        let increment = KeepAwakeTimeFormat.increment(minutes: minutes, locale: locale)
        let title = extends ? increment : String(increment.drop { $0 == "+" })
        let spoken = Self.spokenDuration(minutes: minutes, locale: locale)
        return StayAwakeSessionButton(
            title: title,
            accessibilityName: String(format: extends ? strings.addChipFormat : strings.startChipFormat, spoken)
        ) {
            pickingTime = false
            awake.addHubDuration(minutes: minutes)
        }
    }

    private static func spokenDuration(minutes: Int, locale: Locale) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        var calendar = Calendar.current
        calendar.locale = locale
        formatter.calendar = calendar
        return formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes)"
    }

    /// An explicit end time: a time already past today means tomorrow.
    private var untilRow: some View {
        let end = HubStayAwakeSupport.nextOccurrence(of: untilTime, now: Date())
        return HStack(spacing: 8) {
            Text(strings.untilPrompt)
                .font(.callout)
            DatePicker(strings.untilPrompt, selection: $untilTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(.field)
                .labelsHidden()
                .fixedSize()
                .environment(\.locale, locale)
            if !Calendar.current.isDate(end, inSameDayAs: Date()) {
                Text(hub.tomorrow)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(strings.start) {
                awake.activate(until: HubStayAwakeSupport.nextOccurrence(of: untilTime, now: Date()))
                pickingTime = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// How much of the session is left, around the Stay Awake bolt: empty with
/// a grey core while nothing runs, full for a session with no end.
struct StayAwakeRing: View {
    let fraction: Double
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(KeepAwakeAppearance.indicatorColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                // An ended session empties at once rather than draining.
                .animation(reduceMotion || !isActive ? nil : .linear(duration: 1), value: fraction)
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isActive ? KeepAwakeAppearance.indicatorColor : Color.secondary)
        }
        .frame(width: 38, height: 38)
        .accessibilityHidden(true)
    }
}

enum DurationPicker {
    static let choices = [15, 30, 60, 120, 240, 480, 0]

    static func title(for minutes: Int, _ s: Strings) -> String {
        switch minutes {
        case 15: return s.minutes15
        case 30: return s.minutes30
        case 60: return s.hour1
        case 120: return s.hours2
        case 240: return s.hours4
        case 480: return s.hours8
        default: return s.indefinite
        }
    }

    static func remainingText(until end: Date) -> String {
        let total = max(0, Int(end.timeIntervalSinceNow))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d h %02d min", hours, minutes) }
        if minutes > 0 { return String(format: "%d min %02d s", minutes, seconds) }
        return "\(seconds) s"
    }
}
