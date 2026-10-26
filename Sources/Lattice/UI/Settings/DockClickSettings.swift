// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

struct DockClickSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @Environment(\.settingsPermissionAccess) private var access
    @AppStorage(DefaultsKey.dockClickMinimize) private var minimize = false
    @AppStorage(DefaultsKey.dockClickHide) private var hide = false
    @AppStorage(DefaultsKey.dockClickCycleWindows) private var cycle = false
    @State private var coordinator: PermissionActivationCoordinator?
    var sync: () -> Void = { FeatureRuntime.shared.sync([.dockClick]) }

    typealias Action = DockClickMode

    var body: some View {
        let copy = DockClickCopy.strings(l10n.language)
        VStack(alignment: .leading, spacing: 13) {
            Text(copy.body)
                .font(.body)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Action.allCases, id: \.self) { action in
                    let selected = isSelected(action)
                    Button { select(action) } label: {
                        VStack(spacing: 8) {
                            Image(systemName: action.symbol).font(.system(size: 20, weight: .medium))
                            Text(title(action, copy: copy)).font(.system(size: 11, weight: .medium))
                                .lineLimit(2).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 68).padding(8)
                        .foregroundStyle(selected ? Color.accentColor : .primary)
                        .background(selected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(selected ? Color.accentColor.opacity(0.7) : .clear, lineWidth: 1)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(title(action, copy: copy))
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .permissionActivationLifetime($coordinator)
    }

    private func title(_ action: Action, copy: DockClickStrings) -> String {
        switch action {
        case .off: return copy.off
        case .toggleWindows: return copy.toggleWindows
        case .hideApps: return copy.hideApps
        case .cycleWindows: return copy.cycleWindows
        }
    }

    private func isSelected(_ action: Action) -> Bool {
        _ = minimize; _ = hide; _ = cycle
        let current: Action = access.verify(.accessibility) ? .selected(in: .standard) : .off
        return current == action
    }

    private func select(_ action: Action) {
        coordinator?.cancel()
        if action == .off {
            Action.off.store(in: .standard)
            sync()
            return
        }
        guard !isSelected(action) else { return }
        let synchronize = sync
        let next = PermissionActivationCoordinator(requirements: [.accessibility],
            verify: access.verify, requestAccess: access.request,
            applyEnabled: { enabled in
                (enabled ? action : .off).store(in: .standard)
                synchronize()
            })
        coordinator = next
        next.setEnabled(true)
    }
}
