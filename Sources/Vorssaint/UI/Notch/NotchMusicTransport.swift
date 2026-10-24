// SPDX-License-Identifier: GPL-3.0-or-later
import SwiftUI

struct NotchMusicTransport: View {
    let playback: NotchPlayback
    /// The home card and a short player use the smaller buttons.
    var compact = false
    /// The player's row gives each button an equal place across the island,
    /// and keeps the place of a skip the player does not offer.
    var slot: CGFloat? = nil
    // Automation discovery and consent finish after the first render while the
    // track stays the same, so this row must observe the service itself.
    @ObservedObject private var swipe = NotchMusicSwipeState.shared
    @ObservedObject private var service = NotchMusicService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchSettingsPreview) private var preview
    /// What a tap on play or pause asked for, shown at once while the player
    /// takes its round trip to say so. It gives way to the player's word.
    @State private var requestedPlaying: Bool?
    private var text: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }
    private var height: CGFloat { compact ? 36 : 44 }
    private var showsPlaying: Bool { requestedPlaying ?? playback.isPlaying }

    var body: some View {
        if !playback.canSendCommandsDirectly, service.automationAvailability?.access != .granted {
            HStack(spacing: 10) {
                toggleButton
                if service.automationAvailability?.access == .consent {
                    Button(FeatureStrings.notchMusicExtras(l10n.language).allowPlayback) { service.requestAutomationAccess() }
                        .disabled(service.requestingAutomation)
                    if service.requestingAutomation { ProgressView().controlSize(.small) }
                } else if service.automationAvailability?.access == .denied {
                    Button(l10n.s.permissionOpenSettings) { Permissions.shared.openAutomationSettings() }
                    Button { service.refreshAutomation() } label: { Image(systemName: "arrow.clockwise") }
                        .accessibilityLabel(FeatureStrings.notchMusicExtras(l10n.language).refresh)
                } else {
                    Button(FeatureStrings.notchMusicExtras(l10n.language).openPlayer) { RadialNowPlayingApplication.open(playback.track) }
                }
            }
            .buttonStyle(.borderless).font(.caption).frame(height: height)
        } else {
            transportButtons
        }
    }

    /// The player's own glyphs, white on the island with no plate behind
    /// them, as on the lock screen. Play and pause stand out by size.
    private var transportButtons: some View {
        HStack(spacing: slot == nil ? (compact ? 12 : 18) : 0) {
            if !service.lacksTrackSkipping(.previous) {
                playbackButton("backward.fill", title: text.mediaPrevious, command: .previous).frame(width: slot)
            } else if let slot {
                Color.clear.frame(width: slot)
            }
            toggleButton.frame(width: slot)
            if !service.lacksTrackSkipping(.next) {
                playbackButton("forward.fill", title: text.mediaNext, command: .next).frame(width: slot)
            } else if let slot {
                Color.clear.frame(width: slot)
            }
        }
        .frame(height: height)
    }

    private var toggleButton: some View {
        Button {
            if service.canPerform(.toggle) {
                // Only a player the island writes to directly answers fast enough
                // to show its word early; a slower path waits for the player.
                let direct = playback.canSendCommandsDirectly
                if service.send(.toggle, context: playback.commandContext), direct { requestedPlaying = !showsPlaying }
            } else { service.requestAutomationAccess() }
        } label: {
            Image(systemName: showsPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: compact ? 22 : slot == nil ? 26 : 28, weight: .semibold))
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: showsPlaying)
                .frame(width: height, height: height)
                .contentShape(Circle())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: height / 2))
        // A second tap before the player answers asks for the state after it,
        // so only the player reaching what was asked ends the early word.
        .onChange(of: playback.isPlaying) { if playback.isPlaying == requestedPlaying { requestedPlaying = nil } }
        .onChange(of: playback.track) { requestedPlaying = nil }
        // A player that never answers leaves the button as it was.
        .task(id: requestedPlaying) {
            guard requestedPlaying != nil else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled { requestedPlaying = nil }
        }
        .disabled(!service.canPerform(.toggle)
                  && (service.automationAvailability?.access != .consent || service.requestingAutomation))
        // A preview in Settings must not take Space from the window it sits in.
        .keyboardShortcut(preview ? nil : KeyboardShortcut(.space, modifiers: []))
        .accessibilityLabel(text.mediaPlayPause)
        .help(service.automationAvailability?.access == .consent
              ? FeatureStrings.notchMusicExtras(l10n.language).allowPlayback : text.mediaPlayPause)
    }

    private func playbackButton(_ symbol: String, title: String, command: NotchMusicService.Command) -> some View {
        Button { service.send(command, context: playback.commandContext) } label: {
            Image(systemName: symbol)
                .font(.system(size: compact ? 16 : 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: height, height: height)
                .background {
                    NotchMusicSwipeBackdrop(direction: command == .next ? .next : .previous,
                                           frame: preview ? .init() : swipe.frame, size: height)
                }
                .contentShape(Circle())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: height / 2))
        .disabled(!service.canPerform(command))
        .accessibilityLabel(title)
        .help(title)
    }
}

