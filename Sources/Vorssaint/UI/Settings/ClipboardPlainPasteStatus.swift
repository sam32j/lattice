import SwiftUI

/// Shortcut feedback is observed only while the shortcut is enabled.
struct ClipboardPlainPasteStatus: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = PastePlainService.shared

    var body: some View {
        if service.shortcutRegistrationFailed {
            Text(l10n.s.shortcutUnavailable).font(.caption).foregroundStyle(.orange)
        }
    }
}
