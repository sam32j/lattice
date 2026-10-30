// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct IslandDashedOutlineShape: Shape {
    var radius: CGFloat = 36

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                    radius: radius, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                    radius: radius, startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

struct NotchLiveQuickActionsEditorView: View {
    let screenSize: CGSize
    let onDone: () -> Void
    var onPopoverChange: (Bool) -> Void = { _ in }
    @ObservedObject private var l10n = L10n.shared

    @State private var configuration = NotchQuickAccessConfiguration.stored()
    @State private var addingSide: NotchQuickAccessSide?
    @State private var editingButtonID: UUID?
    @State private var draggingID: UUID?
    @State private var dragTranslation: CGSize = .zero
    @State private var dragLocation: CGPoint = .zero

    private let islandWidth: CGFloat = 420
    private let islandHeight: CGFloat = 130
    private let outlineMargin: CGFloat = 10

    var body: some View {
        let islandRect = CGRect(x: (screenSize.width - islandWidth) / 2, y: 0, width: islandWidth, height: islandHeight)
        let outlineRect = CGRect(x: islandRect.minX - outlineMargin, y: 0,
                                 width: islandWidth + outlineMargin * 2, height: islandHeight + outlineMargin)

        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .contentShape(Rectangle())

            if draggingID != nil {
                ForEach(NotchQuickAccessSide.allCases, id: \.self) { side in
                    let rect = dropRect(side, island: islandRect)
                    let isTarget = rect.contains(dragLocation)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.accentColor.opacity(isTarget ? 0.18 : 0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color.accentColor.opacity(isTarget ? 0.7 : 0.25),
                                              style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        }
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
            }

            IslandDashedOutlineShape(radius: 36)
                .stroke(Color.accentColor.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: outlineRect.width, height: outlineRect.height)
                .position(x: outlineRect.midX, y: outlineRect.midY)

            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 28, bottomTrailingRadius: 28, topTrailingRadius: 0)
                .fill(Color.black)
                .frame(width: islandRect.width, height: islandRect.height)
                .position(x: islandRect.midX, y: islandRect.midY)
                .overlay {
                    VStack(spacing: 14) {
                        Text(NotchQuickActionsCopy.instructions(l10n.language))
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Button(action: onDone) {
                            Text(l10n.s.doneButton)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 7)
                                .background(Color.accentColor, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: islandRect.width, height: islandRect.height, alignment: .center)
                    .position(x: islandRect.midX, y: islandRect.midY + 4)
                }

            ForEach(NotchQuickAccessSide.allCases, id: \.self) { side in
                let buttons = configuration.buttons.filter { $0.side == side }
                let hasRoom = configuration.hasRoom(on: side)
                let totalSlots = buttons.count + (hasRoom ? 1 : 0)

                ForEach(Array(buttons.enumerated()), id: \.element.id) { index, button in
                    let center = slotCenter(index: index, totalSlots: totalSlots, side: side, island: islandRect)
                    buttonView(button, side: side)
                        .position(center)
                        .zIndex(draggingID == button.id ? 20 : 5)
                }

                if hasRoom {
                    let center = slotCenter(index: buttons.count, totalSlots: totalSlots, side: side, island: islandRect)
                    addSlotButton(side: side)
                        .position(center)
                        .zIndex(2)
                }
            }
        }
        .onChange(of: editingButtonID) { _, _ in
            onPopoverChange(editingButtonID != nil || addingSide != nil)
        }
        .onChange(of: addingSide) { _, _ in
            onPopoverChange(editingButtonID != nil || addingSide != nil)
        }
        .onDisappear { onPopoverChange(false) }
        .coordinateSpace(name: "liveEditorSpace")
        .frame(width: screenSize.width, height: screenSize.height)
    }

