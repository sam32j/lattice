// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The wheel itself: a glass disc with one chip per action, a highlight wedge
/// under the pointed slice, a hub that names the selection or leads back, and
/// the profile tabs on an arc above the wheel.
struct RadialMenuView: View {
    @ObservedObject private var service = RadialMenuService.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where the highlight sits right now. Kept unwrapped past a full turn, so
    /// the step from the last slice to the first is one step onward and not a
    /// spin all the way back.
    @State private var wedgeAngle = 0.0
    @State private var wedgeSlice = Double.pi / 3
    @State private var wedgeShown = false

    /// The whole opening sweep lands inside this, however many slices there
    /// are: a wheel of twelve must not take twice as long to draw itself as a
    /// wheel of six.
    private static let sweepDuration = 0.17
    static let coordinateSpace = "RadialMenuPanel"

    private var text: RadialMenuFeatureStrings { FeatureStrings.radialMenu(l10n.language) }
    private var items: [RadialMenuItem] { service.stack.last ?? [] }
    /// Reduce Motion is the only switch over this wheel: opening this way is
    /// what the menu is now, not a preference.
    private var animates: Bool { !reduceMotion }
    private var profileColor: RadialMenuColor { service.activeProfile?.color ?? .accent }

    var body: some View {
        ZStack {
            backplate
            wedge
            ring
                .id("\(service.profileSwitchCount).\(service.stack.count)")
                // A profile switch folds the old chips into the hub; Reduce
                // Motion crossfades instead.
                .transition(animates ? .scale(scale: 0.3).combined(with: .opacity) : .opacity)
            hub
            if service.sessionProfiles.count > 1 {
                RadialTabArc(service: service, text: text, colorScheme: colorScheme)
            }
        }
        .frame(width: service.panelSide, height: service.panelSide)
        .coordinateSpace(name: Self.coordinateSpace)
        .animation(animates ? .easeOut(duration: 0.16) : .linear(duration: 0.12), value: service.profileSwitchCount)
        // The whole panel is tappable; the service decides by distance, so a
        // click on the transparent corners dismisses instead of dying.
        .contentShape(Rectangle())
        .onTapGesture { service.activatePointer() }
        // The wheel grows into the screen and settles back instead of being
        // stamped onto it. The window's own fade carries the shadow and the
        // material; this carries the size.
        .scaleEffect(service.visible || !animates ? 1 : 0.9)
        .animation(animates
                   ? (service.visible
                      ? .spring(response: 0.27, dampingFraction: 0.86)
                      : .easeIn(duration: 0.13))
                   : nil,
                   value: service.visible)
        .onAppear(perform: placeWedgeWithoutMotion)
        .onChange(of: service.highlightedIndex) { _, _ in syncWedge() }
        .onChange(of: items.count) { _, _ in syncWedge() }
        .onChange(of: service.profileSwitchCount) { _, _ in syncWedge() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(text.pageTitle)
    }

    /// One shape that sweeps to the slice under the pointer instead of a new
    /// one being stamped over the old. Always present, so moving between
    /// slices is a movement and not a swap.
    private var wedge: some View {
        RadialWedgeShape(centerAngle: wedgeAngle,
                         sliceAngle: wedgeSlice,
                         innerRadius: RadialMenuLayout.deadZoneRadius,
                         outerRadius: RadialMenuLayout.wheelDiameter / 2 - 4)
            .fill(profileColor.gradient(for: colorScheme))
            // Strongest out at the chip, almost gone by the hub: the wedge
            // points outward, the way the gesture does.
            .mask(RadialWedgeRamp(scheme: colorScheme,
                                  innerRadius: RadialMenuLayout.deadZoneRadius,
                                  outerRadius: RadialMenuLayout.wheelDiameter / 2))
            .frame(width: RadialMenuLayout.wheelDiameter, height: RadialMenuLayout.wheelDiameter)
            .opacity(wedgeShown ? 1 : 0)
    }

    /// A wheel that appears with a slice already highlighted (the rendering
    /// probe's) shows its wedge at once; onChange never runs for that value.
    private func placeWedgeWithoutMotion() {
        guard !wedgeShown, !items.isEmpty, let index = service.highlightedIndex,
              items.indices.contains(index) else { return }
        let slice = 2 * Double.pi / Double(items.count)
        wedgeSlice = slice
        wedgeAngle = slice * Double(index)
        wedgeShown = true
    }

    private func syncWedge() {
        let count = items.count
        guard count > 0, let index = service.highlightedIndex, items.indices.contains(index) else {
            guard wedgeShown else { return }
            withAnimation(animates ? .easeOut(duration: 0.12) : nil) { wedgeShown = false }
            return
        }
        let slice = 2 * Double.pi / Double(count)
        var angle = slice * Double(index)
        guard wedgeShown else {
            // Nothing to sweep from: the highlight simply appears under the
            // pointer that armed it.
            var placement = Transaction()
            placement.disablesAnimations = true
            withTransaction(placement) {
                wedgeAngle = angle
                wedgeSlice = slice
            }
            withAnimation(animates ? .easeOut(duration: 0.12) : nil) { wedgeShown = true }
            return
        }
        // The short way round, so the step from the last slice to the first
        // crosses the top instead of unwinding the whole wheel. The remainder
        // is signed and never past half a turn, which is exactly that step.
        angle = wedgeAngle + (angle - wedgeAngle).remainder(dividingBy: 2 * Double.pi)
        withAnimation(animates ? .spring(response: 0.2, dampingFraction: 0.86) : nil) {
            wedgeAngle = angle
            wedgeSlice = slice
        }
    }

    private var backplate: some View {
        RadialWheelDisc(diameter: RadialMenuLayout.wheelDiameter,
                        sliceCount: items.count,
                        deadZoneRadius: RadialMenuLayout.deadZoneRadius)
            .shadow(color: .black.opacity(colorScheme == .light ? 0.22 : 0.55), radius: 24, y: 8)
    }

    /// The chips are thrown out of the hub one after another, clockwise from
    /// twelve o'clock, so the wheel draws itself around the pointer instead of
    /// landing on it whole. A submenu or another profile is a new set of
    /// chips and draws itself the same way.
    private var ring: some View {
        let count = items.count
        return ZStack {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                RadialChipView(item: item,
                               nowPlayingState: service.nowPlayingState,
                               highlighted: service.highlightedIndex == index,
                               animates: animates,
                               profileColor: profileColor,
                               direction: RadialMenuGeometry.unitPosition(index: index, itemCount: count),
                               openDelay: Self.openDelay(index: index, count: count),
                               open: service.visible)
                    .accessibilityLabel(item.displayName(text, nowPlayingState: service.nowPlayingState))
                    .accessibilityAddTraits(.isButton)
            }
        }
    }

