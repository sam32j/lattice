import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RadialItemEditor: View {
    let text: RadialMenuFeatureStrings
    @State var item: RadialMenuItem
    let isNew: Bool
    let allowsSubmenu: Bool
    var profileColor: RadialMenuColor = .accent
    var openChildren: (() -> Void)? = nil
    let save: (RadialMenuItem) -> Void
    let delete: (() -> Void)?

    @ObservedObject var l10n = L10n.shared
    @Environment(\.dismiss) var dismiss
    @State var shortcutError: String?
    @State var isFetchingFavicon = false
    @State var faviconStatus: FaviconFetchStatus?
    @State var faviconToken = 0
    @State var showsIconChooser = false

    enum FaviconFetchStatus {
        case success
        case error
    }

    /// How long typing in the link field must pause before the website's
    /// icon is fetched.
    static let faviconDebounce: TimeInterval = 0.8

    var availableTools: [RadialMenuTool] {
        RadialMenuTool.allCases.filter { $0.isRunnable() }
    }

    var availableQuickToggles: [RadialMenuQuickToggle] {
        RadialMenuQuickToggle.allCases.filter { $0.isAvailable }
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
        VStack(alignment: .leading, spacing: 16) {
            header

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    editorRow(text.actionLabel) {
                        Picker(text.actionLabel, selection: kindBinding) {
                            ForEach(availableKinds, id: \.self) { kind in
                                Text(kindTitle(kind)).tag(kind)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    payloadEditor
                }
            }

            if item.kind == .submenu {
                SettingsCard {
                    editorRow(text.kindSubmenu, help: text.submenuCaption) {
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
                        }
                    }
                }
            }

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    editorRow(text.nameLabel) {
                        TextField(text.nameLabel, text: $item.name, prompt: Text(text.automaticLabel))
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .frame(width: 220)
                    }
                    editorRow(text.iconLabel, status: faviconMark) {
                        if isFetchingFavicon {
                            ProgressView().controlSize(.small)
                        }
                        iconChooserButton
                    }
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
                    .keyboardShortcut(.cancelAction)
                Button(text.saveButton) {
                    var saved = item
                    saved.name = item.name.trimmingCharacters(in: .whitespaces)
                    save(saved)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(saveDisabled)
            }
        }
        .padding(20)
        .frame(width: 460)
        .settingsExpansionAnimation(value: item.kind)
        .onChange(of: item.payload) { _, _ in scheduleFaviconFetch() }
    }

    /// The action as the wheel will show it, with its name and kind.
    private var header: some View {
        HStack(spacing: 12) {
            RadialChipFace(item: item, nowPlayingState: .nothingPlaying, highlighted: true,
                           profileColor: profileColor, size: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(isNew ? text.addButton : item.displayName(text, stableToggles: true))
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(kindTitle(item.kind))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    /// One line of the editor: title on the leading side (its tooltip says
    /// more where there is more to say), a status mark, the control.
    func editorRow<Control: View>(_ title: String, help: String? = nil, status: RadialRowNote.Content? = nil,
                                  @ViewBuilder control: () -> Control) -> some View {
        RadialTriggerRow(title: title, help: help, status: status, control: control)
    }

    var availableKinds: [RadialMenuItem.Kind] {
        var kinds: [RadialMenuItem.Kind] = [.app, .file, .url, .shortcut]
        if !availableTools.isEmpty { kinds.append(.tool) }
        if !availableQuickToggles.isEmpty { kinds.append(.quickToggle) }
        if AppFeature.windowLayout.isAvailable { kinds.append(.windowLayout) }
        kinds.append(.media)
        if allowsSubmenu { kinds.append(.submenu) }
        return kinds
    }

    func kindTitle(_ kind: RadialMenuItem.Kind) -> String {
        switch kind {
        case .app: return text.kindApp
        case .file: return text.kindFile
        case .url: return text.kindURL
        case .shortcut: return text.kindShortcut
        case .tool: return text.kindTool
        case .quickToggle: return FeatureStrings.quickToggles(l10n.language).pageTitle
        case .windowLayout: return FeatureStrings.windowLayout(l10n.language).title
        case .media: return text.kindMedia
        case .submenu: return text.kindSubmenu
        }
    }

    private var faviconMark: RadialRowNote.Content? {
        guard item.kind == .url, faviconStatus == .error else { return nil }
        return .info(text.fetchFaviconError)
    }

    private var iconChooserButton: some View {
        Button {
            showsIconChooser = true
        } label: {
            RadialIconPreview(item: item)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(showsIconChooser ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(showsIconChooser ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.16),
                                  lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(item.kind == .url ? text.fetchFaviconDisclaimer : text.iconLabel)
        .accessibilityLabel(text.iconLabel)
        .popover(isPresented: $showsIconChooser, arrowEdge: .bottom) {
            RadialIconChooser(text: text, item: $item)
        }
    }

    /// A link's own icon is fetched once typing pauses, unless a symbol was
    /// picked for it. A newer edit makes an older answer moot.
    func scheduleFaviconFetch() {
        faviconToken &+= 1
        faviconStatus = nil
        guard item.kind == .url else { return }
        let token = faviconToken
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.faviconDebounce) {
            guard faviconToken == token else { return }
            fetchWebsiteFavicon(token: token)
        }
    }

    /// Changing the action type clears targets that no longer make sense but
    /// keeps the custom name and icon.
    var kindBinding: Binding<RadialMenuItem.Kind> {
        Binding(get: { item.kind }, set: { kind in
            guard kind != item.kind else { return }
            item.kind = kind
            shortcutError = nil
            faviconStatus = nil
            faviconToken &+= 1
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
        // Run from this sheet as an app-wide modal, the panel was placed
        // where macOS last kept it, which can be off every screen: then each
        // click beeps, Quit is refused and the editor seems frozen. Attached
        // to the editor's own window it always opens over it.
        guard let window = NSApp.keyWindow, window.isVisible else {
            guard panel.runModal() == .OK, let url = panel.url else { return }
            applyChosen(url)
            return
        }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            applyChosen(url)
        }
    }

    func applyChosen(_ url: URL) {
        RadialMenuIconStore.invalidate(item.payload)
        item.payload = url.path
    }

    func fetchWebsiteFavicon(token: Int) {
        guard item.kind == .url, !item.payload.isEmpty, !urlIsInvalid, item.symbolName.isEmpty else { return }
        isFetchingFavicon = true
        RadialMenuFaviconFetcher.fetchFavicon(for: item.payload) { result in
            guard faviconToken == token else { return }
            isFetchingFavicon = false
            switch result {
            case .success(let data):
                item.customIconData = data
                RadialMenuIconStore.invalidate(item: item)
                faviconStatus = .success
            case .failure:
                item.customIconData = nil
                faviconStatus = .error
            }
        }
    }
}
