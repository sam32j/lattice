// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct NotchMusicView: View {
    let size: CGSize
    /// Room lyrics or the queue may add below the player.
    let extrasHeight: CGFloat
    @ObservedObject private var service = NotchMusicService.shared
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var shuffle = NotchShuffleService.shared
    @ObservedObject private var repeating = NotchRepeatService.shared
    @AppStorage(DefaultsKey.notchLyricsEnabled) private var lyricsEnabled = true
    @AppStorage(DefaultsKey.notchQueueEnabled) private var queueEnabled = true
    @State private var extra: MusicExtra?
    private enum MusicExtra { case lyrics, queue }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchSettingsPreview) private var preview
    @Environment(\.notchBand) private var band
    private var text: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }
    /// The cover's own colour, used for the moving parts that belong to this
    /// track. Neutral covers keep them white.
    private var accent: Color { service.artworkTint?.color ?? .white }
    private var showsLyrics: Bool { lyricsEnabled && AppFeature.notchLyrics.isAvailable }
    private var showsQueue: Bool { queueEnabled && AppFeature.notchQueue.isAvailable }
    private var openExtra: MusicExtra? {
        guard service.playback != nil else { return nil }
        switch extra {
        case .lyrics: return showsLyrics ? .lyrics : nil
        case .queue: return showsQueue ? .queue : nil
        case nil: return nil
        }
    }
    /// The camera row belongs to the island chrome. No song artwork, titles,
    /// or accessories can occupy it; the player begins immediately below it.
    private var bandHeight: CGFloat { band.besideCamera ? band.height : 0 }

    private var artworkSize: CGFloat {
        // Preserve the island's width, but let the cover use approximately
        // a quarter of it, like the reference layout. Never enter the camera band.
        min(NotchLayout.musicHeroArtworkSize,
            max(NotchLayout.musicArtworkSize, size.width * 0.23))
    }

    var body: some View {
        // Both presets grow for extra content while retaining the player.
        let split = NotchLayout.musicSplit(
            height: size.height, extras: extrasHeight,
            resting: NotchLayout.musicPlayerHeight(band: bandHeight, playing: service.playback != nil),
            keepsPlayer: !preview, extraOpen: openExtra != nil)
        // With the player gone the list starts below the camera's row, which
        // keeps its toggles; without that row they come back in one of their
        // own above the list, to close it.
        let reserve = split.showsPlayer ? 0
            : band.besideCamera ? bandHeight + NotchLayout.spacing : 28 + NotchLayout.rowSpacing
        VStack(spacing: NotchLayout.rowSpacing) {
            if split.showsPlayer {
                if let playback = service.playback {
                    player(playback)
                } else if !service.awaitingPlayback {
                    idle
                } else {
                    Color.clear.frame(height: split.player)
                }
            } else if band.besideCamera {
                Color.clear.frame(height: reserve - NotchLayout.rowSpacing)
            } else {
                inlineHeader(service.playback)
            }
            if let openExtra, let playback = service.playback {
                Group {
                    switch openExtra {
                    case .lyrics: NotchLyricsView(playback: playback)
                    case .queue: NotchQueueView(playback: playback)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(height: max(0, min(split.extra, size.height - reserve)), alignment: .top)
                .clipped()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // The header contains only the existing back button (from NotchView),
        // the playing-app chooser, and the inherited pin. Music content and
        // animated color never enter the camera's reserved row.
        // Keep the playback app on the camera's trailing side. The temporary
        // volume/brightness feedback is positioned separately by NotchView.
        .notchBand(trailing: {
            if band.besideCamera, let playback = service.playback { sourceMenu(playback) }
        })
        .onAppear {
            // A preview in Settings leaves the island's size and extras alone.
            guard !preview else { return }
            syncExtras()
            service.refreshAutomation()
            shuffle.refresh(for: service.playback)
            repeating.refresh(for: service.playback)
        }
        .onChange(of: extra) { syncExtras() }
        .onChange(of: service.playback.map(NotchMusicIdentity.init)) {
            syncExtras()
            if !preview {
                shuffle.refresh(for: service.playback)
                repeating.refresh(for: service.playback)
            }
        }
        // Shuffle and the playback buttons share one consent, so a grant
        // through the playback buttons also shows on shuffle.
        .onChange(of: service.automationAvailability?.access) { old, new in
            if !preview, old != nil, new != nil {
                shuffle.refresh(for: service.playback)
                repeating.refresh(for: service.playback)
            }
        }
        .onChange(of: features.revision) { syncExtras() }
        .onChange(of: lyricsEnabled) { syncExtras() }
        .onChange(of: queueEnabled) { syncExtras() }
        .onDisappear {
            guard !preview else { return }
            NotchService.shared.setMusicDetailsVisible(false)
            NotchService.shared.setPageLayer(.music, close: nil)
            NotchLyricsService.shared.hide()
            service.setQueueVisible(false)
            shuffle.stop()
            repeating.stop()
        }
    }

    private func syncExtras() {
        guard !preview else { return }
        NotchService.shared.setMusicDetailsVisible(openExtra != nil)
        // Escape closes lyrics or the queue before the island.
        NotchService.shared.setPageLayer(.music, close: openExtra == nil ? nil : { extra = nil })
        NotchLyricsService.shared.update(playback: service.playback, visible: extra == .lyrics)
        service.setQueueVisible(extra == .queue)
    }

    /// No notch / floating windows have no inherited camera-side header.
    /// Keep the same actions in a small local top row in that case.
    private func inlineHeader(_ playback: NotchPlayback?) -> some View {
        HStack(spacing: 6) {
            NotchBandBackButton(title: SettingsFollowupStrings.text(.allTools, l10n.language), showsTitle: true) {
                NotchService.shared.select(.hub)
            }
            Spacer(minLength: 0)
            if let playback { sourceMenu(playback) }
            NotchIconButton(symbol: NotchService.shared.pinned ? "pin.fill" : "pin",
                            title: NotchService.shared.pinned ? FeatureStrings.notch(l10n.language).unpin : FeatureStrings.notch(l10n.language).pin,
                            selected: NotchService.shared.pinned,
                            hasBackdrop: false) {
                NotchService.shared.pinned.toggle()
                LatticeHubService.shared.isPinned = NotchService.shared.pinned
            }
        }
        .frame(height: NotchLayout.musicInlineHeaderHeight)
    }

    private var idle: some View {
        let player = preview ? nil : NotchPreferredPlayer.current()
        let opens = player != nil
        let openTitle = player.map { NotchPreferredPlayer.openTitle(for: $0) } ?? ""
        return VStack(spacing: 0) {
            if band.besideCamera {
                Color.clear.frame(height: bandHeight)
            } else {
                inlineHeader(nil)
            }
            Color.clear.frame(height: NotchLayout.musicHeroTopGap)
            HStack(alignment: .top, spacing: 12) {
                Button { NotchPreferredPlayer.open() } label: {
                    NotchArtwork(image: nil, size: artworkSize)
                }
                .buttonStyle(NotchButtonStyle(cornerRadius: artworkSize * 0.19))
                .disabled(!opens)
                .help(openTitle)
                .accessibilityLabel(opens ? openTitle : text.mediaNothingPlaying)

                VStack(alignment: .leading, spacing: 4) {
                    if !service.sources.isEmpty || !service.sourceIsAutomatic {
                        sourcePicker(nil)
                    } else {
                        Text(text.mediaNothingPlaying)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                    if opens {
                        Text(openTitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
            }
            .frame(height: NotchLayout.musicHeroArtworkSize, alignment: .top)
            Color.clear.frame(height: NotchLayout.musicHeroTransportGap)
            Group {
                if opens {
                    transportRow(leading: { EmptyView() }) { slot in
                        NotchMusicIdleTransport(openTitle: openTitle, slot: slot)
                    }
                } else {
                    Text(FeatureStrings.notch(l10n.language).musicHint)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: NotchLayout.musicTransportHeight)
        }
        .accessibilityElement(children: .contain)
    }

    /// Lyrics and the queue are toggles, named by their glyphs as a player's own are.
    @ViewBuilder private var extraButtons: some View {
        if showsLyrics {
            extraButton(.lyrics, title: FeatureStrings.notchMusicExtras(l10n.language).lyrics, symbol: "quote.bubble")
        }
        if showsQueue {
            extraButton(.queue, title: FeatureStrings.notchMusicExtras(l10n.language).queue, symbol: "list.bullet")
        }
    }

    private func extraButton(_ target: MusicExtra, title: String, symbol: String) -> some View {
        NotchIconButton(symbol: symbol, title: title, selected: extra == target) {
            extra = extra == target ? nil : target
        }
    }

    /// The player's own shuffle switch. A player not yet allowed to be
    /// controlled asks for that first, as the playback buttons do.
    private var shuffleButton: some View {
        let strings = FeatureStrings.notchMusicExtras(l10n.language)
        let consent = shuffle.availability?.access == .consent
        return NotchMusicSideButton(symbol: "shuffle", title: strings.shuffle, hint: consent ? strings.allowPlayback : nil,
                                    active: shuffle.enabled == true, tint: accent) { shuffle.toggle() }
            .disabled(shuffle.requestingAccess || !shuffle.allowed)
    }

    /// The player's repeat state occupies the bottom-right transport slot.
    /// It changes the actual player's state, not a local preference.
    private var repeatButton: some View {
        let mode = repeating.mode ?? .off
        let hint = repeating.availability?.access == .consent
            ? FeatureStrings.notchMusicExtras(l10n.language).allowPlayback : nil
        return NotchMusicSideButton(symbol: mode.symbol, title: mode.title,
                                    hint: hint, active: mode != .off, tint: accent) {
            repeating.cycle()
        }
        .disabled(repeating.pending || repeating.requestingAccess)
    }

    /// Five stable places across the island. A missing shuffle or repeat
    /// button never displaces the three central transport controls.
    private func transportRow<Leading: View, Middle: View>(
        @ViewBuilder leading: () -> Leading, @ViewBuilder middle: (CGFloat) -> Middle) -> some View {
        let slot = size.width / 5
        // An empty place keeps its width: a missing button must not pull the
        // transport off the island's middle.
        return HStack(spacing: 0) {
            Color.clear.frame(width: slot).overlay { leading() }
            middle(slot).frame(width: slot * 3)
            Color.clear.frame(width: slot).overlay {
                if !preview && repeating.isOffered { repeatButton }
            }
        }
        .frame(height: NotchLayout.musicTransportHeight)
    }

    /// Artwork and all song content sit entirely below the camera row.
    /// The cover is larger than the old 56pt art, but we keep original widths
    /// and all the existing playback symbols and actions.
    private func redesignedHead(_ playback: NotchPlayback) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button { RadialNowPlayingApplication.open(playback.track) } label: {
                NotchMusicCrossfadingArtwork(image: service.artwork, size: artworkSize, source: playback.track)
                    .scaleEffect(playback.isPlaying || reduceMotion ? 1 : 0.96)
                    .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: playback.isPlaying)
            }
            .buttonStyle(NotchButtonStyle(cornerRadius: artworkSize * 0.19))
            .help(text.mediaNowPlaying)
            .accessibilityLabel(text.mediaNowPlaying)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(playback.track.title ?? text.mediaNowPlaying)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(playback.track.title ?? text.mediaNowPlaying)
                    Text(service.commandFailed
                         ? FeatureStrings.notchMusicExtras(l10n.language).playbackFailed
                         : playback.track.artist ?? playback.track.album ?? text.mediaNowPlaying)
                        .font(.system(size: 14))
                        .foregroundStyle(service.commandFailed ? .orange : .secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.top, 9)

                Spacer(minLength: 0)

                // One compact accessory group, in the reference order:
                // Lyrics / Queue / output device / mute and volume.
                // Unlike a trailing Spacer before Volume, this group stays
                // together directly under the artist and never jumps right.
                HStack(spacing: 5) {
                    extraButtons
                    if AppFeature.mixer.isAvailable {
                        NotchMusicOutputButton(compact: true)
                        NotchMusicVolumeControls()
                            .frame(width: max(72, min(122, size.width * 0.29)))
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: 28)
                .padding(.bottom, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: NotchLayout.musicHeroArtworkSize)
        }
        .frame(height: NotchLayout.musicHeroArtworkSize, alignment: .top)
    }

    /// The header's original back/player/pin actions are separate from the
    /// content, so the cover and glow cannot overlap the physical camera.
    private func player(_ playback: NotchPlayback) -> some View {
        VStack(spacing: 0) {
            if band.besideCamera {
                Color.clear.frame(height: bandHeight)
            } else {
                inlineHeader(playback)
            }
            Color.clear.frame(height: NotchLayout.musicHeroTopGap)
            redesignedHead(playback)
            Color.clear.frame(height: NotchLayout.musicHeroTimelineGap)
            NotchMusicTimeline(playback: playback, service: service,
                               tint: .white, timesBeside: false)
            Color.clear.frame(height: NotchLayout.musicHeroTransportGap)
            transportRow {
                if !preview && shuffle.isOffered { shuffleButton }
            } middle: { slot in
                NotchMusicTransport(playback: playback, slot: slot)
            }
        }

        // The expanded Music glow lives in NotchWindowBackground, beneath
        // the controls and all the way to the island's animated silhouette.
        // Keeping it out of this inset player removes the dark interior rim.
    }

    /// The player the buttons drive, as its icon, opening the same choice.
    private func sourceMenu(_ playback: NotchPlayback) -> some View {
        let extras = FeatureStrings.notchMusicExtras(l10n.language)
        let current = service.sources.first { $0.pid == playback.track.appPID }
        let app = playback.track.appPID.map { NotchPlayerApps.app(pid: $0, bundle: playback.track.appBundleIdentifier) }
        let name = current?.displayName ?? app?.name ?? playback.track.appBundleIdentifier ?? extras.playbackSource
        let icon = app?.icon
        var items = [NotchMenuItem(title: extras.automaticSource, checked: service.sourceIsAutomatic) { service.selectSource(nil) },
                     .separator]
        items += service.sources.map { source in
            let title = source.displayName ?? NotchPlayerApps.app(pid: source.pid, bundle: source.bundleIdentifier).name
                ?? source.bundleIdentifier
            // The chosen row, even while the automatic player fills its gap.
            return NotchMenuItem(title: title, checked: source.pid == service.selectedSourcePID) { service.selectSource(source.selection) }
        }
        return NotchMenuButton(title: extras.playbackSource, items: items, cornerRadius: 6) {
            Group {
                if let icon {
                    Image(nsImage: icon).resizable().interpolation(.high)
                } else {
                    Image(systemName: "app").font(.system(size: 13)).foregroundStyle(.secondary)
                }
            }
            .frame(width: 18, height: 18)
            .padding(3)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .help("\(extras.playbackSource): \(name)")
        .accessibilityValue([service.sourceIsAutomatic ? extras.automaticSource : nil, name].compactMap { $0 }.joined(separator: ", "))
    }

    private func sourcePicker(_ playback: NotchPlayback?) -> some View {
        let extras = FeatureStrings.notchMusicExtras(l10n.language)
        let pid = playback?.track.appPID
        let name = service.sources.first(where: { $0.pid == pid })?.displayName
            ?? pid.flatMap { NSRunningApplication(processIdentifier: $0)?.localizedName }
            ?? playback?.track.appBundleIdentifier ?? extras.playbackSource
        return Menu {
            Button { service.selectSource(nil) } label: {
                if service.sourceIsAutomatic { Label(extras.automaticSource, systemImage: "checkmark") }
                else { Text(extras.automaticSource) }
            }
            Divider()
            ForEach(service.sources, id: \.pid) { source in
                let title = source.displayName ?? NSRunningApplication(processIdentifier: source.pid)?.localizedName ?? source.bundleIdentifier
                Button { service.selectSource(source.selection) } label: {
                    // The chosen row, even while the automatic player fills its gap.
                    if source.pid == service.selectedSourcePID {
                        Label(title, systemImage: "checkmark")
                    } else { Text(title) }
                }
            }
        } label: {
            Text(name).lineLimit(1).truncationMode(.tail)
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: 110)
        .fixedSize()
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .accessibilityLabel(extras.playbackSource)
        .accessibilityValue([service.sourceIsAutomatic ? extras.automaticSource : nil,
                             playback == nil ? nil : name].compactMap { $0 }.joined(separator: ", "))
        .help(extras.playbackSource)
    }
}

/// Keep the outgoing cover until the incoming cover has faded in. This view
/// keys transitions to the decoded image object, not the once-a-second
/// playback reading. Rapid track changes cancel the previous cleanup task.
private struct NotchMusicCrossfadingArtwork: View {
    let image: NSImage?
    let size: CGFloat
    let source: RadialNowPlayingSnapshot?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed: NSImage?
    @State private var outgoing: NSImage?
    @State private var blend = 1.0

    init(image: NSImage?, size: CGFloat, source: RadialNowPlayingSnapshot?) {
        self.image = image
        self.size = size
        self.source = source
        _displayed = State(initialValue: image)
    }

    var body: some View {
        ZStack {
            if let outgoing {
                NotchArtwork(image: outgoing, size: size, source: source)
                    .opacity(1 - blend)
            }
            NotchArtwork(image: displayed, size: size, source: source)
                .opacity(outgoing == nil ? 1 : blend)
        }
        .frame(width: size, height: size)
        .onChange(of: image.map(ObjectIdentifier.init)) { _, _ in
            guard displayed !== image else { return }
            if reduceMotion {
                displayed = image
                outgoing = nil
                blend = 1
                return
            }
            outgoing = displayed
            displayed = image
            blend = 0
            withAnimation(.easeInOut(duration: 0.62)) { blend = 1 }
        }
        .task(id: image.map(ObjectIdentifier.init)) {
            // SwiftUI cancels this cleanup if another cover arrives first.
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            outgoing = nil
            blend = 1
        }
    }
}

/// Shuffle and Repeat keep their selected-state tint without a permanent
/// plate. The shared button style supplies exactly one hover highlight;
/// layering another selected circle under it produced a double-ring effect.
private struct NotchMusicSideButton: View {
    let symbol: String
    let title: String
    /// What a press does first when that is not switching, as asking for consent.
    var hint: String?
    let active: Bool
    let tint: Color
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let height: CGFloat = 44
    private let plate: CGFloat = 32

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(active ? tint : .white.opacity(isEnabled ? 0.55 : 0.3))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: plate, height: plate)
                .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: active)
                .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: symbol)
                .frame(width: height, height: height)
                .contentShape(Circle())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: height / 2))
        .help(hint ?? title)
        .accessibilityLabel(title)
        .accessibilityHint(hint ?? "")
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/// A player's name and icon, looked up once per running process: the player
/// redraws every second while a song plays. A process number another app
/// took since is looked up again.
private enum NotchPlayerApps {
    private static var known: [Int32: (bundle: String?, name: String?, icon: NSImage?)] = [:]

    static func app(pid: Int32, bundle: String?) -> (name: String?, icon: NSImage?) {
        if let entry = known[pid], bundle == nil || entry.bundle == bundle { return (entry.name, entry.icon) }
        let running = NSRunningApplication(processIdentifier: pid)
        if known.count >= 16 { known.removeAll() }
        known[pid] = (running?.bundleIdentifier ?? bundle, running?.localizedName, running?.icon)
        return (running?.localizedName, running?.icon)
    }
}

/// Mute and native system-output level controls, in one compact group after
/// the output-device picker. Reuse the existing mixer automation and slider.
private struct NotchMusicVolumeControls: View {
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var l10n = L10n.shared

    private var level: Double? {
        mixer.systemOutputVolume.map { mixer.systemOutputMuted == true ? 0 : $0 }
    }

    private func adjust(volume: Double? = nil, muted: Bool? = nil) {
        NotchService.shared.noteOwnLevelAdjustment(.volume)
        mixer.requestOutputAdjustment(volume: volume, muted: muted)
    }

    var body: some View {
        HStack(spacing: 4) {
            Button {
                if let muted = mixer.systemOutputMuted { adjust(muted: !muted) }
            } label: {
                Image(systemName: mixer.systemOutputMuted == true
                      ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 18, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(mixer.systemOutputMuted == nil)
            .accessibilityLabel(mixer.systemOutputMuted == true
                                ? l10n.s.actionUnmute : l10n.s.actionMute)

            if let level {
                NotchLevelSlider(
                    value: Binding(get: { level }, set: { adjust(volume: $0) }),
                    label: FeatureStrings.notch(l10n.language).volume,
                    trackThickness: 6, easesChanges: true
                )
                .frame(height: 24)
            }

        }
        .frame(height: 28)
    }

}

private struct NotchMusicOutputButton: View {
    var compact = false
    @ObservedObject private var notch = NotchService.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var l10n = L10n.shared

    private var deviceName: String {
        mixer.outputDevices.first(where: { $0.uid == mixer.currentOutputDeviceUID })?.name ?? l10n.s.mixerSystemOutputTitle
    }

    /// The kind of output playing now: this Mac, headphones or a speaker.
    private var symbol: String {
        guard let device = mixer.outputDevices.first(where: { $0.uid == mixer.currentOutputDeviceUID }) else { return "airplay.audio" }
        if device.isHeadphones { return NotchAccessorySupport.symbol(for: .audio, name: device.name) }
        switch device.priorityTier {
        case .builtIn: return PowerSampler.hasInternalBattery ? "laptopcomputer" : "desktopcomputer"
        case .hardware: return "hifispeaker"
        case .virtual: return "airplay.audio"
        }
    }

    var body: some View {
        NotchMenuButton(title: l10n.s.mixerSystemOutputTitle, items: items,
                        cornerRadius: compact ? 9 : 22) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 14 : 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: compact ? 28 : 44, height: compact ? 28 : 44)
                .contentShape(Circle())
        }
        .help(mixer.outputSwitchError ?? deviceName)
        .accessibilityValue(deviceName)
    }

    private var items: [NotchMenuItem] {
        mixer.outputDevices.filter(\.canBeDefaultOutput).map { device in
            NotchMenuItem(title: device.name, checked: device.uid == mixer.currentOutputDeviceUID) {
                _ = mixer.setUniversalOutputDeviceUID(device.uid)
            }
        }
    }
}

/// The transport as it looks with nothing playing. Every button opens the
/// music app, since there is no player to send a command to yet.
struct NotchMusicIdleTransport: View {
    var compact = false
    let openTitle: String
    /// The player's row gives each button an equal place across the island.
    var slot: CGFloat? = nil
    @ObservedObject private var l10n = L10n.shared
    private var text: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }
    private var height: CGFloat { compact ? 36 : 44 }

    var body: some View {
        HStack(spacing: slot == nil ? (compact ? 12 : 18) : 0) {
            button("backward.fill", title: text.mediaPrevious, size: compact ? 16 : 19).frame(width: slot)
            button("play.fill", title: text.mediaPlayPause, size: compact ? 22 : slot == nil ? 26 : 28).frame(width: slot)
            button("forward.fill", title: text.mediaNext, size: compact ? 16 : 19).frame(width: slot)
        }
        .frame(height: height)
    }

    private func button(_ symbol: String, title: String, size: CGFloat) -> some View {
        Button { NotchPreferredPlayer.open() } label: {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: height, height: height)
                .contentShape(Circle())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: height / 2))
        .accessibilityLabel(title)
        // VoiceOver says what the press does: it opens the app, not a skip.
        .accessibilityHint(openTitle)
        .help(openTitle)
    }
}