    private static func openDelay(index: Int, count: Int) -> Double {
        guard count > 1 else { return 0 }
        return sweepDuration * Double(index) / Double(count - 1)
    }

    // No disc behind the hub: the label, the back hint and the brand mark sit
    // straight on the wheel's glass, quiet and centered. What it says changes
    // with every slice the pointer crosses, so it changes by crossing over
    // rather than by being replaced between two frames.
    private var hub: some View {
        ZStack {
            // The dead zone is a target: it steps back out of a submenu and
            // it is where the pointer rests without arming anything. A plate
            // this faint is not decoration, it is the only thing that says so.
            Circle()
                .fill(Color.primary.opacity(colorScheme == .light ? 0.045 : 0.075))
                .frame(width: RadialMenuLayout.hubDiameter, height: RadialMenuLayout.hubDiameter)
            hubFace
                .id(hubFaceKey)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
        }
        .frame(width: RadialMenuLayout.hubDiameter, height: RadialMenuLayout.hubDiameter)
        .animation(animates ? .easeOut(duration: 0.14) : nil, value: hubFaceKey)
    }

    /// What the hub is saying right now. A change here is a change of face,
    /// which is what the cross-fade is keyed on.
    private var hubFaceKey: String {
        if let index = service.highlightedIndex, items.indices.contains(index) {
            return "item.\(items[index].id)"
        }
        if let name = service.flashedProfileName { return "profile.\(service.profileSwitchCount).\(name)" }
        if let parent = service.trail.last { return "back.\(parent)" }
        if items.isEmpty { return "empty" }
        return "brand"
    }

