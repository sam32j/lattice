// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// Only the transition owns animation state. No timer or display link survives
/// the reveal, and a reversed transition cannot enable a departing button.
final class NotchQuickAccessMotion: ObservableObject {
    @Published private(set) var progress: CGFloat = 0
    @Published private(set) var interactive = false
    @Published private(set) var configuration = NotchQuickAccessConfiguration(side: .left, actions: [.explore])
    @Published private(set) var placements: [NotchQuickAccessPlacement] = []
    private var bodyFrame = CGRect.zero
    private var visible = false
    private var generation = 0

    func configure(_ configuration: NotchQuickAccessConfiguration, body: CGRect, headerTop: CGFloat, animated: Bool) {
        let values = NotchQuickAccessLayout.placements(configuration, body: body, headerTop: headerTop)
        guard self.configuration != configuration || placements != values else { return }
        let spring = NotchMotion.sideSpring(from: bodyFrame.size, to: body.size)
        let animation: Animation? = animated && visible ? .spring(duration: spring.duration, bounce: spring.bounce) : nil
        bodyFrame = body
        withAnimation(animation) {
            self.configuration = configuration
            placements = values
        }
    }

    var hoverRects: [CGRect] {
        NotchQuickAccessSide.allCases.compactMap { side in
            let values = placements.filter { $0.side == side }
            guard let first = values.first else { return nil }
            return NotchQuickAccessLayout.hoverRect(count: values.count, edge: first.edge, top: first.top, side: side)
        }
    }

    func setVisible(_ visible: Bool, animated: Bool, delay: TimeInterval = 0) {
        guard self.visible != visible else { return }
        self.visible = visible
        generation += 1
        let token = generation
        interactive = false
        let animation: Animation? = animated
            ? (visible ? .spring(duration: 0.38, bounce: 0.12).delay(delay) : .easeIn(duration: NotchQuickAccessLayout.withdrawalDuration))
            : nil
        withAnimation(animation, completionCriteria: .logicallyComplete) {
            progress = visible ? 1 : 0
        } completion: { [weak self] in
            guard let self, self.generation == token else { return }
            self.interactive = visible
        }
    }

    func contains(_ point: CGPoint) -> Bool {
        interactive && placements.contains { value in
            let center = value.center(progress: 1)
            if hypot(point.x - center.x, point.y - center.y) <= NotchQuickAccessLayout.diameter / 2 {
                return true
            }
            // During live editing the 18pt red remove badge protrudes 7pt
            // beyond the original circle. Native NSPanel hit-testing must
            // include the complete badge, not just the button's center.
            guard NotchService.shared.expanded, NotchService.shared.selected == .hub,
                  LatticeHubService.shared.isEditing,
                  NotchQuickAccessEditing.placeholderSide(for: value.button.id) == nil else { return false }
            let badge = CGPoint(x: center.x + NotchQuickAccessLayout.diameter / 2 + 7 - 9,
                                y: center.y - NotchQuickAccessLayout.diameter / 2 - 7 + 9)
            return hypot(point.x - badge.x, point.y - badge.y) <= 9
        }
    }
}

struct NotchQuickAccessView: View {
    @ObservedObject var service: NotchService
    @ObservedObject var motion: NotchQuickAccessMotion
    /// Only the glass surface below follows it; it changes every frame of a resize.
    let backdrop: NotchBackdropPresentation
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @ObservedObject private var microphone = MicMuteService.shared
    @ObservedObject private var recorder = ScreenRecorderService.shared
    @ObservedObject private var launcher = LatticeHubService.shared
    @State private var editingPopoverID: UUID?
    @State private var draggedButtonID: UUID?
    @State private var dragTranslation: CGSize = .zero
    private let glass = LiquidGlassSupport.isSupported
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    /// Increase Contrast keeps the buttons solid beside a lip that barely opens.
    private var followsGlass: Bool {
#if compiler(>=6.2)
        if #available(macOS 26, *) { return glass && !reduceTransparency && contrast != .increased }
#endif
        return false
    }

