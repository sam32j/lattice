// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Feedback is local to a visible control. No recurring work is needed.
/// The pointer lifts a control slightly and a press settles it back, which is
/// what makes the panel feel physical rather than painted on.
struct NotchButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 10
    var lifts = true
    /// A light wash under the pointer.
    var highlights = true
    @State private var hovered = false
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let active = enabled && hovered
        configuration.label
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(active && highlights ? 0.09 : 0))
                    .allowsHitTesting(false)
            }
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(reduceMotion || !lifts ? 1
                         : configuration.isPressed ? 0.965 : (active ? 1.022 : 1))
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.7),
                       value: configuration.isPressed)
            .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.75), value: hovered)
            .onHover { hovered = $0 }
    }
}

extension NotchArtworkTint {
    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
}

/// The bars with the live levels attached. Only this small view observes the
/// audio service, so its thirty updates a second never re-render the island.
struct NotchLiveEqualizerBars: View {
    var isPlaying = true
    var bars = 4
    var barWidth: CGFloat = 2.5
    var height: CGFloat = 14
    var tint: Color = .white
    @ObservedObject private var audio = NotchAudioLevelService.shared

    var body: some View {
        NotchEqualizerBars(isPlaying: isPlaying, bars: bars, barWidth: barWidth, height: height, tint: tint,
                           live: audio.levels)
    }
}

/// A level readout in the same language as the notch's sliders, instead of the
/// thin system bar, so every meter in the panel matches.
struct NotchMeter: View {
    let value: Double
    var height: CGFloat = 5
    var tint: Color = .white

    var body: some View {
        let fraction = value.isFinite ? min(1, max(0, value)) : 0
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(.white.opacity(0.14))
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.9))
                    .frame(width: max(fraction > 0 ? height : 0, proxy.size.width * fraction))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// A clock's digits roll into the next reading, downward while it counts
/// down and upward while it counts up; Reduce Motion changes them in place.
struct NotchRollingDigits: ViewModifier {
    let value: String
    let countsDown: Bool
    /// Off in the closed island, where only the part above the seconds rolls.
    var everySecond = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .contentTransition(.numericText(countsDown: countsDown))
            .animation(reduceMotion ? nil : .smooth(duration: 0.3),
                       value: NotchTimerSupport.rollingValue(value, everySecond: everySecond))
    }
}

/// Draws a strip from what its activity reported while it was on the island.
/// An activity that ends says so before the island swaps its strip out, and
/// the strip on its way out drew the empty reading for those frames and
/// through the fade into what comes next.
struct NotchStripHold<Value: Equatable, Content: View>: View {
    private let value: Value
    private let shows: Bool
    private let content: (Value) -> Content
    @State private var held: Value

    /// `shows` is whether the activity is still on the island.
    init(_ value: Value, shows: Bool, @ViewBuilder content: @escaping (Value) -> Content) {
        self.value = value
        self.shows = shows
        self.content = content
        _held = State(initialValue: value)
    }

    var body: some View {
        content(shows ? value : held)
            .onChange(of: value) { _, value in
                if shows { held = value }
            }
    }
}

/// Swaps a strip and the companion at rest through black: the one leaving is
/// gone halfway through the island's crossfade and the one arriving comes in
/// over the rest of it, so the companion never shows half faded over the
/// strip's text in the same place.
struct NotchFadeThrough: ViewModifier, Animatable {
    var progress: Double
    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.opacity(max(0, progress * 2 - 1))
    }
}

extension AnyTransition {
    static var notchFadeThrough: AnyTransition {
        .modifier(active: NotchFadeThrough(progress: 0), identity: NotchFadeThrough(progress: 1))
    }
}

struct NotchIconButton: View {
    let symbol: String
    let title: String
    var selected = false
    var hasBackdrop = true
    var tint: Color? = nil
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(tint ?? (selected ? Color.white : Color.white.opacity(0.55)))
                .contentTransition(.symbolEffect(.replace))
                .animation(reduceMotion ? nil : .smooth(duration: 0.24), value: symbol)
                .frame(width: 28, height: 28)
                .background(.white.opacity(selected && hasBackdrop ? 0.12 : 0),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 9))
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The island's way to its sections, in its top row or on a page that
/// lays out its own top, while nothing floating beside the island offers it.
struct NotchSectionsButton: View {
    let action: () -> Void
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        NotchIconButton(symbol: "house", title: SettingsFollowupStrings.text(.allTools, l10n.language), action: action)
    }
}