    @ViewBuilder
    private func buttonView(_ button: NotchQuickButton, side: NotchQuickAccessSide) -> some View {
        ZStack {
            Button {
                editingButtonID = button.id
            } label: {
                Circle()
                    .fill(Color.black)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1.5)
                    }
                    .overlay {
                        Image(systemName: button.action?.symbol ?? "questionmark")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .popover(isPresented: Binding(
                get: { editingButtonID == button.id },
                set: { if !$0 { editingButtonID = nil } }
            ), arrowEdge: popoverEdge(for: side)) {
                NotchQuickActionPicker(selected: button.action) { action in
                    if let idx = configuration.buttons.firstIndex(where: { $0.id == button.id }) {
                        configuration.buttons[idx].actionID = action.id
                        save()
                    }
                    editingButtonID = nil
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    configuration.buttons.removeAll { $0.id == button.id }
                    save()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.8))
                        .frame(width: 18, height: 18)
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .offset(x: 15, y: -15)
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .named("liveEditorSpace"))
                .onChanged { value in
                    editingButtonID = nil
                    addingSide = nil
                    draggingID = button.id
                    dragTranslation = value.translation
                    dragLocation = value.location
                }
                .onEnded { value in
                    moveButton(button, at: value.location, island: CGRect(
                        x: (screenSize.width - islandWidth) / 2, y: 0,
                        width: islandWidth, height: islandHeight
                    ))
                    draggingID = nil
                    dragTranslation = .zero
                }
        )
        .offset(draggingID == button.id ? dragTranslation : .zero)
    }

    @ViewBuilder
    private func addSlotButton(side: NotchQuickAccessSide) -> some View {
        Button {
            addingSide = side
        } label: {
            Circle()
                .strokeBorder(Color.accentColor.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: 44, height: 44)
                .background(Color.clear)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
        }
        .buttonStyle(.plain)
        .popover(isPresented: Binding(
            get: { addingSide == side },
            set: { if !$0 { addingSide = nil } }
        ), arrowEdge: popoverEdge(for: side)) {
            NotchQuickActionPicker { action in
                guard configuration.hasRoom(on: side) else { return }
                configuration.buttons.append(NotchQuickButton(action: action, side: side))
                save()
                addingSide = nil
            }
        }
    }

    private func slotCenter(index: Int, totalSlots: Int, side: NotchQuickAccessSide, island: CGRect) -> CGPoint {
        switch side {
        case .left:
            let startY = island.midY - CGFloat(totalSlots - 1) * 28
            return CGPoint(x: island.minX - 38, y: startY + CGFloat(index) * 56)
        case .right:
            let startY = island.midY - CGFloat(totalSlots - 1) * 28
            return CGPoint(x: island.maxX + 38, y: startY + CGFloat(index) * 56)
        case .bottom:
            let startX = island.midX - CGFloat(totalSlots - 1) * 28
            return CGPoint(x: startX + CGFloat(index) * 56, y: island.maxY + 38)
        }
    }

    private func dropRect(_ side: NotchQuickAccessSide, island: CGRect) -> CGRect {
        switch side {
        case .left:
            return CGRect(x: island.minX - 110, y: island.minY - 20, width: 100, height: island.height + 40)
        case .right:
            return CGRect(x: island.maxX + 10, y: island.minY - 20, width: 100, height: island.height + 40)
        case .bottom:
            return CGRect(x: island.minX - 30, y: island.maxY + 5, width: island.width + 60, height: 100)
        }
    }

    private func moveButton(_ button: NotchQuickButton, at point: CGPoint, island: CGRect) {
        guard let targetSide = NotchQuickAccessSide.allCases.first(where: { dropRect($0, island: island).contains(point) }) else { return }
        let siblings = configuration.buttons.filter { $0.side == targetSide && $0.id != button.id }
        let targetNeighbor = siblings.enumerated().first { index, _ in
            let pt = slotCenter(index: index, totalSlots: siblings.count + 1, side: targetSide, island: island)
            return targetSide == .bottom ? pt.x > point.x : pt.y > point.y
        }?.element.id
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            configuration.move(button.id, to: targetSide, before: targetNeighbor)
            save()
        }
    }

    private func popoverEdge(for side: NotchQuickAccessSide) -> Edge {
        .top
    }

    private func save() {
        UserDefaults.standard.set(configuration.encoded, forKey: DefaultsKey.notchQuickAccessLayout)
    }
}