    var body: some View {
        let drops = NotchQuickAccessDrops(placements: motion.placements, progress: motion.progress)
        let buttons = ZStack(alignment: .topLeading) {
            ForEach(motion.placements) { placement in
                Group {
                    if liveEditing {
                        editingBubble(placement)
                    } else {
                        bubble(placement.button)
                    }
                }
                .scaleEffect(0.4 + 0.6 * motion.progress)
                .opacity(Double(motion.progress))
                .position(placement.center(progress: motion.progress))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .coordinateSpace(name: "liveQuickAccessStage")
        Group {
            if followsGlass {
                buttons.modifier(NotchQuickAccessGlassSurface(presentation: backdrop, drops: drops))
            } else {
                buttons.background { drops }
            }
        }
        .environment(\.colorScheme, .dark)
        .environment(\.notchPresentation, true)
        .foregroundStyle(.white)
        .tint(.white)
        .allowsHitTesting(motion.interactive)
        .accessibilityHidden(!motion.interactive)
    }

    private var liveEditing: Bool {
        launcher.isEditing && service.expanded && service.selected == .hub
    }

    @ViewBuilder
    private func editingBubble(_ placement: NotchQuickAccessPlacement) -> some View {
        let button = placement.button
        let isSlot = NotchQuickAccessEditing.placeholderSide(for: button.id) != nil
        ZStack(alignment: .topTrailing) {
            Button { editingPopoverID = button.id } label: {
                Image(systemName: isSlot ? "plus" : (button.action?.symbol ?? "questionmark"))
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: NotchQuickAccessLayout.diameter, height: NotchQuickAccessLayout.diameter)
                    .background(Color.black, in: Circle())
                    .overlay {
                        Circle().strokeBorder(isSlot ? Color.accentColor : Color.white.opacity(0.35),
                                              style: StrokeStyle(lineWidth: 1.5,
                                                                 dash: isSlot ? [4, 4] : []))
                    }
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSlot
                ? "\(FeatureStrings.notchEditor(l10n.language).addButton) · \(sideName(button.side))"
                : "\(FeatureStrings.notchEditor(l10n.language).editButton) · \(button.action?.title(l10n) ?? button.label)")
            .popover(isPresented: Binding(
                get: { editingPopoverID == button.id },
                set: { if !$0 { editingPopoverID = nil } }
            )) {
                NotchQuickActionPicker(selected: isSlot ? nil : button.action) { action in
                    var configuration = NotchQuickAccessConfiguration.stored()
                    if let side = NotchQuickAccessEditing.placeholderSide(for: button.id) {
                        guard configuration.hasRoom(on: side) else { return }
                        configuration.buttons.append(NotchQuickButton(action: action, side: side))
                    } else if let index = configuration.buttons.firstIndex(where: { $0.id == button.id }) {
                        configuration.buttons[index].actionID = action.id
                    }
                    saveEditingConfiguration(configuration)
                    editingPopoverID = nil
                }
            }
            if !isSlot {
                Button {
                    var configuration = NotchQuickAccessConfiguration.stored()
                    configuration.buttons.removeAll { $0.id == button.id }
                    saveEditingConfiguration(configuration)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.white)
                        .background(.red, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(FeatureStrings.notchEditor(l10n.language).removeButton) · \(button.action?.title(l10n) ?? button.label)")
                .offset(x: 7, y: -7)
            }
        }
        .offset(draggedButtonID == button.id ? dragTranslation : .zero)
        .highPriorityGesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named("liveQuickAccessStage"))
                .onChanged { value in
                    guard !isSlot else { return }
                    editingPopoverID = nil
                    draggedButtonID = button.id
                    dragTranslation = value.translation
                }
                .onEnded { value in
                    if !isSlot { moveEditingButton(button, to: value.location) }
                    draggedButtonID = nil
                    dragTranslation = .zero
                }
        )
        .accessibilityIdentifier(isSlot ? "notch.quickAccess.add.\(button.side.rawValue)" : "notch.quickAccess.edit.\(button.id.uuidString)")
    }

    private func sideName(_ side: NotchQuickAccessSide) -> String {
        let strings = FeatureStrings.notchMascot(l10n.language)
        switch side {
        case .left: return strings.left
        case .right: return strings.right
        case .bottom: return FeatureStrings.notchEditor(l10n.language).bottom
        }
    }

