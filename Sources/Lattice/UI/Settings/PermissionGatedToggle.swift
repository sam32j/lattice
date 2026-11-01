// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

/// Preferences and runtime callbacks see only verified enables, never optimistic ones.
struct PermissionGatedToggle: View {
    let title: String
    @Binding var isOn: Bool
    var requiring: [SettingsPermission]
    var feature: AppFeature?
    @ObservedObject private var permissions = Permissions.shared
    @Environment(\.settingsPermissionAccess) private var access
    @State private var coordinator: PermissionActivationCoordinator?

    init(_ title: String, isOn: Binding<Bool>, requiring: [SettingsPermission] = [.accessibility], feature: AppFeature? = nil) {
        self.title = title
        self._isOn = isOn
        self.requiring = requiring
        self.feature = feature
    }

    private var granted: Bool { requiring.allSatisfy(access.verify) }

    var body: some View {
        Toggle(title, isOn: Binding(get: { isOn && granted }, set: change))
            .permissionActivationLifetime($coordinator)
    }

    private func change(_ value: Bool) {
        coordinator?.cancel()
        let binding = $isOn
        if value, requiring.contains(.screenRecording), !access.verify(.screenRecording) {
            if let feature {
                DeferredPermissionActivation.record(feature: feature)
            }
        } else if !value {
            DeferredPermissionActivation.clear()
        }
        let next = PermissionActivationCoordinator(requirements: requiring,
            verify: access.verify,
            requestAccess: access.request,
            applyEnabled: { enabled in
                if enabled { DeferredPermissionActivation.clear() }
                binding.wrappedValue = enabled
            })
        coordinator = next
        next.setEnabled(value)
    }
}
