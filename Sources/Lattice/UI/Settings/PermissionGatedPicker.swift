// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

struct PermissionGatedPicker<Value: Hashable, Options: View>: View {
    let title: String
    @Binding var selection: Value
    let requiring: (Value) -> [SettingsPermission]
    @ViewBuilder let options: Options
    @Environment(\.settingsPermissionAccess) private var access
    @State private var coordinator: PermissionActivationCoordinator?

    var body: some View {
        Picker(title, selection: Binding(get: { selection }, set: change)) { options }
            .permissionActivationLifetime($coordinator)
    }

    private func change(_ value: Value) {
        coordinator?.cancel()
        let binding = $selection
        let next = PermissionActivationCoordinator(requirements: requiring(value),
            verify: access.verify, requestAccess: access.request,
            applyEnabled: { granted in if granted { binding.wrappedValue = value } })
        coordinator = next
        next.setEnabled(true)
    }
}