/// A short island puts the glyph beside its message; taller ones stack them.
/// Actions, when a page has a next step to offer, follow the message.
struct NotchEmptyView<Actions: View>: View {
    let symbol: String
    let message: String
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        ViewThatFits(in: .vertical) {
            VStack(spacing: 12) {
                glyph
                label.multilineTextAlignment(.center).frame(maxWidth: 250)
                actions()
            }
            HStack(spacing: 14) {
                glyph
                VStack(alignment: .leading, spacing: 10) {
                    label.frame(maxWidth: 260, alignment: .leading)
                    actions()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var glyph: some View {
        Image(systemName: symbol)
            .font(.system(size: 26, weight: .light))
            .foregroundStyle(.white.opacity(0.65))
            .frame(width: 56, height: 56)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityHidden(true)
    }

    private var label: some View {
        Text(message)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension NotchEmptyView where Actions == EmptyView {
    init(symbol: String, message: String) {
        self.init(symbol: symbol, message: message) { EmptyView() }
    }
}

/// An empty page's next step, as a word on a pill. The step the page leads
/// to is filled, and any other stays plain beside it.
struct NotchPillButton: View {
    let title: String
    var prominent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: prominent ? .semibold : .medium))
                .foregroundStyle(.white.opacity(prominent ? 1 : 0.7))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(.white.opacity(prominent ? 0.14 : 0), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 14))
    }
}

struct NotchArtwork: View {
    let image: NSImage?
    let size: CGFloat
    /// A player that sends no cover, as Firefox and Zen do, shows its own
    /// icon in its place, so the song still says where it plays.
    var source: RadialNowPlayingSnapshot? = nil

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else if let icon = source.flatMap(RadialNowPlayingApplication.icon(for:)) {
                Color.black.overlay {
                    Image(nsImage: icon).resizable().interpolation(.high).scaledToFit().padding(size * 0.14)
                }
            } else {
                Color.black.overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.3, weight: .light))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.19, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }
}

private struct NotchGlassSurfaceKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var notchGlassSurface: Bool {
        get { self[NotchGlassSurfaceKey.self] }
        set { self[NotchGlassSurfaceKey.self] = newValue }
    }

    /// A page drawn in Settings to preview the island. It shows what the
    /// island shows but must leave the island's state and the keyboard alone.
    var notchSettingsPreview: Bool {
        get { self[NotchSettingsPreviewKey.self] }
        set { self[NotchSettingsPreviewKey.self] = newValue }
    }
}

private struct NotchSettingsPreviewKey: EnvironmentKey {
    static let defaultValue = false
}

private struct NotchBandEnvironmentKey: EnvironmentKey {
    static let defaultValue = NotchBand()
}

extension EnvironmentValues {
    /// The open island's top row, where the page's own controls go: beside
    /// the camera, or across the top of an island without one.
    var notchBand: NotchBand {
        get { self[NotchBandEnvironmentKey.self] }
        set { self[NotchBandEnvironmentKey.self] = newValue }
    }
}

/// Controls a page hands the island's top row. The island names no page, so
/// the row holds what the page needs at hand, and the island adds its own
/// around them: the way back on its leading side, an update or the pin on
/// its trailing side.
struct NotchBandItems {
    var leading: AnyView?
    var trailing: AnyView?
}

struct NotchBandKey: PreferenceKey {
    static var defaultValue = NotchBandItems()

    static func reduce(value: inout NotchBandItems, nextValue: () -> NotchBandItems) {
        let next = nextValue()
        if let leading = next.leading { value.leading = leading }
        if let trailing = next.trailing { value.trailing = trailing }
    }
}

extension View {
    /// Puts controls in the island's top row, beside the camera where they
    /// fit there. The page keeps their state: they are drawn from its body.
    /// Each call sets only its own sides, so an outer call leaves the other
    /// side to what the page inside it set.
    func notchBand<Leading: View, Trailing: View>(@ViewBuilder leading: () -> Leading,
                                                  @ViewBuilder trailing: () -> Trailing) -> some View {
        let leading = AnyView(leading()), trailing = AnyView(trailing())
        return transformPreference(NotchBandKey.self) { $0.leading = leading; $0.trailing = trailing }
    }

    func notchBand<Leading: View>(@ViewBuilder leading: () -> Leading) -> some View {
        let leading = AnyView(leading())
        return transformPreference(NotchBandKey.self) { $0.leading = leading }
    }

    func notchBand<Trailing: View>(@ViewBuilder trailing: () -> Trailing) -> some View {
        let trailing = AnyView(trailing())
        return transformPreference(NotchBandKey.self) { $0.trailing = trailing }
    }
}

/// The open island's top row: a page's controls on either side of the
/// camera, each side kept clear of it, or one row across an island without
/// one, its leading controls at the start and its trailing ones at the end.
struct NotchBandRow<Leading: View, Trailing: View>: View {
    let band: NotchBand
    /// A side a level reading covers for a moment: its controls stay in place
    /// and keep their state, out of sight and out of reach.
    var covered: HorizontalEdge? = nil
    @ViewBuilder let leading: () -> Leading
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 0) {
            side(covered == .leading) {
                HStack(spacing: 6) { leading() }
            }
            .frame(width: band.besideCamera ? band.side : nil, alignment: .leading)
            .frame(maxWidth: band.besideCamera ? nil : .infinity, alignment: .leading)
            Spacer(minLength: band.besideCamera ? 0 : 12)
            side(covered == .trailing) {
                HStack(spacing: 6) { trailing() }
            }
            .frame(width: band.besideCamera ? band.side : nil, alignment: .trailing)
            // Across the top the trailing controls take what they need first,
            // measured against the room the row has, so whatever has to give
            // way (the island's own marks first) is told how much there is.
            .layoutPriority(band.besideCamera ? 0 : 1)
        }
        .frame(height: band.height)
    }

    private func side<Content: View>(_ hidden: Bool, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .opacity(hidden ? 0 : 1)
            .allowsHitTesting(!hidden)
            .accessibilityHidden(hidden)
    }
}

