// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

/// The wheel in the Settings editor, drawn with the live menu's own disc,
/// chips and wedge so it previews the menu in either appearance. The only
/// place actions are added, edited, moved and removed: click a slot to edit
/// it, drag it onto another to swap, right-click for more. Actions sit where
/// the live menu puts them; hovering or focusing Add action makes room on the
/// wheel and shows a dashed slot where the new one lands. Every slot is a
/// focusable button: arrows move round the wheel, Return or Space edits,
/// Option-arrow moves the action, Delete removes it.
struct RadialMenuVisualCanvas: View {
    let items: [RadialMenuItem]
    let profileColor: RadialMenuColor
    let text: RadialMenuFeatureStrings
    let isSubmenu: Bool
    let onEdit: (RadialMenuItem) -> Void
    let onSwap: (RadialMenuItem, RadialMenuItem) -> Void
    let onMove: (RadialMenuItem, Int) -> Void
    let onRemove: (RadialMenuItem) -> Void
    let onOpenSubmenu: (RadialMenuItem) -> Void
    let onBack: () -> Void
    let onAdd: () -> Void

    private enum Slot: Hashable {
        case item(UUID)
        case add
    }

    @State private var hoveredIndex: Int?
    @State private var draggingIndex: Int?
    @State private var dragPosition: CGPoint = .zero
    @State private var targetIndex: Int?
    @State private var addHovered = false
    @State private var ghostHovered = false
    @FocusState private var focusedSlot: Slot?

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let wheelDiameter: CGFloat = 264
    static let ringRadius: CGFloat = 98
    static let chipSize: CGFloat = 46
    static let hubDiameter: CGFloat = 68
    static let deadZoneRadius: CGFloat = 36

    private var canAdd: Bool { items.count < RadialMenuSupport.maxItemsPerWheel }

    /// Only while Add action is pointed at or focused does the wheel lay out
    /// as if the new action were there; otherwise it matches the live menu.
    private var showsAddSlot: Bool {
        canAdd && !items.isEmpty && (addHovered || ghostHovered || focusedSlot == .add)
    }

