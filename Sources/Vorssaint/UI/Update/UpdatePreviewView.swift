import AppKit
import SwiftUI

/// Pre-install preview window content: shows the next version's full changelog;
/// the same notes that ship with the release; so the user can decide before any
/// download starts. Opened from both the Settings install button and the menu
/// panel's update banner. Reuses `ReleaseNotesContent`.
struct UpdatePreviewView: View {
    let version: String
    let notes: String?
    var onUpdate: () -> Void
    var onCancel: () -> Void

    @ObservedObject private var l10n = L10n.shared

    private var release: ReleaseNotes {
        // The release body is the changelog section without its `## [..]` header;
        // synthesize one so the existing parser can structure it.
        let body = ReleaseNotes.inAppUpdateNotes(from: notes) ?? ""
        return ReleaseNotes.notes(for: version, changelog: "## [\(version)]\n\n" + body)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(l10n.s.tabReleaseNotes)
                    .font(.system(size: 22, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                ReleaseNotesContent(releases: [release])
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 22)
            }

            Divider()

            HStack {
                Button(l10n.s.uninstallerCancel) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(l10n.s.updateInstallButton) { onUpdate() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 640, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
