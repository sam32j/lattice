// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import SwiftUI

struct SettingsPermissionAccessors {
    var verify: (SettingsPermission) -> Bool = SettingsPermissionAccess.isGranted
    var request: (SettingsPermission, @escaping (SettingsPermissionResult) -> Void) -> Void = SettingsPermissionAccess.request
}

private struct SettingsPermissionAccessKey: EnvironmentKey {
    static let defaultValue = SettingsPermissionAccessors()
}

extension EnvironmentValues {
    var settingsPermissionAccess: SettingsPermissionAccessors {
        get { self[SettingsPermissionAccessKey.self] }
        set { self[SettingsPermissionAccessKey.self] = newValue }
    }
}

/// A pending intention belongs to its visible settings control and is canceled on exit.
private struct PermissionActivationLifetime: ViewModifier {
    @Binding var coordinator: PermissionActivationCoordinator?
    @ObservedObject private var permissions = Permissions.shared
    @State private var surfaceID = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { permissions.setActivePermissionSurface(surfaceID, visible: true) }
            .onDisappear {
                coordinator?.cancel()
                permissions.setActivePermissionSurface(surfaceID, visible: false)
            }
            .onReceive(permissions.objectWillChange) { _ in
                DispatchQueue.main.async { coordinator?.permissionStateChanged() }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                permissions.refresh()
                coordinator?.returnedToApplication()
            }
    }
}

extension View {
    func permissionActivationLifetime(_ coordinator: Binding<PermissionActivationCoordinator?>) -> some View {
        modifier(PermissionActivationLifetime(coordinator: coordinator))
    }
}