    @ViewBuilder
    private var hubFace: some View {
        if let index = service.highlightedIndex, items.indices.contains(index) {
            Text(items[index].displayName(text, nowPlayingState: service.nowPlayingState))
                .font(.system(size: 11, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 8)
        } else if let name = service.flashedProfileName {
            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(profileColor.color(for: colorScheme))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 8)
        } else if let parent = service.trail.last {
            VStack(spacing: 3) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(parent.isEmpty ? text.kindSubmenu : parent)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .accessibilityLabel(text.backButton)
        } else if items.isEmpty {
            Text(text.inMenuNoActions)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 8)
        } else {
            // Black on the light theme, white on the dark one: the owner
            // wants the mark clearly readable at the center.
            BrandMark(width: 34, tint: Color.primary)
        }
    }
}

/// The radial opacity ramp the highlight wedge is drawn through: almost
/// clear at the hub, strongest at the rim.
struct RadialWedgeRamp: View {
    let scheme: ColorScheme
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    var strength: Double = 1

    var body: some View {
        RadialGradient(colors: [.black.opacity((scheme == .light ? 0.12 : 0.16) * strength),
                                .black.opacity((scheme == .light ? 0.42 : 0.55) * strength)],
                       center: .center, startRadius: innerRadius, endRadius: outerRadius)
    }
}

/// The wheel's glass disc with its rim and the hairlines between slices.
/// Shared by the live menu and the Settings editor, so the editor is a
/// faithful preview in either appearance.
struct RadialWheelDisc: View {
    let diameter: CGFloat
    let sliceCount: Int
    let deadZoneRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        discMaterial
            // Glass is glass because of its edge: lit at the top, gone by the
            // bottom. A flat stroke all the way round reads as cut paper.
            .overlay(Circle().strokeBorder(PanelSurface.rimHighlight(for: colorScheme), lineWidth: 1.2))
            .overlay(Circle().strokeBorder(PanelSurface.border(for: colorScheme), lineWidth: 0.8))
            .overlay(sliceGuides)
            .frame(width: diameter, height: diameter)
    }

    @ViewBuilder
    private var discMaterial: some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *), !reduceTransparency {
            Circle()
                .fill(Color.clear)
                .glassEffect(.regular, in: Circle())
                .overlay(Circle().fill(PanelSurface.baseFill(for: colorScheme).opacity(colorScheme == .light ? 0.35 : 0.45)))
        } else {
            Circle()
                .fill(.regularMaterial)
                .overlay(Circle().fill(PanelSurface.baseFill(for: colorScheme)))
        }
#else
        Circle()
            .fill(.regularMaterial)
            .overlay(Circle().fill(PanelSurface.baseFill(for: colorScheme)))
#endif
    }

    /// A hairline between one slice and the next. Almost invisible on its own,
    /// but it is what turns a ring of buttons into a wheel with directions:
    /// the eye reads the whole wedge as the target, not just the icon.
    private var sliceGuides: some View {
        let length = diameter / 2 - deadZoneRadius - 14
        return ZStack {
            if sliceCount > 1 {
                ForEach(0..<sliceCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.primary.opacity(colorScheme == .light ? 0.07 : 0.09))
                        .frame(width: 1, height: length)
                        .offset(y: -(deadZoneRadius + length / 2 + 7))
                        .rotationEffect(.radians(2 * Double.pi * (Double(index) + 0.5) / Double(sliceCount)))
                }
            }
        }
    }
}

/// One action's round chip: raised on the glass, filled with the profile's
/// gradient while it is the one pointed at.
struct RadialChipFace: View {
    let item: RadialMenuItem
    let nowPlayingState: RadialNowPlayingState
    let highlighted: Bool
    let profileColor: RadialMenuColor
    var size: CGFloat = RadialMenuLayout.chipSize
    @Environment(\.colorScheme) private var colorScheme