/// The native host publishes the same path used by its animated mask. Keeping
/// this in canvas coordinates avoids scaling the glass's corners independently.
final class NotchBackdropPresentation: ObservableObject {
    @Published var contour = Path(CGRect.zero)
    @Published var usesGlass = false
    /// The camera strip's height in points, which the translucent background
    /// keeps black at every island height.
    @Published var stripHeight: CGFloat = 0
    @Published private(set) var fade = NotchGlassFade.open
    /// The menu bar a floating capsule leaves below itself, part of the
    /// surface height a fade is planned in.
    var floatingGap: CGFloat = 0

    /// Measured from the top edge, as the fade is planned: a floating
    /// capsule's contour starts below it and ends above the surface's bottom.
    var openness: Double { Double(fade.openness(atHeight: contourBottom + floatingGap)) }
    fileprivate var contourBottom: CGFloat { contour.boundingRect.isNull ? 0 : contour.boundingRect.maxY }

    /// How much of the resting black still lies beneath the glass. It lets go
    /// as the glass opens and is gone once the glass is fully open, so an
    /// opening never settles over a black that then vanishes at once.
    var restingBlack: Double { 1 - openness }

    /// Plans a resize from `start` to `end` from what is on screen now.
    func planFade(from start: CGFloat, to end: CGFloat, endsInGlass: Bool) {
        setFade(.plan(from: start, to: end, endsInGlass: endsInGlass,
                      current: usesGlass ? fade.openness(atHeight: start) : 0))
    }

    func openFully() { setFade(.open) }

    /// The fade follows the moving contour frame by frame; SwiftUI must not
    /// add an animation of its own on top.
    private func setFade(_ next: NotchGlassFade) {
        guard fade != next else { return }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { fade = next }
    }
}

struct NotchBackdropShape: Shape {
    var contour: Path
    func path(in rect: CGRect) -> Path {
        let safeRect = CGRect(x: rect.minX.isFinite ? rect.minX : 0,
                              y: rect.minY.isFinite ? rect.minY : 0,
                              width: max(0, rect.width.isFinite ? rect.width : 0),
                              height: max(0, rect.height.isFinite ? rect.height : 0))
        let bbox = contour.boundingRect
        if contour.isEmpty || bbox.isNull || !bbox.origin.x.isFinite || !bbox.origin.y.isFinite {
            return Path(CGRect(x: safeRect.minX, y: safeRect.minY, width: 0, height: 0))
        }
        return contour
    }
}

struct NotchWindowBackground: View {
    @ObservedObject var presentation: NotchBackdropPresentation
    @ObservedObject private var notch = NotchService.shared
    @ObservedObject private var music = NotchMusicService.shared
    private let glass = LiquidGlassSupport.isSupported
    @AppStorage(DefaultsKey.notchTranslucentBackground) private var translucent = false
    @AppStorage(DefaultsKey.notchLiveEqualizer) private var visualizerEnabled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var showsMusicGlow: Bool {
        notch.isMusicPageExpanded
            // The same backdrop component is used by compact mirror islands.
            // Never color their shorter silhouettes when Music is open elsewhere.
            && presentation.contour.boundingRect.height >= 160
            // Keep the glow view mounted through an empty-palette interval,
            // so a departing cover fades out instead of cutting to black.
            && music.playback != nil
    }

    var body: some View {
        NotchSurfaceBackground(presentation: presentation, glass: glass, translucent: translucent)
            .overlay {
                if showsMusicGlow, let playback = music.playback {
                    // The backdrop is a separate AppKit hosting view under the
                    // page content, and its contour is the window's exact mask.
                    // A player-local background cannot reach these curved edges.
                    NotchMusicWindowGlow(palette: music.artworkGlowPalette,
                                         isPlaying: playback.isPlaying,
                                         contour: presentation.contour,
                                         cameraHeight: presentation.stripHeight,
                                         enabled: visualizerEnabled)
                        .mask(NotchBackdropShape(contour: presentation.contour))
                        .opacity(visualizerEnabled ? min(1, max(0, presentation.openness)) : 0)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28),
                                   value: visualizerEnabled)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }
}

