import AppKit
import MusicKit
import SwiftUI

/// Inspecting authorization never calls MusicAuthorization.request(). This
/// also avoids touching a library file just to decide which status to show.
struct MediaMusicPermissionRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var l10n = L10n.shared
    @State private var status = MusicAuthorization.currentStatus
    @State private var details = false
    let hub: FeatureHubStrings

    private var granted: Bool { status == .authorized }
    private var statusColor: Color {
        granted ? PanelMetricColor.green(for: colorScheme) : PanelMetricColor.orange(for: colorScheme)
    }
    private var title: String { "Media & Music" }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "music.note").font(.system(size: 13, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 30, height: 30)
                .background(statusColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title).fontWeight(.medium)
                    Circle().fill(statusColor).frame(width: 6, height: 6)
                    Text(granted ? hub.statusGranted : hub.statusMissing).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { details = true } label: { Image(systemName: "info.circle") }
                        .buttonStyle(.borderless).accessibilityLabel("\(title): \(DataPermissionsStrings.localized(l10n.language).details)")
                }
                Button(hub.openSystemSettings) {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Media") {
                        NSWorkspace.shared.open(url)
                    }
                }.controlSize(.small).padding(.top, 2)
            }
        }
        .padding(.vertical, 14)
        .onAppear { status = MusicAuthorization.currentStatus }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            status = MusicAuthorization.currentStatus
        }
        .sheet(isPresented: $details) {
            VStack(alignment: .leading, spacing: 16) {
                Text(title).font(.title2.bold())
                Text("macOS controls access to your music, video activity and media library. Viewing this status does not request access.")
                    .foregroundStyle(.secondary)
                HStack { Spacer(); Button(l10n.s.doneButton) { details = false }.keyboardShortcut(.cancelAction) }
            }.padding(24).frame(width: 460)
        }
    }
}