    private var iconSize: CGFloat { size * 34 / 52 }
    private var symbolSize: CGFloat { size * 20 / 52 }

    var body: some View {
        ZStack {
            Circle()
                .fill(highlighted ? AnyShapeStyle(profileColor.gradient(for: colorScheme))
                                  : AnyShapeStyle(PanelSurface.raisedFill(for: colorScheme)))
                .overlay(Circle().strokeBorder(highlighted
                                               ? Color.clear
                                               : PanelSurface.raisedBorder(for: colorScheme),
                                               lineWidth: 0.8))
                // Its own shadow is what puts the chip ON the glass instead of
                // in it, the way the system's own round toggles sit on theirs.
                // Pointed at, that shadow takes the wheel's colour, so which
                // one is armed is never only a change of tint.
                .shadow(color: highlighted ? profileColor.color(for: colorScheme).opacity(0.45)
                                           : PanelSurface.raisedShadow(for: colorScheme),
                        radius: highlighted ? 13 : 5,
                        y: highlighted ? 4 : 2)
            icon
        }
        .frame(width: size, height: size)
    }

    private var symbolStyle: AnyShapeStyle {
        highlighted ? AnyShapeStyle(profileColor.foreground(for: colorScheme)) : AnyShapeStyle(.primary)
    }

    @ViewBuilder
    private var icon: some View {
        if item.mediaKey == .nowPlaying {
            if case let .playing(snapshot) = nowPlayingState,
               let icon = RadialNowPlayingApplication.icon(for: snapshot) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: iconSize, height: iconSize)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: symbolSize, weight: .semibold))
                    .foregroundStyle(symbolStyle)
            }
        } else if item.symbolName.isEmpty, let customImage = RadialMenuIconStore.customIcon(for: item) {
            Image(nsImage: customImage)
                .resizable()
                .interpolation(.high)
                .frame(width: iconSize, height: iconSize)
        } else if item.usesFileIcon {
            Image(nsImage: RadialMenuIconStore.fileIcon(for: item.payload))
                .resizable()
                .interpolation(.high)
                .frame(width: iconSize, height: iconSize)
        } else {
            Image(systemName: item.effectiveSymbolName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(symbolStyle)
        }
    }
}

/// A profile's color as a small gradient dot, the mark every tab carries.
/// On a tab already filled with that gradient it turns to the tab's text
/// color, so it never disappears into its own fill.
struct RadialProfileDot: View {
    let color: RadialMenuColor
    var size: CGFloat = 10
    var onOwnFill = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Circle()
            .fill(onOwnFill ? AnyShapeStyle(color.foreground(for: colorScheme))
                            : AnyShapeStyle(color.gradient(for: colorScheme)))
            .overlay(Circle().strokeBorder(Color.primary.opacity(onOwnFill ? 0 : 0.12), lineWidth: 0.5))
            .frame(width: size, height: size)
    }
}

private struct RadialChipView: View {
    let item: RadialMenuItem
    let nowPlayingState: RadialNowPlayingState
    let highlighted: Bool
    let animates: Bool
    let profileColor: RadialMenuColor
    /// Where on the ring this chip belongs, and when its turn comes in the
    /// opening sweep.
    let direction: (dx: CGFloat, dyUp: CGFloat)
    let openDelay: Double
    /// The wheel's own state. Chips fly out of the hub when it opens and fold
    /// back into it when it closes, so the wheel gathers itself up on the way
    /// out instead of simply going dark.
    let open: Bool
    @State private var settled = false