/// Convert the equalizer's seven frequency bands into an ambient light pulse.
/// The equalizer has its own fast attack and per-band gain; a second, slower
/// envelope prevents each 30Hz bar update from jostling the entire backdrop.
/// Input band order is low bass to high treble (50 Hz to 12 kHz).
struct NotchMusicGlowEnvelope {
    private var lastSampleTime: TimeInterval?
    private var baseline = 0.0
    private var previousEnergy = 0.0
    private var transientPeak = 0.08
    private(set) var value = 0.0

    mutating func next(_ levels: [Double]?, at time: TimeInterval) -> Double {
        guard let levels, levels.count >= 6 else {
            // No captured audio is different from a quiet musical passage.
            // Re-arm when a tap begins again; ambient drift remains independent.
            self = Self()
            return 0
        }

        let dt = lastSampleTime.map { min(0.15, max(1.0 / 60.0, time - $0)) } ?? (1.0 / 30.0)
        let bass = 0.52 * levels[0] + 0.48 * levels[1] // 50-250 Hz
        let body = 0.5 * (levels[2] + levels[3])      // 250-1000 Hz
        let presence = 0.5 * (levels[4] + levels[5])  // 1-4.5 kHz
        let energy = min(1, max(0, bass * 0.54 + body * 0.34 + presence * 0.12))

        if lastSampleTime == nil {
            // Starting at the current song level avoids a false flash when
            // a tap comes online or the music resumes after silence.
            baseline = energy
            previousEnergy = energy
            lastSampleTime = time
            return value
        }
        lastSampleTime = time

        // A slow baseline tracks differences in master volume and mastering.
        // Only changes relative to that baseline should create a beat pulse.
        let baselineAlpha = 1 - exp(-dt / 1.7)
        baseline += (energy - baseline) * baselineAlpha
        let rise = max(0, energy - previousEnergy)
        previousEnergy = energy
        let transient = max(0, energy - baseline) * 0.78 + rise * 0.30
        transientPeak = max(0.065, transient, transientPeak * exp(-dt / 3.2))

        // Adaptive peak reference responds to quiet tracks without maxing out
        // every sample. A small deadband removes flicker from tiny variations.
        let relative = min(1, transient / transientPeak)
        let target = min(1, max(0, (relative - 0.12) / 0.88))
        let tau = target > value ? 0.16 : 0.60
        value += (target - value) * (1 - exp(-dt / tau))
        return value
    }
}

/// A deterministic, non-repeating-looking drift for album-colored light.
/// Combining several slow, incommensurate waves gives the movement of a
/// free-flowing gradient without the flicker of per-frame random positions.
/// Both the full Island and the compact music card share these trajectories;
/// the audio envelope remains responsible for beat-driven brightness.
struct NotchMusicColorFlow {
    static func offset(index: Int, time: TimeInterval) -> CGPoint {
        let seed = Double(index) * 2.399963229728653
        let x = 0.63 * sin(time * (0.19 + Double(index) * 0.013) + seed)
              + 0.25 * sin(time * (0.34 + Double(index) * 0.017) + seed * 1.73)
              + 0.12 * cos(time * 0.11 + seed * 0.61)
        let y = 0.58 * cos(time * (0.16 + Double(index) * 0.011) + seed * 1.31)
              + 0.29 * sin(time * (0.29 + Double(index) * 0.014) + seed * 0.83)
              + 0.13 * cos(time * 0.10 + seed * 1.97)
        return CGPoint(x: x, y: y)
    }

    static func radius(index: Int, time: TimeInterval) -> CGFloat {
        let seed = Double(index) * 2.399963229728653
        return CGFloat(0.94 + 0.075 * sin(time * 0.21 + seed * 0.93)
                     + 0.025 * cos(time * 0.37 + seed * 1.51))
    }

    static func brightness(index: Int, time: TimeInterval) -> Double {
        0.91 + 0.09 * sin(time * 0.23 + Double(index) * 2.11)
    }
}

