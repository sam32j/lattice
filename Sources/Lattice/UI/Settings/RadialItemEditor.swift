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
    /// The width every field and menu of the editor shares.
    static let fieldWidth: CGFloat = 175

    /// The name the action gets when none is typed, shown as the field's
    /// placeholder; "Automatic" only until there is a target to name.
    var automaticName: String {
        var unnamed = item
        unnamed.name = ""
        let hasTarget = !((item.kind == .app || item.kind == .file || item.kind == .url) && item.payload.isEmpty)
            && !urlIsInvalid
        return hasTarget ? unnamed.displayName(text, stableToggles: true) : text.automaticLabel
    }

    /// What the Action menu offers. Utilities that open something and the
    /// controls that switch something are separate, as in the hub, whatever
    /// kind they are stored as.
    enum Category: Hashable {
        case app, file, url, shortcut, utility, control, windowLayout, media, submenu
    }

    /// The tools on offer, plus the one this action already uses even if its
    /// feature is switched off now, so the menu never shows a blank choice.
    private var offeredTools: [RadialMenuTool] {
        guard let current = item.tool, !availableTools.contains(current) else { return availableTools }
        return availableTools + [current]
    }
    var availableUtilities: [RadialMenuTool] { offeredTools.filter { !$0.isControl } }
    var availableControlTools: [RadialMenuTool] { offeredTools.filter(\.isControl) }

    var category: Category {
        switch item.kind {
        case .app: return .app
        case .file: return .file
        case .url: return .url
        case .shortcut: return .shortcut
        case .tool: return item.tool?.isControl == true ? .control : .utility
        case .quickToggle: return .control
        case .windowLayout: return .windowLayout
        case .media: return .media
        case .submenu: return .submenu
        }
    }

    var availableCategories: [Category] {
        var categories: [Category] = [.app, .file, .url, .shortcut]
        if !availableUtilities.isEmpty { categories.append(.utility) }
        if !availableQuickToggles.isEmpty || !availableControlTools.isEmpty { categories.append(.control) }
        if AppFeature.windowLayout.isAvailable { categories.append(.windowLayout) }
        categories.append(.media)
        if allowsSubmenu { categories.append(.submenu) }
        return categories
    }

    func categoryTitle(_ category: Category) -> String {
        switch category {
        case .app: return text.kindApp
        case .file: return text.kindFile
        case .url: return text.kindURL
        case .shortcut: return text.kindShortcut
        case .utility: return text.kindTool
        case .control: return FeatureStrings.quickToggles(l10n.language).pageTitle
        case .windowLayout: return FeatureStrings.windowLayout(l10n.language).title
        case .media: return text.kindMedia
        case .submenu: return text.kindSubmenu
        }
    }

    var categoryBinding: Binding<Category> {
        Binding(get: { category }, set: { new in
            guard new != category else { return }
            switch new {
            case .app: kindBinding.wrappedValue = .app
            case .file: kindBinding.wrappedValue = .file
            case .url: kindBinding.wrappedValue = .url
            case .shortcut: kindBinding.wrappedValue = .shortcut
            case .utility:
                kindBinding.wrappedValue = .tool
                item.payload = availableUtilities.first?.rawValue ?? ""
            case .control:
                if let toggle = availableQuickToggles.first {
                    kindBinding.wrappedValue = .quickToggle
                    item.payload = toggle.rawValue
                } else {
                    kindBinding.wrappedValue = .tool
                    item.payload = availableControlTools.first?.rawValue ?? ""
                }
            case .windowLayout: kindBinding.wrappedValue = .windowLayout
            case .media: kindBinding.wrappedValue = .media
            case .submenu: kindBinding.wrappedValue = .submenu
            }
        })
    }

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
                        Picker(text.actionLabel, selection: categoryBinding) {
                            ForEach(availableCategories, id: \.self) { category in
                                Text(categoryTitle(category)).tag(category)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: Self.fieldWidth)
                    }
                    payloadEditor
                    if item.kind == .submenu {
                        editorRow(text.kindSubmenu, help: text.submenuCaption) {
                            Button(text.editActionButton) {
                                dismiss()
                                openChildren?()
                            }
                            .disabled(openChildren == nil)
                        }
                    }
                }
            }

            SettingsCard {
                VStack(alignment: .leading, spacing: 12) {
                    editorRow(text.nameLabel) {
                        TextField(text.nameLabel, text: $item.name, prompt: Text(automaticName))
                            .textFieldStyle(.roundedBorder)
                            .labelsHidden()
                            .frame(width: Self.fieldWidth)
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
                Text(categoryTitle(category))
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