    var body: some View {
        RadialChipFace(item: item, nowPlayingState: nowPlayingState,
                       highlighted: highlighted, profileColor: profileColor)
            .scaleEffect(highlighted && animates ? 1.14 : 1)
            .animation(animates ? .spring(response: 0.24, dampingFraction: 0.72) : nil, value: highlighted)
            // The opening sweep rides outside the highlight's own animation, so
            // pointing at a chip mid-flight does not fight with its arrival.
            .scaleEffect(settled || !animates ? 1 : 0.35)
            .opacity(settled || !animates ? 1 : 0)
            .offset(x: direction.dx * reach, y: -direction.dyUp * reach)
            // A chip born into an open wheel is a submenu arriving, and draws
            // itself in the same sweep the wheel itself did.
            .onAppear { if open { bloom() } else { settled = false } }
            .onChange(of: open) { _, isOpen in
                if isOpen { bloom() } else { fold() }
            }
    }

    /// How far out the chip sits: folded into the hub to begin with, then out
    /// to its place on the ring.
    private var reach: CGFloat {
        settled || !animates ? RadialMenuLayout.ringRadius : RadialMenuLayout.deadZoneRadius * 0.2
    }

    private func bloom() {
        guard animates else {
            settled = true
            return
        }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.75).delay(openDelay)) {
            settled = true
        }
    }

    /// Folding in is tighter than opening out: what is being dismissed should
    /// not be waited for.
    private func fold() {
        guard animates else {
            settled = false
            return
        }
        withAnimation(.easeIn(duration: 0.1).delay(openDelay * 0.25)) {
            settled = false
        }
    }
}

