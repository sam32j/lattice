import SwiftUI

struct FinderImagePasteSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @AppStorage(DefaultsKey.finderPasteImageAsFile) private var pasteImageAsFile = false

    private var text: ClipboardFeatureStrings { FeatureStrings.clipboard(l10n.language) }

    var body: some View {
        Section {
            Toggle(text.pasteImageAsFile, isOn: $pasteImageAsFile)
                .onChange(of: pasteImageAsFile) { _, _ in FinderCutPaste.shared.syncWithPreferences() }
            Text(text.pasteImageAsFileCaption).font(.caption).foregroundStyle(.secondary)
            if pasteImageAsFile, !permissions.accessibility { PermissionRow(kind: .accessibility) }
        }
    }
}