/// Album colors illuminate the actual window backdrop, not an inset card.
/// The stage can be wider than the visible island, so all drawing coordinates
/// are relative to the animated contour's bounding rectangle.
private struct NotchMusicWindowGlow: View {
    let palette: [NotchArtworkTint]
    let isPlaying: Bool
    let contour: Path
    let cameraHeight: CGFloat
    let enabled: Bool
    @ObservedObject private var audio = NotchAudioLevelService.shared
    @State private var envelope = NotchMusicGlowEnvelope()
    @State private var audioPulse = 0.0
    @State private var outgoingPalette: [NotchArtworkTint] = []
    @State private var paletteTransitionStarted: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var bounds: CGRect { contour.boundingRect }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0,
                                paused: !enabled || reduceMotion || (!isPlaying && paletteTransitionStarted == nil)
                                    || (palette.isEmpty && outgoingPalette.isEmpty))) { tick in
            Canvas(opaque: false, rendersAsynchronously: true) { context, _ in
                let b = bounds
                guard b.width > 0, b.height > 0 else { return }

                let pulse = isPlaying && !reduceMotion ? audioPulse : 0
                let time = isPlaying && !reduceMotion ? tick.date.timeIntervalSinceReferenceDate : 0
                let elapsed = paletteTransitionStarted.map { tick.date.timeIntervalSince($0) } ?? 0.62
                let fraction = min(1, max(0, elapsed / 0.62))
                let fade = fraction * fraction * (3 - 2 * fraction)

                if !outgoingPalette.isEmpty && fade < 1 {
                    draw(palette: outgoingPalette, opacity: 1 - fade,
                         pulse: pulse, time: time, bounds: b, context: context)
                }
                draw(palette: palette, opacity: paletteTransitionStarted == nil ? 1 : fade,
                     pulse: pulse, time: time, bounds: b, context: context)
            }
        }
        // Screen blending lifts light out of black without a muddy dark fill.
        // The fade protects the camera band; it is NOT a clip of the player.
        .blendMode(.screen)
        .mask {
            Canvas(opaque: false) { context, _ in
                let b = bounds
                guard b.width > 0, b.height > 0 else { return }
                let darkTo = min(0.66, max(0, cameraHeight / b.height))
                let clearTo = min(1, darkTo + 0.34)
                let cameraFade = Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .clear, location: darkTo),
                    .init(color: .white.opacity(0.72), location: clearTo),
                    .init(color: .white, location: 1)
                ])
                context.fill(Path(b), with: .linearGradient(
                    cameraFade,
                    startPoint: CGPoint(x: b.midX, y: b.minY),
                    endPoint: CGPoint(x: b.midX, y: b.maxY)))
            }
        }
        .opacity(reduceTransparency ? 0.72 : 1)
        .onReceive(audio.$levels) { levels in
            guard enabled else { return }
            audioPulse = envelope.next(levels, at: ProcessInfo.processInfo.systemUptime)
        }
        .onChange(of: enabled) { _, isEnabled in
            if !isEnabled {
                envelope = NotchMusicGlowEnvelope()
                audioPulse = 0
            }
        }
        .onChange(of: palette) { old, new in
            guard old != new else { return }
            if reduceMotion {
                outgoingPalette = []
                paletteTransitionStarted = nil
            } else {
                outgoingPalette = old
                paletteTransitionStarted = Date()
            }
        }
        .task(id: paletteTransitionStarted) {
            guard paletteTransitionStarted != nil else { return }
            // Draw both palettes for the brief transition only. A new cover
            // cancels this task and starts a fresh blend without a hard cut.
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            outgoingPalette = []
            paletteTransitionStarted = nil
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    /// Draw a single palette into the SAME canvas as its outgoing version.
    /// Alpha weights sum to one, avoiding doubled brightness and extra audio
    /// observers while the artwork and glow crossfade.
    private func draw(palette: [NotchArtworkTint], opacity: Double,
                      pulse: Double, time: Double, bounds b: CGRect,
                      context: GraphicsContext) {
        guard let firstTint = palette.first, opacity > 0 else { return }
        let first = softened(firstTint)
        let foundation = Gradient(stops: [
            .init(color: first.opacity(0.035 * opacity), location: 0),
            .init(color: first.opacity(0.065 * opacity), location: 0.48),
            .init(color: first.opacity(0.11 * opacity), location: 1)
        ])
        context.fill(Path(b), with: .linearGradient(
            foundation,
            startPoint: CGPoint(x: b.midX, y: b.minY),
            endPoint: CGPoint(x: b.midX, y: b.maxY)))

        let horizontal: [CGFloat] = [0.22, 0.76, 0.47]
        let vertical: [CGFloat] = [0.54, 0.71, 0.91]
        let radiusBase = max(b.width * 0.73, b.height * 0.85)
        for (index, tint) in palette.prefix(3).enumerated() {
            // Each colour follows a different, smoothly wandering path.
            // Only the light fields move; the Island contour and UI stay put.
            let offset = NotchMusicColorFlow.offset(index: index, time: time)
            let cx = b.minX + b.width * (horizontal[index] + offset.x * 0.19)
            let cy = b.minY + b.height * (vertical[index] + offset.y * 0.13)
            let radius = radiusBase * (NotchMusicColorFlow.radius(index: index, time: time)
                                       + CGFloat(pulse) * 0.012)
            let strength = ((index == 0 ? 0.22 : 0.17)
                            * NotchMusicColorFlow.brightness(index: index, time: time)
                            + pulse * 0.040) * opacity
            let color = softened(tint)
            let gradient = Gradient(stops: [
                .init(color: color.opacity(strength), location: 0),
                .init(color: color.opacity(strength * 0.64), location: 0.43),
                .init(color: color.opacity(0), location: 1)
            ])
            context.fill(Path(ellipseIn: CGRect(
                x: cx - radius, y: cy - radius,
                width: radius * 2, height: radius * 2)),
                with: .radialGradient(gradient, center: CGPoint(x: cx, y: cy),
                                      startRadius: 0, endRadius: radius))
        }
    }

    /// Bright covers, such as neon-green artwork, retain their hue without
    /// spraying pure saturated RGB over the Liquid Glass surface.
    private func softened(_ tint: NotchArtworkTint) -> Color {
        Color(.sRGB,
              red: 0.30 + tint.red * 0.61,
              green: 0.30 + tint.green * 0.61,
              blue: 0.30 + tint.blue * 0.61,
              opacity: 1)
    }
}