struct NotchMusicTimeline: View {
    let playback: NotchPlayback
    @ObservedObject var service: NotchMusicService
    var tint: Color = .white
    /// The island's player sets the times beside the bar, as a phone's
    /// island does, which leaves its short row room for the artist.
    var timesBeside = false
    @ObservedObject private var l10n = L10n.shared
    @State private var scrubPosition: Double?
    @State private var scrubTrack: RadialNowPlayingSnapshot?
    @State private var scrubContext: NotchPlaybackContext?
    @State private var pendingSeek: UUID?

    var body: some View {
        if playback.duration > 0 {
            TimelineView(.animation(minimumInterval: 1, paused: !playback.isPlaying)) { context in
                let position = scrubPosition ?? playback.position(at: context.date)
                Group {
                    if timesBeside {
                        HStack(spacing: 8) {
                            // The song's longest reading holds each side's
                            // width, so the bar keeps its length as it plays.
                            ZStack(alignment: .leading) {
                                Text(timestamp(playback.duration)).hidden()
                                Text(timestamp(position))
                            }
                            bar(position)
                            ZStack(alignment: .trailing) {
                                Text("−" + timestamp(playback.duration)).hidden()
                                Text("−" + timestamp(playback.duration - position))
                            }
                        }
                    } else {
                        VStack(spacing: 3) {
                            bar(position)
                            HStack {
                                Text(timestamp(position))
                                Spacer()
                                Text("−" + timestamp(playback.duration - position))
                            }
                        }
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
            .frame(height: timesBeside ? NotchLayout.musicTimelineHeight : NotchLayout.musicHeroTimelineHeight)
            .onChange(of: playback.track) { clearScrub() }
            .onChange(of: playback.commandContext) { clearScrub() }
            .onChange(of: playback.sampledAt) {
                if pendingSeek != nil, let scrubPosition,
                   abs(playback.position(at: Date()) - scrubPosition) <= 2 { clearScrub() }
            }
            .task(id: pendingSeek) {
                guard pendingSeek != nil else { return }
                // Keep the released thumb still while the player responds,
                // but always return to observed playback if it ignores seeking.
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                clearScrub()
            }
        }
    }

    @ViewBuilder private func bar(_ position: TimeInterval) -> some View {
        if service.canSeek {
            NotchLevelSlider(
                value: Binding(get: { position }, set: {
                    if scrubTrack == nil {
                        scrubTrack = playback.track
                        scrubContext = playback.commandContext
                    }
                    scrubPosition = $0
                }),
                label: FeatureStrings.notch(l10n.language).playbackPosition,
                range: 0...playback.duration,
                tint: tint,
                valueLabel: timestamp(position),
                onEditingChanged: { editing in
                    if editing {
                        pendingSeek = nil
                    } else if let scrubPosition, let scrubTrack {
                        service.seek(to: scrubPosition, in: scrubTrack, context: scrubContext)
                        pendingSeek = UUID()
                    }
                })
                .frame(height: 10)
                .disabled(service.commandPending)
        } else {
            NotchMeter(value: position / playback.duration, height: 6, tint: tint)
        }
    }

    private func clearScrub() {
        pendingSeek = nil
        scrubPosition = nil
        scrubTrack = nil
        scrubContext = nil
    }

    private func timestamp(_ interval: TimeInterval) -> String {
        let seconds = Int(min(604_800, max(0, interval)))
        return seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// The home surface shares playback actions without opening lyrics or queue
/// readers: the player's cover, the title and artist beside it, and the
/// transport at the end of their line, or under the title where a level card
/// shares the row.
struct NotchMusicControlsView: View {
    @ObservedObject var notch: NotchService
    var height: CGFloat = NotchLayout.cardHeight
    @ObservedObject private var music = NotchMusicService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.notchSettingsPreview) private var preview
    private var text: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }
    private var isIdle: Bool {
        !preview && music.playback == nil && !music.awaitingPlayback
    }

    var body: some View {
        let player = isIdle ? NotchPreferredPlayer.current() : nil
        let idleOpens = player != nil
        let openTitle = player.map { NotchPreferredPlayer.openTitle(for: $0) } ?? ""
        HStack(spacing: 12) {
            // With nothing playing, the cover opens the music app instead.
            Button {
                if isIdle, NotchPreferredPlayer.open() { return }
                notch.select(.music)
            } label: {
                NotchArtwork(image: music.artwork, size: max(40, height - 24), source: music.playback?.track)
            }
            .buttonStyle(NotchButtonStyle(cornerRadius: 16))
            .accessibilityLabel(idleOpens ? openTitle : text.mediaNowPlaying)
            .help(idleOpens ? openTitle : text.mediaNowPlaying)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    // Measured at its narrowest, so a long title truncates
                    // before the transport moves under it.
                    titles(artist: true)
                        .frame(minWidth: 80, idealWidth: 80, maxWidth: .infinity, alignment: .leading)
                    transport(idleOpens: idleOpens, openTitle: openTitle).fixedSize()
                }
                VStack(alignment: .leading, spacing: 4) {
                    // A shortened card keeps the title and the transport.
                    titles(artist: height >= 84)
                    transport(idleOpens: idleOpens, openTitle: openTitle).frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background {
            NotchMusicArtworkGlow(palette: music.artworkGlowPalette,
                                  isPlaying: music.playback?.isPlaying == true,
                                  intensity: 0.45)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .modifier(NotchControlSurface(cornerRadius: 18))
        .onAppear { if !preview { music.refreshAutomation() } }
    }

    private func titles(artist: Bool) -> some View {
        Button { notch.select(.music) } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(music.playback?.track.title ?? (music.awaitingPlayback ? text.mediaNowPlaying : text.mediaNothingPlaying))
                    .font(.system(size: 13, weight: .semibold)).lineLimit(1)
                if artist {
                    Text(music.commandFailed ? FeatureStrings.notchMusicExtras(l10n.language).playbackFailed
                         : music.playback?.track.artist ?? music.playback?.track.album
                            ?? (music.awaitingPlayback ? "" : FeatureStrings.notch(l10n.language).musicHint))
                        .font(.system(size: 11))
                        .foregroundStyle(music.commandFailed ? .orange : .secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func transport(idleOpens: Bool, openTitle: String) -> some View {
        if let playback = music.playback {
            NotchMusicTransport(playback: playback, compact: true)
        } else if idleOpens {
            NotchMusicIdleTransport(compact: true, openTitle: openTitle)
        }
    }
}

/// A softly moving cover-colored wash. Only this child observes the existing
/// seven-band audio service, keeping 30 Hz audio updates out of the page layout.
/// The Show Audio Visualizer setting gates both this compact glow and the
/// expanded window glow; no separate audio permission is requested here.
/// A translucent, album-driven light field inside the existing Liquid Glass
/// shape. The window still owns its border and clipping; the glow adds light
/// within the content without replacing the native material.
private struct NotchMusicArtworkGlow: View {
    let palette: [NotchArtworkTint]
    let isPlaying: Bool
    var intensity: Double = 1
    @AppStorage(DefaultsKey.notchLiveEqualizer) private var visualizerEnabled = false
    @ObservedObject private var audio = NotchAudioLevelService.shared
    @State private var envelope = NotchMusicGlowEnvelope()
    @State private var audioPulse = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.notchSettingsPreview) private var preview

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0,
                                paused: !visualizerEnabled || !isPlaying || reduceMotion || preview || palette.isEmpty)) { tick in
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                guard size.width > 0, size.height > 0, !palette.isEmpty else { return }
                let pulse = isPlaying && !reduceMotion && !preview ? CGFloat(audioPulse) : 0
                let t = isPlaying && !reduceMotion && !preview
                    ? tick.date.timeIntervalSinceReferenceDate : 0

                // A low-opacity color veil fills the entire lower content area.
                // Without it, separate radial blobs look like isolated stains.
                let main = palette[0].color
                let veil = Gradient(stops: [
                    .init(color: main.opacity(0), location: 0),
                    .init(color: main.opacity(0.035 * intensity), location: 0.30),
                    .init(color: main.opacity(0.075 * intensity), location: 0.68),
                    .init(color: main.opacity(0.105 * intensity), location: 1)
                ])
                context.fill(Path(CGRect(origin: .zero, size: size)),
                             with: .linearGradient(veil,
                                   startPoint: CGPoint(x: 0, y: 0),
                                   endPoint: CGPoint(x: 0, y: size.height)))

                // Album colours wander independently and blend, while bass
                // still supplies the short pulse on top of that slow movement.
                // Reuse the full-window flow field without any new refresh loop.
                let positions: [CGFloat] = [0.18, 0.53, 0.82]
                let extent = max(size.width, size.height)
                for (index, tint) in palette.prefix(3).enumerated() {
                    let offset = NotchMusicColorFlow.offset(index: index, time: t)
                    let cx = size.width * (positions[index] + offset.x * 0.16)
                    let cy = size.height * (0.79 + offset.y * 0.12)
                    let radius = extent * (0.66 * NotchMusicColorFlow.radius(index: index, time: t)
                                           + 0.012 * pulse)
                    let strength = (0.15 * NotchMusicColorFlow.brightness(index: index, time: t)
                                    + 0.040 * Double(pulse)) * intensity
                    let center = CGPoint(x: cx, y: cy)
                    let area = CGRect(x: cx - radius, y: cy - radius,
                                      width: 2 * radius, height: 2 * radius)
                    let gradient = Gradient(stops: [
                        .init(color: tint.color.opacity(strength), location: 0),
                        .init(color: tint.color.opacity(strength * 0.55), location: 0.40),
                        .init(color: tint.color.opacity(0), location: 1)
                    ])
                    context.fill(Path(ellipseIn: area), with: .radialGradient(
                        gradient, center: center, startRadius: 0, endRadius: radius))
                }
            }
        }
        // Screen blend lets sampled colors illuminate the dark glass instead
        // of forming opaque muddy patches. The gradient itself is clipped by
        // the existing island surface, so its outline and corners stay native.
        .blendMode(.screen)
        .mask {
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.12), location: 0.18),
                .init(color: .white.opacity(0.55), location: 0.42),
                .init(color: .white.opacity(0.88), location: 0.66),
                .init(color: .white, location: 1)
            ], startPoint: .top, endPoint: .bottom)
        }
        .opacity(visualizerEnabled ? 1 : 0)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28),
                   value: visualizerEnabled)
        .onReceive(audio.$levels) { levels in
            guard visualizerEnabled else { return }
            audioPulse = envelope.next(levels, at: ProcessInfo.processInfo.systemUptime)
        }
        .onChange(of: visualizerEnabled) { _, isEnabled in
            if !isEnabled {
                envelope = NotchMusicGlowEnvelope()
                audioPulse = 0
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