/// The profile tabs on an arc above the wheel: curved pills that follow the
/// rim, a gradient dot per profile, the current one opened up to show its
/// name, the primary marked with a star. The angles go back to the service,
/// which hit-tests the pointer for clicks, release and the hold dwell.
private struct RadialTabArc: View {
    @ObservedObject var service: RadialMenuService
    let text: RadialMenuFeatureStrings
    let colorScheme: ColorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let nameFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)

    private struct Placed: Identifiable {
        let tab: RadialProfileTabs.VisibleTab
        let span: ClosedRange<Double>
        var id: Int { tab.index }
    }

    private func width(of tab: RadialProfileTabs.VisibleTab) -> CGFloat {
        // Collapsed: the primary's star or another profile's dot. Expanded:
        // the primary's star and the name, no dot.
        guard tab.index == service.activeProfileIndex else { return (tab.index == 0 ? 9 : 10) + 12 }
        let star: CGFloat = tab.index == 0 ? 14 : 0
        let name = fittedName(service.sessionProfiles[tab.index].displayName(text))
        let textWidth = name.reduce(CGFloat(0)) { $0 + ($1 as NSString).size(withAttributes: [.font: Self.nameFont]).width }
        return star + textWidth + 18
    }

    private var placed: [Placed] {
        let tabs = RadialProfileTabs.visibleTabs(count: service.sessionProfiles.count,
                                                 current: service.activeProfileIndex)
        let spans = RadialProfileTabs.arcSpans(widths: tabs.map(width(of:)),
                                               radius: RadialMenuLayout.tabArcRadius,
                                               capHeight: RadialMenuLayout.tabPillHeight,
                                               maxSpan: RadialMenuLayout.tabArcMaxSpan)
        return zip(tabs, spans).map { Placed(tab: $0, span: $1) }
    }

    var body: some View {
        let placed = placed
        ZStack {
            ForEach(placed) { item in band(item) }
            ForEach(placed) { item in label(item) }
        }
        .frame(width: service.panelSide, height: service.panelSide)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: service.activeProfileIndex)
        .onAppear { report(placed) }
        .onChange(of: placed.map(\.span)) { _, _ in report(placed) }
        // Spans can match across a switch while the profiles under them move.
        .onChange(of: service.activeProfileIndex) { _, _ in report(placed) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(text.profilesHeader)
    }

    private func report(_ placed: [Placed]) {
        service.updateTabSpans(Dictionary(uniqueKeysWithValues: placed.map { ($0.tab.index, $0.span) }))
    }

    @ViewBuilder
    private func band(_ item: Placed) -> some View {
        let profile = service.sessionProfiles[item.tab.index]
        let current = item.tab.index == service.activeProfileIndex
        let hovered = item.tab.index == service.hoveredTabIndex && !current
        let pill = RadialArcPill(span: item.span, radius: RadialMenuLayout.tabArcRadius,
                                 thickness: RadialMenuLayout.tabPillHeight)
        ZStack {
            pill.fill(current ? AnyShapeStyle(profile.color.gradient(for: colorScheme))
                              : AnyShapeStyle(PanelSurface.raisedFill(for: colorScheme)))
            pill.stroke(hovered ? profile.color.color(for: colorScheme) : PanelSurface.raisedBorder(for: colorScheme),
                        lineWidth: hovered ? 1.5 : 0.8)
        }
        .shadow(color: PanelSurface.raisedShadow(for: colorScheme), radius: 4, y: 1)
        .opacity(item.tab.faded ? 0.4 : 1)
        .allowsHitTesting(false)
    }

    /// One piece of a tab's content set along the arc: the star, the dot or
    /// a single character of the name.
    private enum Glyph {
        case star, dot, character(String)
    }

    /// The name cut to fit the tab, with an ellipsis when it had to be, as
    /// the pieces set along the arc: one per character, or the whole name
    /// as one piece in a script that joins or reorders its letters.
    private func fittedName(_ name: String) -> [String] {
        let characters = name.map(String.init)
        func width(_ parts: [String]) -> CGFloat {
            (parts.joined() as NSString).size(withAttributes: [.font: Self.nameFont]).width
        }
        var kept = characters
        if width(characters) > 120 {
            while !kept.isEmpty, width(kept + ["…"]) > 120 { kept.removeLast() }
            kept.append("…")
        }
        return Self.needsShaping(name) ? [kept.joined()] : kept
    }

    /// Arabic, Hebrew, the Indic scripts and their kin shape letters by their
    /// neighbours and may run right to left, so set one at a time they
    /// come apart; such a name is drawn as one run, turned at its centre.
    static func needsShaping(_ name: String) -> Bool {
        name.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0590...0x08FF, 0x0900...0x0DFF, 0x0F00...0x109F, 0x1780...0x18AF,
                 0xA800...0xABFF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF, 0x10800...0x10FFF, 0x11000...0x11FFF:
                return true
            default:
                return false
            }
        }
    }

    private func glyphWidth(_ glyph: Glyph, dotSize: CGFloat) -> CGFloat {
        switch glyph {
        case .star: return 9
        case .dot: return dotSize
        case .character(let character):
            return (character as NSString).size(withAttributes: [.font: Self.nameFont]).width
        }
    }

    /// Lays the content out along the band's centre line, each piece turned
    /// to the arc where it sits, so the text bends with the pill.
    private func label(_ item: Placed) -> some View {
        let profile = service.sessionProfiles[item.tab.index]
        let current = item.tab.index == service.activeProfileIndex
        let middle = (item.span.lowerBound + item.span.upperBound) / 2
        let radius = RadialMenuLayout.tabArcRadius
        let name = profile.displayName(text)
        let dotSize: CGFloat = current ? 7 : 10
        var glyphs: [Glyph] = []
        if item.tab.index == 0 { glyphs.append(.star) } else if !current { glyphs.append(.dot) }
        if current { glyphs += fittedName(name).map(Glyph.character) }
        let gaps: [CGFloat] = glyphs.indices.map { index in
            guard index + 1 < glyphs.count else { return 0 }
            if case .character = glyphs[index], case .character = glyphs[index + 1] { return 0 }
            return 5
        }
        let widths = glyphs.map { glyphWidth($0, dotSize: dotSize) }
        let total = widths.reduce(0, +) + gaps.reduce(0, +)
        var run = -total / 2
        var placements: [(Glyph, Double)] = []
        for (index, glyph) in glyphs.enumerated() {
            placements.append((glyph, middle + Double((run + widths[index] / 2) / radius)))
            run += widths[index] + gaps[index]
        }
        let foreground = current ? AnyShapeStyle(profile.color.foreground(for: colorScheme))
                                 : AnyShapeStyle(profile.color.color(for: colorScheme))
        return ZStack {
            ForEach(Array(placements.enumerated()), id: \.offset) { _, placement in
                Group {
                    switch placement.0 {
                    case .star:
                        Image(systemName: "star.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(foreground)
                    case .dot:
                        RadialProfileDot(color: profile.color, size: dotSize, onOwnFill: current)
                    case .character(let character):
                        Text(character)
                            .font(Font(Self.nameFont))
                            .foregroundStyle(profile.color.foreground(for: colorScheme))
                    }
                }
                .fixedSize()
                .rotationEffect(.radians(placement.1))
                .offset(x: radius * CGFloat(sin(placement.1)), y: -radius * CGFloat(cos(placement.1)))
            }
        }
        .opacity(item.tab.faded ? 0.4 : 1)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityAddTraits(current ? [.isButton, .isSelected] : .isButton)
        .accessibilityValue(item.tab.index == 0 ? text.primaryHelp : "")
        .accessibilityAction { service.switchProfile(to: item.tab.index) }
    }
}

