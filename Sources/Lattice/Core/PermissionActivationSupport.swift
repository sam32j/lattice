// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import Foundation

/// An enable intention belongs to one visible control, never to persistent preferences.
struct PermissionActivationRequest {
    private(set) var pendingID: UUID?

    mutating func begin() -> UUID {
        let id = UUID()
        pendingID = id
        return id
    }

    mutating func resolve(_ id: UUID, granted: Bool) -> Bool {
        guard pendingID == id else { return false }
        pendingID = nil
        return granted
    }

    mutating func cancel() { pendingID = nil }
}

enum SettingsPermission: Hashable {
    case accessibility, screenRecording, camera, microphone, calendar, bluetooth
}

enum SettingsPermissionResult { case granted, denied, needsSettings }

/// Owns a single, cancellable enable request. Verification never reads a UI cache.
final class PermissionActivationCoordinator {
    private var activation = PermissionActivationRequest()
    private let requirements: [SettingsPermission]
    private let verify: (SettingsPermission) -> Bool
    private let requestAccess: (SettingsPermission, @escaping (SettingsPermissionResult) -> Void) -> Void
    private let applyEnabled: (Bool) -> Void
    private var waitingForSettings: SettingsPermission?

    init(requirements: [SettingsPermission], verify: @escaping (SettingsPermission) -> Bool,
         requestAccess: @escaping (SettingsPermission, @escaping (SettingsPermissionResult) -> Void) -> Void,
         applyEnabled: @escaping (Bool) -> Void) {
        self.requirements = requirements
        self.verify = verify
        self.requestAccess = requestAccess
        self.applyEnabled = applyEnabled
    }

    func setEnabled(_ enabled: Bool) {
        cancel()
        guard enabled else { applyEnabled(false); return }
        _ = activation.begin()
        if !requirements.allSatisfy(verify) { applyEnabled(false) }
        advance()
    }

    func cancel() {
        activation.cancel()
        waitingForSettings = nil
    }

    func permissionStateChanged() {
        guard let permission = waitingForSettings, verify(permission) else { return }
        waitingForSettings = nil
        advance()
    }

    func returnedToApplication() {
        guard let permission = waitingForSettings else { return }
        waitingForSettings = nil
        guard verify(permission) else { cancel(); return }
        advance()
    }

    private func advance() {
        guard let id = activation.pendingID else { return }
        guard let missing = requirements.first(where: { !verify($0) }) else {
            if activation.resolve(id, granted: true) { applyEnabled(true) }
            return
        }
        requestAccess(missing) { [weak self] result in
            guard let self, self.activation.pendingID == id else { return }
            switch result {
            case .granted:
                guard self.verify(missing) else { self.cancel(); return }
                self.advance()
            case .denied:
                self.cancel()
            case .needsSettings:
                self.waitingForSettings = missing
            }
        }
    }
}
