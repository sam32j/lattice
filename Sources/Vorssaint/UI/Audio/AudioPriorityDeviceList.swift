import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PriorityDeviceList: View {
    @ObservedObject private var l10n = L10n.shared
    let priorityUIDs: [String]
    let isAvailable: (String) -> Bool
    let displayName: (String) -> String?
    let currentUID: String?
    /// A list is only empty while the Mac has no such device.
    let emptyText: String
    let onMove: ([String]) -> Void

    @State private var draggingUID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if priorityUIDs.isEmpty {
                Text(emptyText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 2) {
                    ForEach(Array(priorityUIDs.enumerated()), id: \.element) { index, uid in
                        priorityRow(uid: uid, index: index)
                    }
                }
            }
        }
    }

    private func priorityRow(uid: String, index: Int) -> some View {
        let available = isAvailable(uid)
        let name = displayName(uid) ?? uid
        let isCurrent = uid == currentUID

        return HStack(spacing: 8) {
            Text("\(index + 1)")
                .font(.system(size: 10.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(name)
                        .font(.system(size: 10.5))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(available ? .primary : .secondary)
                    if isCurrent {
                        Text(l10n.s.audioPriorityCurrent)
                            .font(.system(size: 9))
                            .foregroundStyle(Color.accentColor)
                            .fixedSize()
                    }
                }
                if !available {
                    Text(l10n.s.audioPriorityUnavailable)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 16, height: 22)
                .contentShape(Rectangle())
        }
        .font(.system(size: 9, weight: .semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isCurrent ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(isCurrent ? Color.accentColor.opacity(0.65) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .opacity(draggingUID == uid ? 0.45 : 1)
        .onDrag {
            draggingUID = uid
            return NSItemProvider(object: uid as NSString)
        } preview: {
            // A full-row preview lingers briefly while AppKit concludes the
            // drop. The real row has already moved by then, which makes the
            // two copies look like a slow settle. Keep native drag/drop, but
            // preview only the affordance so there is no duplicate row.
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(.regularMaterial,
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .accessibilityAction(named: Text(l10n.s.audioPriorityMoveUp)) {
            move(uid, by: -1)
        }
        .accessibilityAction(named: Text(l10n.s.audioPriorityMoveDown)) {
            move(uid, by: 1)
        }
        .onDrop(of: [UTType.text],
                delegate: PriorityDeviceDropDelegate(
                    targetUID: uid,
                    priorityUIDs: priorityUIDs,
                    onMove: onMove,
                    draggingUID: $draggingUID))
    }

    private func move(_ uid: String, by offset: Int) {
        guard let index = priorityUIDs.firstIndex(of: uid) else { return }
        let destination = index + offset
        guard priorityUIDs.indices.contains(destination) else { return }
        var reordered = priorityUIDs
        reordered.swapAt(index, destination)
        onMove(reordered)
    }
}

private struct PriorityDeviceDropDelegate: DropDelegate {
    let targetUID: String
    let priorityUIDs: [String]
    let onMove: ([String]) -> Void
    @Binding var draggingUID: String?

    func dropEntered(info: DropInfo) {
        guard let draggingUID,
              draggingUID != targetUID,
              let from = priorityUIDs.firstIndex(of: draggingUID),
              let to = priorityUIDs.firstIndex(of: targetUID) else { return }

        var reordered = priorityUIDs
        reordered.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        onMove(reordered)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingUID = nil
        return true
    }
}
