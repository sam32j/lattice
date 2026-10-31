import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RadialItemEditor: View {
    let text: RadialMenuFeatureStrings
    @State var item: RadialMenuItem
    let isNew: Bool
    let allowsSubmenu: Bool
    var openChildren: (() -> Void)? = nil
    let save: (RadialMenuItem) -> Void
    let delete: (() -> Void)?

    @ObservedObject var l10n = L10n.shared
    @Environment(\.dismiss) var dismiss
    @State var shortcutError: String?
    @State var isFetchingFavicon = false
    @State var faviconStatus: FaviconFetchStatus?

    enum FaviconFetchStatus {
        case success
        case error
    }

    var availableTools: [RadialMenuTool] {
        RadialMenuTool.allCases.filter { $0.isRunnable() }
    }

    var availableQuickToggles: [RadialMenuQuickToggle] {
        RadialMenuQuickToggle.allCases.filter { $0.feature.isAvailable }
    }

    var urlIsInvalid: Bool {
        item.kind == .url && RadialMenuSupport.normalizedURL(item.payload) == nil
    }

    // The same rule sanitized() applies, so the editor can never save an item
    // the wheel would silently drop.
    var saveDisabled: Bool {
        !RadialMenuSupport.isValidPayload(item)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isNew ? text.addButton : item.displayName(text))
                .font(.headline)

            Form {
                Picker(text.actionLabel, selection: kindBinding) {
                    Text(text.kindApp).tag(RadialMenuItem.Kind.app)
                    Text(text.kindFile).tag(RadialMenuItem.Kind.file)
                    Text(text.kindURL).tag(RadialMenuItem.Kind.url)
                    Text(text.kindShortcut).tag(RadialMenuItem.Kind.shortcut)
                    if !availableTools.isEmpty {
                        Text(text.kindTool).tag(RadialMenuItem.Kind.tool)
                    }
                    if !availableQuickToggles.isEmpty {
                        Text(FeatureStrings.quickToggles(l10n.language).pageTitle)
                            .tag(RadialMenuItem.Kind.quickToggle)
                    }
                    if AppFeature.windowLayout.isAvailable {
                        Text(FeatureStrings.windowLayout(l10n.language).title)
                            .tag(RadialMenuItem.Kind.windowLayout)
                    }
                    Text(text.kindMedia).tag(RadialMenuItem.Kind.media)
                    if allowsSubmenu {
                        Text(text.kindSubmenu).tag(RadialMenuItem.Kind.submenu)
                    }
                }

                payloadEditor

                TextField(text.nameLabel, text: $item.name, prompt: Text(text.automaticLabel))

                RadialSymbolPicker(text: text, item: $item)
            }
            .formStyle(.columns)

            if urlIsInvalid, !item.payload.isEmpty {
                Text(text.urlInvalid)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if item.kind == .shortcut, let shortcutError {
                Text(shortcutError)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if item.kind == .submenu {
                Text(text.submenuCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let openChildren {
                    Button {
                        dismiss()
                        openChildren()
                    } label: {
                        HStack(spacing: 4) {
                            Text(text.editActionsButton)
                            Image(systemName: "chevron.forward")
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }

            HStack {
                if let delete {
                    Button(role: .destructive) {
                        delete()
                        dismiss()
                    } label: {
                        Text(text.deleteButton)
                    }
                }
                Spacer()
                Button(l10n.s.uninstallerCancel) { dismiss() }
                Button(text.saveButton) {
                    var saved = item
                    saved.name = item.name.trimmingCharacters(in: .whitespaces)
                    save(saved)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(saveDisabled)
            }
        }
        .padding(18)
        .frame(width: 440)
        .settingsExpansionAnimation(value: item.kind)
    }

    /// Changing the action type clears targets that no longer make sense but
    /// keeps the custom name and icon.
    var kindBinding: Binding<RadialMenuItem.Kind> {
        Binding(get: { item.kind }, set: { kind in
            guard kind != item.kind else { return }
            item.kind = kind
            shortcutError = nil
            faviconStatus = nil
            if kind != .url { item.customIconData = nil }
            switch kind {
            case .tool: item.payload = availableTools.first?.rawValue ?? ""
            case .quickToggle: item.payload = availableQuickToggles.first?.rawValue ?? ""
            case .windowLayout: item.payload = WindowLayoutAction.leftHalf.rawValue
            case .media: item.payload = RadialMenuMediaKey.playPause.rawValue
            default: item.payload = ""
            }
            if kind != .submenu { item.children = [] }
        })
    }

    var chooseTitle: String {
        if item.payload.isEmpty { return text.chooseButton }
        return RadialMenuIconStore.fileName(for: item.payload)
    }

    func choose(applications: Bool) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = !applications
        if applications {
            panel.allowedContentTypes = [.applicationBundle]
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
        }
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        RadialMenuIconStore.invalidate(item.payload)
        item.payload = url.path
    }

    func fetchWebsiteFavicon() {
        guard !item.payload.isEmpty, !urlIsInvalid else { return }
        isFetchingFavicon = true
        faviconStatus = nil

        RadialMenuFaviconFetcher.fetchFavicon(for: item.payload) { result in
            isFetchingFavicon = false
            switch result {
            case .success(let data):
                item.customIconData = data
                item.symbolName = ""
                RadialMenuIconStore.invalidate(item: item)
                faviconStatus = .success
            case .failure:
                faviconStatus = .error
            }
        }
    }
}

// MARK: - Icon picker

/// "Automatic" plus a small curated grid; automatic means the real app or
/// file icon when the target has one, or the action's own symbol.
