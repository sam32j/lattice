// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI


struct NotchTimerView: View {
    let size: CGSize

    @ObservedObject private var service = NotchTimerService.shared
    @ObservedObject private var notch = NotchService.shared
    @ObservedObject private var l10n = L10n.shared

    @AppStorage(DefaultsKey.notchTimerMode)
    private var mode: NotchTimerMode = .timer

    @AppStorage(DefaultsKey.notchTimerMinutes)
    private var savedMinutes = 16

    @AppStorage(DefaultsKey.notchPomodoroFocusMinutes)
    private var focusMinutes = 25

    @AppStorage(DefaultsKey.notchPomodoroShortBreakMinutes)
    private var shortBreakMinutes = 5

    @AppStorage(DefaultsKey.notchPomodoroLongBreakMinutes)
    private var longBreakMinutes = 15

    @AppStorage(DefaultsKey.notchPomodoroLongBreakInterval)
    private var longBreakInterval = 2

    @AppStorage(DefaultsKey.notchPomodoroTotalSessions)
    private var totalSessions = 4

    @AppStorage(NotchLayout.timerSettingsExpandedDefaultsKey)
    private var settingsExpanded = false

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @Environment(\.notchBand)
    private var band

    @State private var clockTwinkling = false
    @State private var twinkleTask: Task<Void, Never>?

    private var text: NotchActivityStrings {
        FeatureStrings.notchActivities(l10n.language)
    }

    private var ui: NotchTimerUIStrings { FeatureStrings.notchTimerUI(l10n.language) }

    private var locale: Locale {
        Locale(identifier: l10n.language.rawValue)
    }

    private var accent: Color {
        Color(red: 1, green: 150.0 / 255, blue: 56.0 / 255)
    }

    private var transition: Animation? {
        reduceMotion ? nil : .smooth(duration: 0.32)
    }

    private var hasSession: Bool {
        service.session.hasSession
    }

    private var displayedMode: NotchTimerMode {
        hasSession ? service.session.mode : mode
    }

    private var clockSize: CGFloat {
        min(58, max(40, size.width * 0.15))
    }

    private var naturalHeight: CGFloat {
        NotchLayout.timer(
            mode: displayedMode,
            hasSession: hasSession,
            height: size.height
        )
    }

    private var rulerRevealHeight: CGFloat {
        guard !hasSession, displayedMode != .stopwatch else {
            return 0
        }

        return NotchLayout.timerRowSpacing
            + NotchLayout.timerRulerHeight
    }

