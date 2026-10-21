import SwiftUI

struct DockQuitOnCloseSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.autoQuitEnabled) private var enabled = false

    var body: some View {
        SettingsCard {
            SettingsRow(symbol: "xmark.rectangle", title: l10n.s.autoQuitName) {
                Toggle(l10n.s.autoQuitEnable, isOn: $enabled)
                    .labelsHidden()
                    .onChange(of: enabled) { _, _ in FeatureRuntime.shared.sync([.autoQuit]) }
            }
            if enabled {
                DockQuitOnCloseExceptions()
            }
        }
        .settingsSectionAnchor(.autoQuit, cornerRadius: 16)
    }
}

/// Construct service-backed controls only while this behavior is enabled.
private struct DockQuitOnCloseExceptions: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = AutoQuitService.shared
    @ObservedObject private var permissions = Permissions.shared
    @State private var showingAppPicker = false

    private var exceptions: [String] {
        AutoQuitSupport.visibleExceptions(service.exceptions) { InstalledApps.url(for: $0) != nil }
            .sorted { InstalledApps.name(for: $0).localizedStandardCompare(InstalledApps.name(for: $1)) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !permissions.accessibility { PermissionRow(kind: .accessibility) }
            DisclosureGroup(l10n.s.autoQuitExceptionsTitle) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.s.autoQuitOngoingWorkNote)
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(exceptions, id: \.self) { bundleID in
                        HStack {
                            Image(nsImage: InstalledApps.icon(for: bundleID))
                                .resizable().frame(width: 20, height: 20)
                            Text(InstalledApps.name(for: bundleID))
                            Spacer()
                            if service.isMandatoryException(bundleID) {
                                Image(systemName: "lock.fill").foregroundStyle(.tertiary)
                            } else {
                                Button { service.removeException(bundleID) } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(l10n.s.autoQuitExceptionsTitle + ": " + InstalledApps.name(for: bundleID))
                            }
                        }
                    }
                    Button { showingAppPicker = true } label: {
                        Label(l10n.s.autoQuitAddApp, systemImage: "plus")
                    }
                }
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            let excluded = Set(service.exceptions)
            AppPickerView { showingAppPicker = false } onSelect: { url in
                showingAppPicker = false
                guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return }
                service.addException(bundleID)
            } loadApps: {
                InstalledApps.installedBundleApplications(excluding: excluded)
            }
        }
    }
}
