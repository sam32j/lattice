// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

enum AppUpdateState: Equatable {
    case idle
    case checking
    case upToDate
    case available(version: String)
    case downloading(progress: Double?)
    case installing
    case failed(String)
}

/// Actions depend only on the current operation, never earlier session history.
struct UpdateSettingsPresentation {
    let state: AppUpdateState
    var canCheck: Bool {
        switch state {
        case .checking, .downloading, .installing: return false
        case .idle, .upToDate, .available, .failed: return true
        }
    }
    var reviewVersion: String? {
        if case let .available(version) = state { return version }
        return nil
    }
}