    private var settingsRevealHeight: CGFloat {
        guard !hasSession, displayedMode == .pomodoro else {
            return 0
        }

        return NotchLayout.timerBottomRowHeight(mode: .pomodoro)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            mainRow

            // Keep the same ruler mounted across all modes.
            // Its container closes from the bottom edge.
            
            rulerSection
                .frame(
                    height: rulerRevealHeight,
                    alignment: .top
                )
                .clipped()
                .opacity(displayedMode == .stopwatch ? 0 : 1)
                .transaction { transaction in
                    if displayedMode == .stopwatch {
                        transaction.animation = nil
                    }
                }
                .allowsHitTesting(rulerRevealHeight > 0)


            // Pomodoro's controls have their own bottom mask.
            settingsSection
                .frame(
                    height: settingsRevealHeight,
                    alignment: .top
                )
                .clipped()
                .allowsHitTesting(settingsRevealHeight > 0)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .top
        )
        .frame(height: naturalHeight, alignment: .top)
        .clipped()
        .tint(accent)
        .animation(transition, value: displayedMode)
        .animation(transition, value: hasSession)
        .animation(transition, value: settingsExpanded)
        .onChange(of: settingsExpanded) { _, _ in
            notch.refreshPresentation()
        }
        .onDisappear {
            twinkleTask?.cancel()
        }
        .notchBand {
            EmptyView()
        } trailing: {
            headerControls
        }
    }

    // MARK: - Main control row

    
    private var mainRow: some View {
        HStack(spacing: 8) {
            if hasSession && service.session.completed &&
                (service.session.mode == .timer || service.session.cycleFinished) {

                let pomodoroDone = service.session.cycleFinished

                roundButton(
                    symbol: pomodoroDone ? "checkmark" : "stop.fill",
                    title: pomodoroDone ? ui.done : ui.stop,
                    color: pomodoroDone ? .green : .red,
                    action: stopTimer
                )
                .frame(width: 52, height: 52)

            } else {
                leadingControl
                    .frame(width: 52, height: 52)

                if hasSession {
                    roundButton(
                        symbol: "stop.fill",
                        title: ui.stop,
                        color: .red,
                        action: stopTimer
                    )
                    .frame(width: 52, height: 52)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 0) {
                phaseReading
                clockReading
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .layoutPriority(1)

            modeRail
                .frame(
                    width: NotchTimerModeRail.width,
                    height: NotchTimerModeRail.height
                )
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .frame(height: NotchLayout.timerMainRowHeight)
    }


    @ViewBuilder
    private var leadingControl: some View {
        if !hasSession {
            roundButton(
                symbol: "play.fill",
                title: text.start,
                action: startTimer
            )
        } else if service.session.completed {
            if service.session.canStartNext {
                roundButton(
                    symbol: "play.fill",
                    title: text.start,
                    action: service.startNext
                )
            } else {
                Color.clear.frame(width: 52, height: 52)
            }
        } else {
            roundButton(
                symbol: service.session.isPaused
                    ? "play.fill"
                    : "pause.fill",
                title: service.session.isPaused
                    ? text.resume
                    : l10n.s.actionPause,
                action: service.pauseOrResume
            )
        }
    }

    private var modeRail: some View {
        NotchTimerModeRail(mode: displayedMode) { selected in
            selectMode(selected)
        }
        .allowsHitTesting(!hasSession)
        .overlay {
            if hasSession {
                NotchTimerModeLockOverlay {
                    twinkleRemainingTime()
                }
            }
        }
        .accessibilityLabel(text.timer)
    }

    // MARK: - Clock

    @ViewBuilder
    private var clockReading: some View {
        if service.session.isRunning {
            TimelineView(
                .periodic(
                    from: .now,
                    by: displayedMode == .stopwatch
                        ? 1.0 / 30.0
                        : 1.0
                )
            ) { _ in
                clockContent(at: service.now)
            }
        } else {
            clockContent(at: service.now)
        }
    }

    
    private func clockContent(at now: TimeInterval) -> some View {
        let normal = clockValue(
            at: now,
            includesMilliseconds: false
        )

        let precise = clockValue(
            at: now,
            includesMilliseconds: true
        )

        return ZStack(alignment: .trailing) {
            Group {
                if displayedMode == .stopwatch {
                    ViewThatFits(in: .horizontal) {
                        clock(precise)
                            .fixedSize(
                                horizontal: true,
                                vertical: false
                            )

                        clock(normal)
                    }
                } else {
                    clock(normal)
                }
            }
            // Each mode has its own clock identity,
            // allowing the outgoing reading to fade
            // while the incoming reading fades in.
            .id(displayedMode)
            .transition(.opacity)
        }
        // The right edge remains anchored beside
        // the mode rail throughout the transition.
        .frame(
            maxWidth: .infinity,
            alignment: .trailing
        )
        .animation(
            reduceMotion
                ? nil
                : .easeInOut(duration: 0.20),
            value: displayedMode
        )
        .opacity(clockTwinkling ? 0.42 : 1)
        .shadow(
            color: accent.opacity(
                clockTwinkling ? 0.85 : 0
            ),
            radius: clockTwinkling ? 12 : 0
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            hasSession
                ? text.phase(service.session.phase)
                : title(for: displayedMode)
        )
        .accessibilityValue(normal)
    }


    private func clockValue(
        at now: TimeInterval,
        includesMilliseconds: Bool
    ) -> String {
        if hasSession {
            return NotchTimerSupport.clockText(
                for: service.session,
                at: now,
                includesMilliseconds: includesMilliseconds
            )
        }

        switch displayedMode {
        case .stopwatch:
            return NotchTimerSupport.stopwatchText(
                0,
                includesMilliseconds: includesMilliseconds
            )

        case .timer:
            return NotchTimerSupport.clockText(
                Double(timerMinutes.wrappedValue) * 60
            )

        case .pomodoro:
            return NotchTimerSupport.clockText(
                Double(configuration.focusMinutes) * 60
            )
        }
    }

    private func clock(_ value: String) -> some View {
        let parts = value.split(
            separator: ".",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )

        let primary = String(parts[0])
        let fraction = parts.count > 1
            ? "." + String(parts[1])
            : ""

        return (
            Text(primary)
                .font(
                    .system(
                        size: clockSize,
                        weight: .thin
                    )
                )
            +
            Text(fraction)
                .font(
                    .system(
                        size: clockSize * 0.43,
                        weight: .light
                    )
                )
        )
        .monospacedDigit()
        .foregroundStyle(accent)
        .lineLimit(1)
        .minimumScaleFactor(0.55)
    }

    // MARK: - Persistent ruler

    private var rulerSection: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: NotchLayout.timerRowSpacing)

            NotchTimerRuler(
                minutes: displayedMode == .pomodoro
                    ? binding(.focus)
                    : timerMinutes,
                label: displayedMode == .pomodoro
                    ? text.focus
                    : text.timer,
                locale: locale,
                range: displayedMode == .pomodoro
                    ? NotchPomodoroConfiguration.focusRange
                    : 1...180
            )
            .frame(
                height: NotchLayout.timerRulerHeight
            )
        }
        .frame(
            height: NotchLayout.timerRowSpacing
                + NotchLayout.timerRulerHeight,
            alignment: .top
        )
    }

    // MARK: - Pomodoro settings


    private var pomodoroSummary: String {
        let config = configuration

        let short = display(.shortBreak, config.shortBreakMinutes)
        let long = display(.longBreak, config.longBreakMinutes)

        return "\(config.totalSessions) \(ui.sessionUnit) · \(short) / \(long) \(ui.breakUnit)"
    }


    private var settingsSection: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: NotchLayout.timerRowSpacing)

            Button {
                withAnimation(transition) {
                    settingsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(ui.focusAndBreaks)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.82))
                        .fixedSize(horizontal: true, vertical: false)

                    Spacer(minLength: 8)

                    Text(pomodoroSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(
                            .degrees(settingsExpanded ? 180 : 0)
                        )
                }
                .contentShape(Rectangle())
                .frame(height: NotchLayout.timerSettingsHeaderHeight)

            }
            .buttonStyle(.plain)

            HStack(spacing: 5) {
                readout(.shortBreak)
                readout(.longBreak)
                readout(.longBreakInterval)
                readout(.totalSessions)
            }
            .frame(
                height: NotchLayout.timerSettingsFieldsHeight
            )
            .frame(
                height: settingsExpanded
                    ? NotchLayout.timerSettingsFieldsHeight
                    : 0,
                alignment: .top
            )
            .clipped()
            .allowsHitTesting(settingsExpanded)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .top
        )
    }

    
    private func readout(
        _ option: NotchPomodoroOption
    ) -> some View {
        let current = settingValue(option)

        let valid = option.choices(
            totalSessions: configuration.totalSessions
        )

        let unavailable = configuration.totalSessions <= 2
            && (option == .longBreak
                || option == .longBreakInterval)

        return VStack(alignment: .leading, spacing: 4) {
            // Static label: outside the menu highlight.
            Text(compactTitle(option))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            // Only this value row is interactive.
            NotchMenuButton(
                title: title(option),
                items: valid.map { choice in
                    NotchMenuItem(
                        title: display(option, choice),
                        checked: choice == current
                    ) {
                        setSetting(option, to: choice)
                    }
                }
            ) {
                HStack(spacing: 4) {
                    Text(display(option, current))
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 2)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .frame(height: 28)
                .contentShape(
                    RoundedRectangle(cornerRadius: 6)
                )
            }
            .disabled(unavailable)
            .help(title(option))
            .accessibilityValue(display(option, current))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: NotchLayout.timerSettingsFieldsHeight)
        .padding(.horizontal, 2)
    }


    private func compactTitle(
        _ option: NotchPomodoroOption
    ) -> String {
        switch option {
        case .focus:
            return text.focus
        case .shortBreak:
            return text.shortBreak
        case .longBreak:
            return text.longBreak
        case .longBreakInterval:
            return ui.longEvery
        case .totalSessions:
            return ui.sessions
        }
    }

    private var configuration: NotchPomodoroConfiguration {
        NotchPomodoroConfiguration(
            focusMinutes: focusMinutes,
            shortBreakMinutes: shortBreakMinutes,
            longBreakMinutes: longBreakMinutes,
            longBreakInterval: longBreakInterval,
            totalSessions: totalSessions
        )
    }

    private func settingValue(
        _ option: NotchPomodoroOption
    ) -> Int {
        switch option {
        case .focus:
            return configuration.focusMinutes
        case .shortBreak:
            return configuration.shortBreakMinutes
        case .longBreak:
            return configuration.longBreakMinutes
        case .longBreakInterval:
            return configuration.longBreakInterval
        case .totalSessions:
            return configuration.totalSessions
        }
    }

    private func setSetting(
        _ option: NotchPomodoroOption,
        to value: Int
    ) {
        guard option.choices(
            totalSessions: configuration.totalSessions
        ).contains(value) else {
            return
        }

        switch option {
        case .focus:
            focusMinutes = value

        case .shortBreak:
            shortBreakMinutes = value

        case .longBreak:
            longBreakMinutes = value

        case .longBreakInterval:
            longBreakInterval = value

        case .totalSessions:
            totalSessions = value

            let permitted = NotchPomodoroConfiguration
                .longBreakIntervalChoices(
                    totalSessions: value
                )

            if !permitted.contains(longBreakInterval) {
                longBreakInterval = 0
            }
        }
    }

    private var timerMinutes: Binding<Int> {
        Binding(
            get: {
                NotchTimerSupport.timerMinutes(savedMinutes)
            },
            set: {
                savedMinutes = NotchTimerSupport.timerMinutes($0)
            }
        )
    }

    private func binding(
        _ option: NotchPomodoroOption
    ) -> Binding<Int> {
        Binding(
            get: { settingValue(option) },
            set: { setSetting(option, to: $0) }
        )
    }

    private func title(
        _ option: NotchPomodoroOption
    ) -> String {
        switch option {
        case .focus:
            return text.focus
        case .shortBreak:
            return text.shortBreak
        case .longBreak:
            return text.longBreak
        case .longBreakInterval:
            return text.longBreakInterval
        case .totalSessions:
            return text.totalSessions
        }
    }

    private func display(
        _ option: NotchPomodoroOption,
        _ value: Int
    ) -> String {
        if option == .longBreakInterval && value == 0 {
            return ui.off
        }

        return option.isDuration
            ? NotchTimerSupport.compactText(
                Double(value) * 60,
                locale: locale
            )
            : String(value)
    }

    // MARK: - Header controls

    private var headerControls: some View {
        HStack(spacing: 10) {
            headerModeControl
        }
        .frame(height: NotchLayout.headerHeight)
    }

    @ViewBuilder
    private var headerModeControl: some View {
        modeMenu
    }

    private var modeMenu: some View {
        let current = title(for: mode)

        let named = !band.besideCamera
            || NotchTimerSupport.ModePicker.menuNamesFit(
                NotchTimerMode.allCases.map(title(for:)),
                in: max(0, band.side - 38)
            )

        return NotchMenuButton(
            title: text.timer,
            items: NotchTimerMode.allCases.map { candidate in
                NotchMenuItem(
                    title: title(for: candidate),
                    checked: candidate == mode
                ) {
                    selectMode(candidate)
                }
            }
        ) {
            Group {
                if named {
                    Text(current)
                        .font(
                            .system(
                                size: NotchTimerSupport
                                    .ModePicker.labelSize,
                                weight: .medium
                            )
                        )
                } else {
                    Image(
                        systemName: NotchTimerSupport
                            .ModePicker.symbol(for: mode)
                    )
                    .font(.system(size: 12))
                }
            }
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 4)
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .help(current)
        .accessibilityValue(current)
    }

    
    private var phaseReading: some View {
        let session = service.session
        let phase: String
        let progress: String

        if hasSession {
            phase = session.cycleFinished
                ? text.pomodoroFinished
                : session.mode == .pomodoro
                    ? text.phase(session.phase)
                    : title(for: session.mode)

            progress = session.mode == .pomodoro && !session.cycleFinished
                ? " \(session.sessionNumber)/\(session.configuration.totalSessions)"
                : ""
        } else {
            phase = displayedMode == .pomodoro
                ? text.focus
                : title(for: displayedMode)

            progress = displayedMode == .pomodoro
                ? " 1/\(configuration.totalSessions)"
                : ""
        }

        let status: String
        if !hasSession {
            status = ui.ready
        } else if session.completed {
            status = text.finished
        } else if session.isPaused {
            status = ui.paused
        } else {
            status = ui.running
        }

        let subtitle = session.cycleFinished
            ? phase
            : "\(phase)\(progress) · \(status)"

        return Text(subtitle)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityLabel(subtitle)
}


    private func title(
        for mode: NotchTimerMode
    ) -> String {
        switch mode {
        case .timer:
            return text.timer
        case .pomodoro:
            return text.pomodoro
        case .stopwatch:
            return text.stopwatch
        }
    }

    // MARK: - Actions

    private func selectMode(
        _ selected: NotchTimerMode
    ) {
        guard !hasSession else {
            twinkleRemainingTime()
            return
        }

        guard selected != mode else {
            return
        }

        // Shared by menu clicks, rail clicks, and rail scrolls.
        // NotchService checks the user's haptics preference.
        // The rail emits one selection per gesture.
        notch.provideHapticFeedback()

        withAnimation(transition) {
            mode = selected
        }

        // Avoid transitionContent: .replace, which would
        // recreate the ruler and rail mid-animation.
        notch.refreshPresentation()
    }

    private func startTimer() {
        service.start(
            mode: mode,
            minutes: timerMinutes.wrappedValue
        )

        notch.refreshPresentation()
    }

    private func stopTimer() {
        service.cancel()
        notch.refreshPresentation()
    }

    private func twinkleRemainingTime() {
        guard hasSession else {
            return
        }

        twinkleTask?.cancel()
        clockTwinkling = false

        withAnimation(.easeInOut(duration: 0.12)) {
            clockTwinkling = true
        }

        twinkleTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(160))
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            withAnimation(.easeOut(duration: 0.32)) {
                clockTwinkling = false
            }
        }
    }

    // MARK: - Shared circular button

    private func roundButton(
        symbol: String,
        title: String,
        color: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        let tint = color ?? accent

        return Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(
                    tint.opacity(0.22),
                    in: Circle()
                )
                .contentShape(Circle())
        }
        .buttonStyle(
            NotchButtonStyle(cornerRadius: 26)
        )
        .accessibilityLabel(title)
        .help(title)
    }
}