/// Keep the upper content dark and open the lower surface into a refractive lip.
struct NotchSurfaceBackground: View {
    @ObservedObject var presentation: NotchBackdropPresentation
    let glass: Bool
    var translucent = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var offersGlass: Bool {
#if compiler(>=6.2)
        if #available(macOS 26, *) { return glass && !reduceTransparency }
#endif
        return false
    }

    private var showsGlass: Bool { offersGlass && presentation.usesGlass }
    private var showsTranslucent: Bool {
        translucent && !offersGlass && presentation.usesGlass && !reduceTransparency
    }

    var body: some View {
        ZStack {
            // The black the island rests in stays beneath the glass until
            // the glass has opened, and the glass exists only while that
            // black lets it show, so the window's resizes at either end of a
            // transition happen in plain black.
            Color.black.opacity(showsGlass || showsTranslucent ? presentation.restingBlack : 1)
#if compiler(>=6.2)
            if #available(macOS 26, *), showsGlass, presentation.restingBlack < 1 {
                let shape = NotchBackdropShape(contour: presentation.contour)
                Color.clear
                    .glassEffect(.clear, in: shape)
                    .environment(\.appearsActive, true)
                    .materialActiveAppearance(.active)
                    .overlay {
                        LinearGradient(stops: Self.shade(openness: presentation.openness, contrast: contrast),
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: presentation.contourBottom)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .mask(shape)
                    }
            }
#endif
            if showsTranslucent, presentation.restingBlack < 1 {
                translucentOrBlack
            }
        }
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The dimming over the glass, from the top of the island to its lip. Near
    /// a black strip the lip closes up, so the last frames of a collapse
    /// already match the resting island.
    static func shade(openness: Double, contrast: ColorSchemeContrast) -> [Gradient.Stop] {
        (0...64).map { index in
            let t = Double(index) / 64
            return Gradient.Stop(
                color: .black.opacity(1 - openness * (contrast == .increased ? 0.10 : 0.45) * pow(t, 2.5)),
                location: t)
        }
    }
}

extension NotchSurfaceBackground {
    /// The system's behind-window blur while the island is open, black over
    /// the camera strip so every open state meets the housing as the resting
    /// island does. Reduce Transparency keeps it black.
    @ViewBuilder var translucentOrBlack: some View {
        if translucent, presentation.usesGlass, !reduceTransparency {
            let shape = NotchBackdropShape(contour: presentation.contour)
            let height = presentation.contourBottom
            let stops = NotchTranslucentTint.stops(height: height, stripHeight: presentation.stripHeight,
                                                   openness: presentation.openness,
                                                   increasedContrast: contrast == .increased)
                .map { Gradient.Stop(color: .black.opacity($0.opacity), location: $0.location) }
            // The blur covers only the island's box. Its mask image is drawn
            // again on every frame of a resize, and at the stage's size it
            // would be as large as the largest display.
            let box = presentation.contour.boundingRect.integral
            ZStack(alignment: .topLeading) {
                if !box.isNull, box.width > 0, box.height > 0 {
                    NotchTranslucentMaterial(contour: presentation.contour.offsetBy(dx: -box.minX, dy: -box.minY).cgPath)
                        .frame(width: box.width, height: box.height)
                        .padding(EdgeInsets(top: box.minY, leading: box.minX, bottom: 0, trailing: 0))
                }
                LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
                    .frame(height: height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .mask(shape)
            }
        } else {
            Color.black
        }
    }
}

/// `NSVisualEffectView` blurs behind the window only inside its mask image,
/// so the mask follows the island's contour as it animates.
private struct NotchTranslucentMaterial: NSViewRepresentable {
    let contour: CGPath

    func makeNSView(context: Context) -> NotchTranslucentView {
        let view = NotchTranslucentView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ view: NotchTranslucentView, context: Context) {
        view.contour = contour
    }
}

private final class NotchTranslucentView: NSVisualEffectView {
    var contour: CGPath? {
        didSet { if contour != oldValue { updateMask() } }
    }

    override var isFlipped: Bool { true }

    /// The view follows the island's box, so each new size gets its mask at
    /// once. Without one the whole view would blur.
    override func setFrameSize(_ newSize: NSSize) {
        let resized = newSize != frame.size
        super.setFrameSize(newSize)
        if resized { updateMask() }
    }