    private var slotCount: Int { items.count + (showsAddSlot ? 1 : 0) }

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            ZStack {
                RadialWheelDisc(diameter: Self.wheelDiameter, sliceCount: slotCount,
                                deadZoneRadius: Self.deadZoneRadius)
                    .shadow(color: .black.opacity(colorScheme == .light ? 0.12 : 0.4), radius: 14, y: 5)
                wedgeHighlight
                chips(center: center)
                if showsAddSlot { addSlot }
                hub
                floatingDraggedChip
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .coordinateSpace(name: "RadialCanvas")
        }
        .overlay(alignment: .bottom) { bottomBar }
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.82), value: items.map(\.id))
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.82), value: showsAddSlot)
    }

    /// Add action on the leading side, the action count on the trailing one.
    private var bottomBar: some View {
        HStack {
            if canAdd && !items.isEmpty {
                Button(action: onAdd) {
                    Label(text.addButton, systemImage: "plus")
                        .font(.callout)
                }
                .buttonStyle(.borderless)
                .onHover { addHovered = $0 }
                .focused($focusedSlot, equals: .add)
                .onKeyPress(phases: .down) { press in
                    switch press.key {
                    case .leftArrow, .upArrow: focus(items.count - 1); return .handled
                    case .rightArrow, .downArrow: focus(0); return .handled
                    default: return .ignored
                    }
                }
                .help(text.addButton)
            }
            Spacer()
            Text("\(items.count) / \(RadialMenuSupport.maxItemsPerWheel)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel(String(format: text.actionCountFormat, items.count,
                                           RadialMenuSupport.maxItemsPerWheel))
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Wedge

    @ViewBuilder
    private var wedgeHighlight: some View {
        let active = targetIndex ?? hoveredIndex
        if let active, slotCount > 0, items.indices.contains(active) {
            RadialWedgeShape(centerAngle: 2 * .pi * Double(active) / Double(slotCount),
                             sliceAngle: 2 * .pi / Double(slotCount),
                             innerRadius: Self.deadZoneRadius,
                             outerRadius: Self.wheelDiameter / 2 - 3)
                .fill(profileColor.gradient(for: colorScheme))
                .mask(RadialWedgeRamp(scheme: colorScheme, innerRadius: Self.deadZoneRadius,
                                      outerRadius: Self.wheelDiameter / 2,
                                      strength: targetIndex != nil ? 1.3 : 1))
                .frame(width: Self.wheelDiameter, height: Self.wheelDiameter)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Chips

    private func offset(for index: Int) -> CGSize {
        let unit = RadialMenuGeometry.unitPosition(index: index, itemCount: slotCount)
        return CGSize(width: unit.dx * Self.ringRadius, height: -unit.dyUp * Self.ringRadius)
    }

    @ViewBuilder
    private func chips(center: CGPoint) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            let isDragged = draggingIndex == index
            let isHovered = hoveredIndex == index
            let isFocused = focusedSlot == .item(item.id)
            RadialChipFace(item: item, nowPlayingState: .nothingPlaying,
                           highlighted: targetIndex == index || isHovered,
                           profileColor: profileColor, size: Self.chipSize)
                .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 2).padding(-3)
                    .opacity(isFocused ? 1 : 0))
                .opacity(isDragged ? 0.25 : 1)
                .scaleEffect(isHovered && !isDragged && !reduceMotion ? 1.08 : 1)
                .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.75), value: isHovered)
                .contentShape(Circle())
                .offset(offset(for: index))
                .onHover { inside in
                    guard draggingIndex == nil else { return }
                    if inside {
                        hoveredIndex = index
                    } else if hoveredIndex == index {
                        hoveredIndex = nil
                    }
                }
                .gesture(dragGesture(index: index, item: item, center: center))
                .contextMenu { contextMenu(for: item) }
                .focusable()
                .focusEffectDisabled()
                .focused($focusedSlot, equals: .item(item.id))
                .onKeyPress(phases: .down) { press in handleKey(press, on: index) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(format: text.slotAccessibilityFormat,
                                           item.displayName(text, stableToggles: true), kindLabel(for: item),
                                           index + 1, items.count))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onEdit(item) }
                .accessibilityActions {
                    Button(text.editActionButton) { onEdit(item) }
                    if items.count > 1 {
                        Button(text.moveEarlierButton) { onMove(item, -1) }
                        Button(text.moveLaterButton) { onMove(item, 1) }
                    }
                    if item.kind == .submenu {
                        Button(text.editActionsButton) { onOpenSubmenu(item) }
                    }
                    Button(text.deleteButton) { onRemove(item) }
                }
        }
    }

    private func dragGesture(index: Int, item: RadialMenuItem, center: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("RadialCanvas"))
            .onChanged { value in
                guard hypot(value.translation.width, value.translation.height) > 6 else { return }
                draggingIndex = index
                dragPosition = value.location
                let angle = RadialMenuGeometry.angle(dx: value.location.x - center.x,
                                                     dyUp: center.y - value.location.y)
                // The add slot is not a drop target.
                if let slot = RadialMenuGeometry.index(forAngle: angle, itemCount: slotCount),
                   items.indices.contains(slot) {
                    targetIndex = slot
                } else {
                    targetIndex = nil
                }
            }
            .onEnded { value in
                if hypot(value.translation.width, value.translation.height) <= 6 {
                    onEdit(item)
                } else if let from = draggingIndex, let to = targetIndex, from != to,
                          items.indices.contains(from), items.indices.contains(to) {
                    onSwap(items[from], items[to])
                }
                draggingIndex = nil
                targetIndex = nil
            }
    }

    @ViewBuilder
    private func contextMenu(for item: RadialMenuItem) -> some View {
        Button(text.editActionButton) { onEdit(item) }
        if item.kind == .submenu {
            Button(text.editActionsButton) { onOpenSubmenu(item) }
        }
        Divider()
        Button(text.deleteButton, role: .destructive) { onRemove(item) }
    }

    /// Arrows walk round the wheel (right and down clockwise), Option-arrow
    /// carries the action along, Return or Space edits, Delete removes.
    private func handleKey(_ press: KeyPress, on index: Int) -> KeyPress.Result {
        let item = items[index]
        let step: Int? = {
            switch press.key {
            case .rightArrow, .downArrow: return 1
            case .leftArrow, .upArrow: return -1
            default: return nil
            }
        }()
        if let step {
            if press.modifiers.contains(.option) {
                onMove(item, step)
                focusedSlot = .item(item.id)
            } else {
                focus(index + step)
            }
            return .handled
        }
        switch press.key {
        case .return, .space:
            onEdit(item)
            return .handled
        case .delete, .deleteForward:
            let neighbour = items.count > 1 ? items[(index + 1) % items.count].id : nil
            onRemove(item)
            focusedSlot = neighbour.map { .item($0) }
            return .handled
        default:
            return .ignored
        }
    }

    /// Walks the actions and then Add action, round and round.
    private func focus(_ position: Int) {
        let stops = items.count + (canAdd && !items.isEmpty ? 1 : 0)
        guard stops > 0 else { return }
        let wrapped = ((position % stops) + stops) % stops
        focusedSlot = items.indices.contains(wrapped) ? .item(items[wrapped].id) : .add
    }

    // MARK: - Add slot

    /// The dashed slot that previews where a new action lands. Clicking it
    /// adds there too; keyboard users reach the same through Add action.
    private var addSlot: some View {
        Button(action: onAdd) {
            ZStack {
                Circle()
                    .strokeBorder(profileColor.color(for: colorScheme).opacity(0.7),
                                  style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .background(Circle().fill(Color.primary.opacity(0.03)))
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(profileColor.color(for: colorScheme))
            }
            .frame(width: Self.chipSize, height: Self.chipSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .offset(offset(for: items.count))
        .onHover { ghostHovered = $0 }
        .transition(.opacity.combined(with: .scale(scale: 0.6)))
        .help(text.addButton)
        .accessibilityHidden(true)
    }

    // MARK: - Hub

    private var hub: some View {
        ZStack {
            Circle()
                .fill(Color.primary.opacity(colorScheme == .light ? 0.045 : 0.075))
            hubContent
        }
        .frame(width: Self.hubDiameter, height: Self.hubDiameter)
        .contentShape(Circle())
        .onTapGesture {
            if isSubmenu {
                onBack()
            } else if items.isEmpty {
                onAdd()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isSubmenu ? text.backButton : (items.isEmpty ? text.addButton : ""))
        .accessibilityAddTraits(isSubmenu || items.isEmpty ? .isButton : [])
        .accessibilityHidden(!isSubmenu && !items.isEmpty)
        .accessibilityAction { if isSubmenu { onBack() } else if items.isEmpty { onAdd() } }
    }

    @ViewBuilder
    private var hubContent: some View {
        if let target = targetIndex, items.indices.contains(target) {
            VStack(spacing: 2) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(profileColor.color(for: colorScheme))
                Text(items[target].displayName(text, stableToggles: true))
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 4)
        } else if let index = hoveredIndex, items.indices.contains(index) {
            let item = items[index]
            VStack(spacing: 1) {
                Text(item.displayName(text, stableToggles: true))
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(kindLabel(for: item))
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 6)
        } else if isSubmenu {
            VStack(spacing: 3) {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(profileColor.color(for: colorScheme))
                Text(text.backButton)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else if items.isEmpty {
            VStack(spacing: 3) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(profileColor.color(for: colorScheme))
                Text(text.addButton)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 6)
        } else {
            BrandMark(width: 28, tint: Color.primary)
        }
    }

    // MARK: - Dragged chip

    @ViewBuilder
    private var floatingDraggedChip: some View {
        if let dragIdx = draggingIndex, items.indices.contains(dragIdx) {
            RadialChipFace(item: items[dragIdx], nowPlayingState: .nothingPlaying,
                           highlighted: true, profileColor: profileColor, size: Self.chipSize)
                .scaleEffect(1.15)
                .position(dragPosition)
                .allowsHitTesting(false)
        }
    }

    private func kindLabel(for item: RadialMenuItem) -> String {
        switch item.kind {
        case .app: return text.kindApp
        case .file: return text.kindFile
        case .url: return text.kindURL
        case .shortcut: return text.kindShortcut
        case .tool: return text.kindTool
        case .quickToggle: return FeatureStrings.quickToggles(L10n.shared.language).pageTitle
        case .windowLayout: return FeatureStrings.windowLayout(L10n.shared.language).title
        case .media: return text.kindMedia
        case .submenu: return text.kindSubmenu
        }
    }
}