// MARK: - Locked mode input surface

/// Intercepts interactions above the mode rail while a
/// session exists, without changing the rail's selection.
///
/// The same 40-point, one-gesture latch prevents a single
/// fast swipe from repeatedly triggering the clock pulse.
private struct NotchTimerModeLockOverlay: NSViewRepresentable {
    let onAttempt: () -> Void

    func makeNSView(context: Context) -> Control {
        let view = Control()
        view.onAttempt = onAttempt
        return view
    }

    func updateNSView(_ view: Control, context: Context) {
        view.onAttempt = onAttempt
    }

    final class Control: NSView {
        var onAttempt: (() -> Void)?

        private var accumulated: CGFloat = 0
        private var consumed = false
        private var lastTimestamp: TimeInterval?

        override func mouseDown(with event: NSEvent) {
            onAttempt?()
        }

        override func scrollWheel(with event: NSEvent) {
            // Never react to momentum events.
            guard event.momentumPhase.isEmpty else {
                return
            }

            if event.phase.contains(.began)
                || event.phase.contains(.mayBegin) {
                reset()
            }

            if event.phase.contains(.ended)
                || event.phase.contains(.cancelled) {
                return
            }

            if event.phase.isEmpty {
                if let lastTimestamp,
                event.timestamp - lastTimestamp > 0.45 {
                    reset()
                }
            }

            lastTimestamp = event.timestamp

            guard !consumed else { return }

            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY

            guard abs(dy) > abs(dx) else { return }

            let delta = event.hasPreciseScrollingDeltas
                ? dy
                : dy * 16

            if accumulated * delta < 0 {
                accumulated = 0
            }

            accumulated += delta

            guard abs(accumulated) >= 40 else {
                return
            }

            consumed = true
            onAttempt?()
        }

        private func reset() {
            accumulated = 0
            consumed = false
        }
    }
}