/// A pill bent to the wheel's rim: the outline of the tab band's centre
/// arc stroked with round caps, so it can be filled and outlined like any
/// other shape.
private struct RadialArcPill: Shape {
    let span: ClosedRange<Double>
    let radius: CGFloat
    let thickness: CGFloat

    func path(in rect: CGRect) -> Path {
        var arc = Path()
        arc.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: radius,
                   startAngle: .radians(span.lowerBound - .pi / 2),
                   endAngle: .radians(span.upperBound - .pi / 2), clockwise: false)
        return arc.strokedPath(StrokeStyle(lineWidth: thickness, lineCap: .round))
    }
}

/// A slice-shaped highlight between the hub and the wheel border.
struct RadialWedgeShape: Shape {
    var centerAngle: Double
    var sliceAngle: Double
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    /// The angle and the width are what move, so the highlight sweeps to the
    /// slice under the pointer, and re-fits when a submenu holds a different
    /// number of them.
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(centerAngle, sliceAngle) }
        set {
            centerAngle = newValue.first
            sliceAngle = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // Screen angles: 0 at +x, growing clockwise (flipped y); our slice
        // angles run clockwise from 12 o'clock, so shift by a quarter turn.
        let start = Angle(radians: centerAngle - sliceAngle / 2 - .pi / 2)
        let end = Angle(radians: centerAngle + sliceAngle / 2 - .pi / 2)
        var path = Path()
        path.addArc(center: center, radius: innerRadius, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: outerRadius, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}

/// Real icons and display names for slices that point at the disk, cached so
/// the wheel never touches the file system while the pointer is tracked (a
/// dead network mount would otherwise stall every highlight change).
/// Configurations are tiny (a wheel holds 12 items), so entries accumulate.
enum RadialMenuIconStore {
    private static var icons: [String: NSImage] = [:]
    private static var names: [String: String] = [:]
    /// Keyed by the action and checked against its data, so an editor's
    /// draft icon never stands in for the saved action's own.
    private static var customIcons: [UUID: (data: Data, image: NSImage)] = [:]

    static func fileIcon(for payload: String) -> NSImage {
        if let cached = icons[payload] { return cached }
        let path = (payload as NSString).expandingTildeInPath
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 34, height: 34)
        icons[payload] = icon
        return icon
    }

    static func customIcon(for item: RadialMenuItem) -> NSImage? {
        guard let data = item.customIconData else { return nil }
        if let cached = customIcons[item.id], cached.data == data { return cached.image }
        guard let image = NSImage(data: data) else { return nil }
        image.size = NSSize(width: 34, height: 34)
        customIcons[item.id] = (data, image)
        return image
    }

    static func fileName(for payload: String) -> String {
        if let cached = names[payload] { return cached }
        let path = (payload as NSString).expandingTildeInPath
        let name = FileManager.default.displayName(atPath: path)
        names[payload] = name
        return name
    }

    static func invalidate(_ payload: String) {
        icons.removeValue(forKey: payload)
        names.removeValue(forKey: payload)
    }

    static func invalidate(item: RadialMenuItem) {
        icons.removeValue(forKey: item.payload)
        names.removeValue(forKey: item.payload)
        customIcons.removeValue(forKey: item.id)
    }
}

