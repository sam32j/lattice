import AppKit
import SwiftUI

struct PriorityDeviceList: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var outputSwitcher = SoundOutputSwitcher.shared
    @AppStorage(DefaultsKey.volumeMixerEnabled) private var volumeMixerEnabled = true
    @AppStorage(DefaultsKey.microphoneLevelControlEnabled) private var microphoneControlEnabled = true
    let priorityUIDs: [String]
    let isAvailable: (String) -> Bool
    let displayName: (String) -> String?
    let currentUID: String?
    /// A list is only empty while the Mac has no such device.
    let emptyText: String
    let onMove: ([String]) -> Void
    var canCycle: Bool = true

    /// The row being dragged, the slot it started from, and how far the
    /// pointer has moved in the list's own space. The order itself stays put
    /// until the row is let go, so nothing reloads under the pointer.
    @State private var draggingUID: String?
    @State private var dragStartIndex = 0
    @State private var dragTranslation: CGFloat = 0
    /// A released row is settling into its slot; a new drag waits for it, so
    /// every released drag commits its own move.
    @State private var settling = false
    /// Rows differ in height (a status line makes one taller), so slots come
    /// from each row's measured height.
    @State private var rowHeights: [String: CGFloat] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let rowSpacing: CGFloat = 2
    private static let space = "audioPriorityList"

    private var visibleUIDs: [String] {
        AudioPriorityPresentation.visibleUIDs(priorityUIDs, isAvailable: isAvailable, displayName: displayName)
    }

    private func reorderVisible(_ uids: [String]) {
        onMove(AudioPriorityPresentation.mergingVisibleOrder(uids, into: priorityUIDs))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if visibleUIDs.isEmpty {
                Text(emptyText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            } else {
                let uids = visibleUIDs
                let target = proposedIndex(in: uids)
                VStack(spacing: Self.rowSpacing) {
                    ForEach(Array(uids.enumerated()), id: \.element) { index, uid in
                        let isDragged = draggingUID == uid
                        priorityRow(uid: uid, index: index, isDragged: isDragged)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                                rowHeights[uid] = $0
                            }
                            // The dragged row tracks the pointer exactly; the
                            // rows it passes slide aside by its height.
                            .offset(y: isDragged ? dragTranslation : shift(for: index, target: target, in: uids))
                            .animation(isDragged || reduceMotion ? nil : .easeInOut(duration: 0.15), value: target)
                            .zIndex(isDragged ? 1 : 0)
                            .gesture(reorderGesture(for: uid, index: index, in: uids))
                    }
                }
                .padding(.horizontal, 1)
                .coordinateSpace(name: Self.space)
            }
        }
    }

    private func priorityRow(uid: String, index: Int, isDragged: Bool) -> some View {
        let available = isAvailable(uid)
        let name = displayName(uid) ?? uid
        let isCurrent = uid == currentUID
        let isSkipped = canCycle && outputSwitcher.isSkipped(uid)

        return HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 10.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(available ? .primary : .secondary)
                if canCycle && !available && isSkipped {
                    Text("\(l10n.s.audioPriorityUnavailable) • \(l10n.s.audioPrioritySkipCycling)")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if !available {
                    Text(l10n.s.audioPriorityUnavailable)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if canCycle && isSkipped {
                    Text(l10n.s.audioPrioritySkipCycling)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isCurrent {
                Text(l10n.s.audioPriorityCurrent)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .fixedSize()
            }

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 16, height: 22)
                .contentShape(Rectangle())
        }
        .font(.system(size: 9, weight: .semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background {
            // A lifted row reads as picked up: an opaque card with a shadow.
            if isDragged {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
            }
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isCurrent ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.035))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(isCurrent ? Color.accentColor.opacity(0.65) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .contextMenu {
            if canCycle {
                if volumeMixerEnabled {
                    Button(l10n.s.audioPrioritySetOutput) {
                        _ = AppVolumeMixer.shared.setUniversalOutputDeviceUID(uid)
                    }
                    .disabled(isCurrent || !available)
                }

                Toggle(l10n.s.audioPrioritySkipCycling, isOn: Binding(
                    get: { isSkipped },
                    set: { _ in outputSwitcher.toggleSkip(for: uid) }
                ))
            } else if microphoneControlEnabled {
                Button(l10n.s.audioPrioritySetInput) {
                    AudioInputDeviceManager.shared.setCurrentInputDeviceUID(uid)
                }
                .disabled(isCurrent || !available)
            }
        }
        .accessibilityAction(named: Text(l10n.s.audioPriorityMoveUp)) {
            move(uid, by: -1)
        }
        .accessibilityAction(named: Text(l10n.s.audioPriorityMoveDown)) {
            move(uid, by: 1)
        }
    }

    // MARK: - Dragging

    private func height(of uid: String) -> CGFloat { rowHeights[uid] ?? 34 }

    /// The slot the dragged row would land in now: past every row whose
    /// middle its own middle has crossed.
    private func proposedIndex(in uids: [String]) -> Int? {
        guard let draggingUID, uids.indices.contains(dragStartIndex),
              uids[dragStartIndex] == draggingUID else { return nil }
        var target = dragStartIndex
        if dragTranslation > 0 {
            var travelled: CGFloat = 0
            for index in uids.indices where index > dragStartIndex {
                let row = height(of: uids[index])
                // Half of the passed row plus the gap before it.
                guard dragTranslation > travelled + Self.rowSpacing + row / 2 else { break }
                travelled += Self.rowSpacing + row
                target = index
            }
        } else if dragTranslation < 0 {
            var travelled: CGFloat = 0
            for index in uids.indices.reversed() where index < dragStartIndex {
                let row = height(of: uids[index])
                guard -dragTranslation > travelled + Self.rowSpacing + row / 2 else { break }
                travelled += Self.rowSpacing + row
                target = index
            }
        }
        return target
    }

    /// How far a row that is not dragged moves aside for the dragged one.
    private func shift(for index: Int, target: Int?, in uids: [String]) -> CGFloat {
        guard let target, let draggingUID, index != dragStartIndex else { return 0 }
        let step = height(of: draggingUID) + Self.rowSpacing
        if dragStartIndex < target, (dragStartIndex + 1...target).contains(index) { return -step }
        if target < dragStartIndex, (target...dragStartIndex - 1).contains(index) { return step }
        return 0
    }

    /// Where the dragged row sits once it is in `target`'s slot.
    private func settleOffset(to target: Int, in uids: [String]) -> CGFloat {
        if target > dragStartIndex {
            return uids[(dragStartIndex + 1)...target].reduce(0) { $0 + height(of: $1) + Self.rowSpacing }
        }
        if target < dragStartIndex {
            return -uids[target..<dragStartIndex].reduce(0) { $0 + height(of: $1) + Self.rowSpacing }
        }
        return 0
    }

    private func reorderGesture(for uid: String, index: Int, in uids: [String]) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.space))
            .onChanged { value in
                guard !settling else { return }
                if draggingUID != uid {
                    draggingUID = uid
                    dragStartIndex = index
                }
                dragTranslation = value.translation.height
            }
            .onEnded { _ in
                guard !settling, draggingUID == uid, let target = proposedIndex(in: uids) else { return }
                settling = true
                let start = dragStartIndex
                // Settle into the slot first, then commit the order once with
                // no animation: every row is already where the order puts it.
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                    dragTranslation = settleOffset(to: target, in: uids)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0 : 0.12)) {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        if target != start {
                            var reordered = uids
                            reordered.move(fromOffsets: IndexSet(integer: start),
                                           toOffset: target > start ? target + 1 : target)
                            reorderVisible(reordered)
                        }
                        if draggingUID == uid {
                            draggingUID = nil
                            dragTranslation = 0
                        }
                        settling = false
                    }
                }
            }
    }

    private func move(_ uid: String, by offset: Int) {
        guard let index = visibleUIDs.firstIndex(of: uid) else { return }
        let destination = index + offset
        guard visibleUIDs.indices.contains(destination) else { return }
        var reordered = visibleUIDs
        reordered.swapAt(index, destination)
        reorderVisible(reordered)
    }
}
