// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit

enum LatticeInterfaceConfirmation {
    static func confirmHideLattice(over window: NSWindow? = nil) -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = SettingsFollowupStrings.text(.latticeWillBeHiddenTitle, L10n.shared.language)
        alert.informativeText = SettingsFollowupStrings.text(.latticeWillBeHiddenMessage, L10n.shared.language)
        alert.addButton(withTitle: SettingsFollowupStrings.text(.hideLatticeButton, L10n.shared.language))
        alert.addButton(withTitle: L10n.shared.s.uninstallerCancel)
        return PermissionDialogPresentation.run(alert, over: window ?? NSApp.mainWindow) == .alertFirstButtonReturn
    }
}