/// Name resolution shared by the wheel and the Settings editor: a custom name
/// wins, everything else derives from the target in the user's language.
extension RadialMenuItem {
    /// `stableToggles` names a state-dependent quick toggle by what it does
    /// ("Toggle System Appearance") rather than by what it would do right now,
    /// for Settings, where the state of the moment means nothing.
    func displayName(_ text: RadialMenuFeatureStrings,
                     nowPlayingState: RadialNowPlayingState? = nil,
                     stableToggles: Bool = false) -> String {
        if !name.isEmpty { return name }
        if stableToggles, kind == .quickToggle, let quickToggle { return quickToggle.settingsTitle(text) }
        switch kind {
        case .app, .file:
            // Nothing chosen yet: an empty path would name the working folder.
            guard !payload.isEmpty else { return kind == .app ? text.kindApp : text.kindFile }
            return RadialMenuIconStore.fileName(for: payload)
        case .url:
            let normalized = RadialMenuSupport.normalizedURL(payload) ?? payload
            return URL(string: normalized)?.host ?? payload
        case .shortcut:
            return GlobalShortcut(storageValue: payload)?.displayString ?? text.kindShortcut
        case .tool:
            guard let tool else { return text.kindTool }
            return tool.feature.hubTitle(L10n.shared.s, hub: FeatureStrings.hub(L10n.shared.language))
        case .quickToggle:
            return quickToggle?.radialTitle ?? FeatureStrings.quickToggles(L10n.shared.language).pageTitle
        case .windowLayout:
            guard let windowLayoutAction else {
                return FeatureStrings.windowLayout(L10n.shared.language).title
            }
            return windowLayoutAction.radialTitle(text)
        case .media:
            switch mediaKey {
            case .playPause: return text.mediaPlayPause
            case .previousTrack: return text.mediaPrevious
            case .nextTrack: return text.mediaNext
            case .nowPlaying:
                switch nowPlayingState {
                case let .some(.playing(snapshot)): return snapshot.radialLabel ?? text.mediaNowPlaying
                case .some(.nothingPlaying): return text.mediaNothingPlaying
                case .some(.loading), .none: return text.mediaNowPlaying
                }
            case nil: return text.kindMedia
            }
        case .submenu:
            return text.kindSubmenu
        }
    }

    /// Only once something is chosen: an empty path draws a blank document.
    var usesFileIcon: Bool {
        (kind == .app || kind == .file) && symbolName.isEmpty && !payload.isEmpty
    }
}

extension WindowLayoutAction {
    /// The window layout's own title, minus the "window" the wheel already
    /// implies for the two display moves.
    func radialTitle(_ text: RadialMenuFeatureStrings) -> String {
        switch self {
        case .nextDisplay: return text.moveToNextDisplay
        case .previousDisplay: return text.moveToPreviousDisplay
        default: return title(FeatureStrings.windowLayout(L10n.shared.language))
        }
    }
}

extension RadialMenuQuickToggle {
    /// A name that does not change with the system's state.
    func settingsTitle(_ text: RadialMenuFeatureStrings) -> String {
        stableTitle(text) ?? radialTitle
    }

    var radialTitle: String {
        let strings = FeatureStrings.quickToggles(L10n.shared.language)
        let toggles = QuickTogglesService.shared
        switch self {
        case .darkMode:
            return toggles.systemAppearanceIsDark == true ? strings.darkModeToLight : strings.darkModeToDark
        case .emptyTrash: return strings.emptyTrashTitle
        case .ejectDisks: return strings.ejectTitle
        case .hiddenFiles: return toggles.hiddenFilesShown ? strings.hiddenFilesHide : strings.hiddenFilesShow
        case .desktopIcons: return toggles.desktopIconsShown ? strings.desktopIconsHide : strings.desktopIconsShow
        case .lockScreen: return strings.lockScreenTitle
        case .displayOff: return strings.displayOffTitle
        case .screenSaver: return strings.screenSaverTitle
        }
    }
}