    private func updateMask() {
        guard let contour, bounds.width > 0, bounds.height > 0 else {
            maskImage = nil
            return
        }
        maskImage = NSImage(size: bounds.size, flipped: true) { _ in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.addPath(contour)
            context.setFillColor(.black)
            context.fillPath()
            return true
        }
    }
}

/// Controls on the glass shell use quiet translucent fills, leaving the
/// refraction to the island rather than stacking separate glass lenses.
struct NotchControlSurface: ViewModifier {
    let cornerRadius: CGFloat
    var selected = false
    var interactive = true
    private let glass = LiquidGlassSupport.isSupported
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.notchGlassSurface) private var glassSurface

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if glassSurface {
                content
                    .background(.white.opacity(selected ? 0.11 : 0.045), in: shape)
                    .overlay {
                        shape.strokeBorder(.white.opacity(selected ? 0.16 : 0.065), lineWidth: 0.5)
                            .allowsHitTesting(false)
                    }
            } else {
#if compiler(>=6.2)
                if #available(macOS 26, *), glass, !reduceTransparency {
                    content.background(.white.opacity(selected ? 0.12 : 0.065), in: shape)
                        .glassEffect(.regular.interactive(interactive), in: shape)
                } else {
                    content.background(.white.opacity(selected ? 0.12 : 0.065), in: shape)
                        .overlay {
                            shape.strokeBorder(.white.opacity(contrast == .increased ? 0.24 : (selected ? 0.16 : 0.065)),
                                               lineWidth: 0.5)
                                .allowsHitTesting(false)
                        }
                }
#else
                content.background(.white.opacity(selected ? 0.12 : 0.065), in: shape)
                    .overlay {
                        shape.strokeBorder(.white.opacity(contrast == .increased ? 0.24 : (selected ? 0.16 : 0.065)),
                                           lineWidth: 0.5)
                            .allowsHitTesting(false)
                    }
#endif
            }
        }
    }
}

/// One entry of a native menu popped up from a SwiftUI control.
struct NotchMenuItem {
    let title: String
    var checked = false
    var symbol: String? = nil
    var enabled = true
    var action: () -> Void = {}

    /// A line between groups of entries.
    static let separator = NotchMenuItem(title: "")
    var isSeparator: Bool { title.isEmpty }
}

/// A control SwiftUI draws in full that pops up a native menu. `Menu`
/// cannot do this: its borderless style turns the label into a pop-up
/// button title, one line cut with an ellipsis, images moved to the front
/// and frames ignored, so anything but a lone glyph loses its shape.
struct NotchMenuButton<Label: View>: View {
    let title: String
    let items: [NotchMenuItem]
    var cornerRadius: CGFloat = 6
    var lifts = false
    @ViewBuilder let label: () -> Label
    @State private var anchor = NotchMenuAnchor()

    var body: some View {
        Button { anchor.popUp(items) } label: { label() }
            .buttonStyle(NotchButtonStyle(cornerRadius: cornerRadius, lifts: lifts))
            .background(NotchMenuAnchorView(anchor: anchor))
            .help(title)
            .accessibilityLabel(title)
    }
}

/// The way back in the island's top row. It names where it is, as a title
/// did above a detail before the island stopped naming its pages.
struct NotchBandBackButton: View {
    let title: String
    var showsTitle: Bool = true
    let action: () -> Void
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
                if showsTitle && !title.isEmpty {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.horizontal, showsTitle && !title.isEmpty ? 7 : 8)
            .frame(height: 28)
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: 9))
        .help(l10n.s.navigationBack)
        .accessibilityLabel(l10n.s.navigationBack)
        .accessibilityValue(title)
    }
}

/// What a menu in the island's top row reads: its current choice, cut to the
/// room its side leaves, with the chevron that says a list opens from it.
struct NotchBandMenuLabel: View {
    let title: String
    var symbol: String? = nil
    var truncation: Text.TruncationMode = .tail

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol).foregroundStyle(.white.opacity(0.55))
            }
            Text(title).lineLimit(1).truncationMode(truncation)
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold))
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 7)
        .frame(height: 28)
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// A chooser whose current choice reads in full: up to two centred lines, or
/// one line cut in the middle, with the list as a native menu below it.
struct NotchDeviceMenu: View {
    let title: String
    let current: String
    var width: CGFloat = 100
    var lines = 2
    var alignment: TextAlignment = .center
    let items: [NotchMenuItem]

