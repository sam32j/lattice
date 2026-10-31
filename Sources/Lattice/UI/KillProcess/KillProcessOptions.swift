import SwiftUI

struct KillProcessOptions: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = KillProcessService.shared
    @AppStorage(DefaultsKey.killProcessCommandBarEnabled) private var commandBarEnabled = true
    private var strings: KillProcessFeatureStrings { FeatureStrings.killProcess(l10n.language) }

    var body: some View {
        Form {
            Section {
                Toggle(strings.groupToggle, isOn: Binding(
                    get: { service.groupRelated }, set: { service.setGroupRelated($0) }))
                Text(strings.groupCaption).font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Toggle(strings.commandBarToggle, isOn: $commandBarEnabled)
                Text(strings.commandBarCaption).font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The same options stay accessible in a native toolbar or a hosted Hub workspace.
struct KillProcessOptionsButton: View {
    @Binding var presented: Bool
    @ObservedObject private var l10n = L10n.shared
    private var title: String { FeatureStrings.recorder(l10n.language).moreOptions }

    var body: some View {
        Button { presented.toggle() } label: { Image(systemName: "slider.horizontal.3") }
            .help(title)
            .accessibilityLabel(title)
            .popover(isPresented: $presented) { KillProcessOptions().frame(width: 330) }
    }
}