    private func moveEditingButton(_ button: NotchQuickButton, to point: CGPoint) {
        guard let target = motion.placements
            .filter({ $0.button.id != button.id })
            .min(by: {
                let first = $0.center(progress: 1), second = $1.center(progress: 1)
                return hypot(first.x - point.x, first.y - point.y) < hypot(second.x - point.x, second.y - point.y)
            }) else { return }
        let targetPoint = target.center(progress: 1)
        guard hypot(targetPoint.x - point.x, targetPoint.y - point.y) <= 75 else { return }
        var configuration = NotchQuickAccessConfiguration.stored()
        let targetIsSlot = NotchQuickAccessEditing.placeholderSide(for: target.button.id) != nil
        let isAfter: Bool = {
            switch target.side {
            case .bottom: return point.x > targetPoint.x
            case .left, .right: return point.y > targetPoint.y
            }
        }()
        let sideButtons = configuration.buttons.filter { $0.side == target.side && $0.id != button.id }
        let targetIndex = sideButtons.firstIndex { $0.id == target.button.id }
        let before: UUID? = {
            guard !targetIsSlot, let targetIndex else { return nil }
            if isAfter {
                let next = sideButtons.index(after: targetIndex)
                return next < sideButtons.endIndex ? sideButtons[next].id : nil
            }
            return target.button.id
        }()
        configuration.move(button.id, to: target.side, before: before)
        saveEditingConfiguration(configuration)
    }

    private func saveEditingConfiguration(_ configuration: NotchQuickAccessConfiguration) {
        UserDefaults.standard.set(configuration.sanitized().encoded, forKey: DefaultsKey.notchQuickAccessLayout)
        service.refreshPresentation(animated: false)
    }

    private func bubble(_ button: NotchQuickButton) -> some View {
        let action = button.action ?? .explore
        let selected: Bool = {
            if action == .explore { return service.selected == .hub }
            if action == .pin { return service.pinned }
            if action == .control(.keepAwake) { return awake.isActive }
            if action == .control(.microphone) { return microphone.isMuted }
            if action == .control(.recording) { return recorder.isRecording }
            if case .module(let module) = action {
                return service.selected == module
            }
            return false
        }()
        var actionTitle = action.title(l10n)
        var symbol = action.symbol
        switch action {
        case .explore: symbol = "house"
        case .pin:
            actionTitle = service.pinned ? FeatureStrings.notch(l10n.language).unpin : FeatureStrings.notch(l10n.language).pin
            if service.pinned { symbol = "pin.fill" }
        case .control(.microphone):
            actionTitle = microphone.isMuted ? l10n.s.micUnmuteName : l10n.s.micMuteName
            if microphone.isMuted { symbol = "mic.slash.fill" }
        case .control(.keepAwake) where awake.isActive: symbol = "bolt.fill"
        case .control(.recording) where recorder.isRecording: symbol = "stop.circle.fill"
        default: break
        }
        let title = button.label.isEmpty ? actionTitle : button.label
        return Button {
            service.activateQuickAction(action)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .frame(width: NotchQuickAccessLayout.diameter, height: NotchQuickAccessLayout.diameter)
                // In glass the drop beneath carries the island's shade, which
                // the window server does not count as the window's own pixels:
                // a faint fill keeps the whole circle from passing clicks to
                // the app behind, not just the glyph.
                .background(followsGlass ? Color.black.opacity(0.02) : Color.black, in: Circle())
                .overlay {
                    Circle().strokeBorder(.white.opacity(selected || contrast == .increased ? 0.6 : 0.16), lineWidth: 0.75)
                        .allowsHitTesting(false)
                }
                .contentShape(Circle())
        }
        .buttonStyle(NotchButtonStyle(cornerRadius: NotchQuickAccessLayout.diameter / 2))
        .help(title)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("notch.quickAccess.\(button.id.uuidString)")
    }
}

/// Every button's drop, in the coordinates of the whole floating layer.
private struct NotchQuickAccessDrops: View {
    let placements: [NotchQuickAccessPlacement]
    let progress: CGFloat

    var body: some View {
        ZStack {
            ForEach(placements) { placement in
                NotchQuickAccessDrop(progress: progress, index: placement.index, edge: placement.edge,
                                     top: placement.top, side: placement.side)
                    .fill(.black)
            }
        }
        .allowsHitTesting(false)
    }
}

/// On glass each drop takes the island's shade at its own height, so it
/// leaves the island without a seam and buttons below the island are as
/// translucent as its lip. The island no longer hides what lies beneath its
/// edge, so a drop still inside it is cut away.
private struct NotchQuickAccessGlassSurface: ViewModifier {
    @ObservedObject var presentation: NotchBackdropPresentation
    let drops: NotchQuickAccessDrops
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let island = presentation.usesGlass ? presentation.contour : Path()
        content
            .background {
                if presentation.usesGlass {
                    GeometryReader { proxy in
                        // Past the island the shade keeps the lip's tone,
                        // measured from the top edge as the island's own.
                        LinearGradient(stops: NotchSurfaceBackground.shade(openness: presentation.openness, contrast: contrast),
                                       startPoint: .top,
                                       endPoint: UnitPoint(x: 0.5, y: (island.isEmpty ? 0 : island.boundingRect.maxY)
                                                            / max(1, proxy.size.height)))
                            .mask { drops }
                    }
                } else {
                    drops
                }
            }
            .clipShape(NotchQuickAccessOutside(island: island), style: FillStyle(eoFill: true))
    }
}