    var body: some View {
        NotchMenuButton(title: title, items: items) {
            Text("\(current) \(Image(systemName: "chevron.down"))")
                .font(.system(size: 10, weight: .medium))
                .lineLimit(lines)
                .multilineTextAlignment(alignment)
                .truncationMode(lines > 1 ? .tail : .middle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: width, alignment: frameAlignment)
                .padding(.horizontal, 4)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .help(current)
        .accessibilityValue(current)
    }

    private var frameAlignment: Alignment {
        switch alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

/// Owns the native menu's targets while it is up and remembers the view it
/// pops up from. Menu tracking keeps the island open on its own.
final class NotchMenuAnchor: NSObject, NSMenuDelegate {
    weak var view: NSView?
    private var actions: [() -> Void] = []
    var onMenuOpenChanged: ((Bool) -> Void)?

    func menuWillOpen(_ menu: NSMenu) {
        onMenuOpenChanged?(true)
    }

    func menuDidClose(_ menu: NSMenu) {
        onMenuOpenChanged?(false)
    }

    func popUp(_ items: [NotchMenuItem], appearance: NSAppearance? = NSAppearance(named: .darkAqua)) {
        guard let view else { return }
        actions = items.map(\.action)
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        // The island is dark whatever the system is, so its menus are too.
        if let appearance {
            menu.appearance = appearance
        }
        for (index, item) in items.enumerated() {
            guard !item.isSeparator else { menu.addItem(.separator()); continue }
            let entry = NSMenuItem(title: item.title, action: #selector(choose(_:)), keyEquivalent: "")
            entry.target = self
            entry.tag = index
            entry.state = item.checked ? .on : .off
            entry.isEnabled = item.enabled
            if let symbol = item.symbol {
                entry.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            }
            menu.addItem(entry)
        }
        // A menu whose top lands on the menu bar's edge opens scrolled past its
        // first entry, so a button against the bar opens it a little below.
        var location = NSPoint.zero
        if let window = view.window, let screen = window.screen {
            let bottom = window.convertPoint(toScreen: view.convert(location, to: nil)).y
            let edge = screen.visibleFrame.maxY - 3
            if bottom > edge { location.y -= bottom - edge }
        }
        menu.popUp(positioning: nil, at: location, in: view)
    }

    @objc private func choose(_ sender: NSMenuItem) {
        guard actions.indices.contains(sender.tag) else { return }
        actions[sender.tag]()
    }
}

struct NotchMenuAnchorView: NSViewRepresentable {
    let anchor: NotchMenuAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        anchor.view = nsView
    }
}

extension NSAlert {
    /// A SwiftUI alert or confirmation dialog hangs from the island as a
    /// sheet, which moves and reskins the borderless surface. Inside the
    /// island a tool asks the same question on its own, just above it, like
    /// the Scratchpad page does, and the island gets the keyboard back after.
    static func confirmAboveIsland(_ title: String, message: String, action: String,
                                   destructive: Bool, cancel: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: action).hasDestructiveAction = destructive
        // Escape cancels in every language, like the dialog's cancel role.
        alert.addButton(withTitle: cancel).keyEquivalent = "\u{1b}"
        return alert.runAboveIsland() == .alertFirstButtonReturn
    }

    private func runAboveIsland() -> NSApplication.ModalResponse {
        let island = NotchService.shared.presentationWindow
        var observers: [NSObjectProtocol] = []
        if let island {
            // The modal session puts the alert at the modal panel level, below
            // the island, and puts it back there when it activates the app or
            // makes the alert key. Raise it once running and after each of those.
            let level = NSWindow.Level(rawValue: island.level.rawValue + 1)
            let alertWindow = window
            let raise: (Notification) -> Void = { _ in alertWindow.level = level }
            observers = [NSWindow.didBecomeKeyNotification, NSApplication.didBecomeActiveNotification].map {
                NotificationCenter.default.addObserver(forName: $0, object: nil, queue: .main, using: raise)
            }
            DispatchQueue.main.async { alertWindow.level = level }
        }
        NSApp.activate(ignoringOtherApps: true)
        let response = runModal()
        observers.forEach(NotificationCenter.default.removeObserver)
        // A closed island declines key status, so this only returns to an open one.
        if let island, island.isVisible { island.makeKey() }
        return response
    }
}

extension NSSavePanel {
    /// Runs an open or save panel from inside the island just above it, like
    /// `NSAlert.confirmAboveIsland`: an application-modal panel would open
    /// below the island, and a sheet would move and reskin its surface.
    func runAboveIsland() -> NSApplication.ModalResponse {
        let island = NotchService.shared.presentationWindow
        var observers: [NSObjectProtocol] = []
        if let island {
            // The modal session resets the level when it activates the app or
            // makes the panel key. Raise it once running and after each reset.
            let level = NSWindow.Level(rawValue: island.level.rawValue + 1)
            let raise: (Notification) -> Void = { [weak self] _ in self?.level = level }
            observers = [NSWindow.didBecomeKeyNotification, NSApplication.didBecomeActiveNotification].map {
                NotificationCenter.default.addObserver(forName: $0, object: nil, queue: .main, using: raise)
            }
            DispatchQueue.main.async { [weak self] in self?.level = level }
        }
        NSApp.activate(ignoringOtherApps: true)
        let response = runModal()
        observers.forEach(NotificationCenter.default.removeObserver)
        // A closed island declines key status, so this only returns to an open one.
        if let island, island.isVisible { island.makeKey() }
        return response
    }
}
