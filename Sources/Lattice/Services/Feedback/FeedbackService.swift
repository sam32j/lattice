// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

extension FeedbackDiagnostics {
    static func current() -> FeedbackDiagnostics {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let isBeta = AppInfo.isBeta
        let channel = AppInfo.isDeveloperBuild ? "developer" : (isBeta ? "beta" : (UpdateService.shared.includeBetaUpdates ? "beta-opt-in" : "stable"))
        return FeedbackDiagnostics(
            appVersion: AppInfo.version,
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0",
            macOS: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            macModel: modelIdentifier,
            language: L10n.shared.language.rawValue,
            isBeta: isBeta,
            updateChannel: channel
        )
    }

    private static let modelIdentifier: String? = {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }()
}

@MainActor
final class FeedbackService {
    static let shared = FeedbackService()

    private init() {}

    func openDraft(kind: FeedbackKind,
                message: String,
                diagnostics: FeedbackDiagnostics?) throws {
        try FeedbackDraft.open(kind: kind, message: message, diagnostics: diagnostics,
                               using: { NSWorkspace.shared.open($0) })
    }
}