/// The floating layer except the island, centered between equal gutters.
private struct NotchQuickAccessOutside: Shape {
    let island: Path

    func path(in rect: CGRect) -> Path {
        let safeRect = CGRect(x: rect.minX.isFinite ? rect.minX : 0,
                              y: rect.minY.isFinite ? rect.minY : 0,
                              width: max(0, rect.width.isFinite ? rect.width : 0),
                              height: max(0, rect.height.isFinite ? rect.height : 0))
        var path = Path(safeRect)
        let bbox = island.boundingRect
        guard !island.isEmpty, !bbox.isNull, bbox.origin.x.isFinite else { return path }
        path.addPath(island, transform: CGAffineTransform(translationX: safeRect.midX - bbox.midX, y: 0))
        return path
    }
}

struct NotchQuickAccessDrop: Shape {
    var progress: CGFloat
    let index: Int
    var edge: CGFloat
    var top: CGFloat
    let side: NotchQuickAccessSide
    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(progress, AnimatablePair(edge, top)) }
        set { progress = newValue.first; edge = newValue.second.first; top = newValue.second.second }
    }

    func path(in rect: CGRect) -> Path {
        let safeRect = CGRect(x: rect.minX.isFinite ? rect.minX : 0,
                              y: rect.minY.isFinite ? rect.minY : 0,
                              width: max(0, rect.width.isFinite ? rect.width : 0),
                              height: max(0, rect.height.isFinite ? rect.height : 0))
        let zeroPath = Path(CGRect(x: safeRect.minX, y: safeRect.minY, width: 0, height: 0))
        let phase = min(1.1, max(0, progress))
        guard phase > 0.001, safeRect.width > 0, safeRect.height > 0 else { return zeroPath }
        let anchor = side == .bottom ? safeRect.height - edge : side == .left ? edge : safeRect.width - edge
        let center = NotchQuickAccessLayout.center(index: index, progress: phase, edge: anchor, top: top, side: .left)
        let radius = NotchQuickAccessLayout.diameter / 2 * (0.4 + 0.6 * phase)
        var path = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        // The narrow connection dissolves before the circle finishes moving.
        // Its other end sits under the notch, so there is no visible seam.
        let neck = radius * max(0, 1 - phase / 0.84)
        if neck > 0, center.x + radius < anchor {
            path.move(to: CGPoint(x: anchor + 2, y: center.y + neck))
            path.addCurve(to: CGPoint(x: center.x + radius * 0.55, y: center.y + neck * 0.75),
                          control1: CGPoint(x: anchor - 7, y: center.y + neck),
                          control2: CGPoint(x: center.x + radius, y: center.y + neck * 0.15))
            path.addLine(to: CGPoint(x: center.x + radius * 0.55, y: center.y - neck * 0.75))
            path.addCurve(to: CGPoint(x: anchor + 2, y: center.y - neck),
                          control1: CGPoint(x: center.x + radius, y: center.y - neck * 0.15),
                          control2: CGPoint(x: anchor - 7, y: center.y - neck))
            path.closeSubpath()
        }
        if side == .bottom { return path.applying(CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: safeRect.height)) }
        if side == .right { return path.applying(CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: safeRect.width, ty: 0)) }
        return path
    }
}

extension NotchQuickAction {
    var symbol: String {
        switch self {
        case .explore: return "house"
        case .settings: return "gearshape"
        case .pin: return "pin"
        case .module(let module): return module.symbol
        case .control(let item): return item.symbol
        }
    }

    func title(_ l10n: L10n) -> String {
        switch self {
        case .explore: return SettingsFollowupStrings.text(.allTools, l10n.language)
        case .settings: return l10n.s.menuSettings
        case .pin: return FeatureStrings.notch(l10n.language).pin
        case .module(let module): return module.title(l10n.language)
        case .control(let item): return item.title(l10n)
        }
    }
}
