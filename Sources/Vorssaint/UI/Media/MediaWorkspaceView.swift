import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PanelMediaView: View {
    var onClose: () -> Void
    var body: some View {
        MediaHUDView(model: MediaHUDModel.shared, onClose: onClose)
            .onAppear { PanelInteractionState.shared.viewKeepsPopoverOpen = true }
            .onDisappear { PanelInteractionState.shared.viewKeepsPopoverOpen = false }
    }
}
struct MediaWorkspaceView: View {
    let compact: Bool
    let onClose: (() -> Void)?
    @ObservedObject private var media: MediaService
    @StateObject private var workspace: MediaWorkspaceSelection
    @Environment(\.notchPresentation) private var inNotch
    @State private var isDropTargeted = false
    @State private var aggressive = false
    private let initialInputs: [URL]
    private let initialTool: MediaTool?
    private let onContentHeightChange: ((CGFloat) -> Void)?
    private let onToolChange: (() -> Void)?
    static var panelModalActive = false
    init(compact: Bool, onClose: (() -> Void)? = nil,
         media: MediaService = .shared, initialInputs: [URL] = [],
         initialTool: MediaTool? = nil, preservesServiceState: Bool = false,
         workspace: MediaWorkspaceSelection? = nil,
         onContentHeightChange: ((CGFloat) -> Void)? = nil,
         onToolChange: (() -> Void)? = nil) {
        self.compact = compact; self.onClose = onClose; self.media = media
        self.initialInputs = initialInputs; self.initialTool = initialTool
        self.onContentHeightChange = onContentHeightChange; self.onToolChange = onToolChange
        _workspace = StateObject(wrappedValue: workspace ?? MediaWorkspaceSelection())
    }
    private var selectedTool: MediaTool {
        get { workspace.tool ?? .imageCompressor }
        nonmutating set {
            workspace.tool = newValue; workspace.inputURLs = []; media.reset()
        }
    }
    private var isRunning: Bool {
        if case .running = media.state { return true }; return false
    }
    var body: some View {
        layout
            .onAppear {
                if !workspace.loadedInitialInputs {
                    workspace.tool = initialTool ?? .imageCompressor
                    workspace.inputURLs = initialInputs; workspace.loadedInitialInputs = true
                }
            }
    }
    private var header: some View {
        HStack {
            Text("Media Optimizer").font(.headline)
            Spacer()
            if let onClose { Button(action: onClose) { Image(systemName: "xmark") }.buttonStyle(.plain) }
        }
    }
    private var toolPicker: some View {
        Picker("Media type", selection: selectedToolBinding) {
            ForEach(MediaTool.allCases) { Text($0.title).tag($0) }
        }.pickerStyle(.segmented).disabled(isRunning)
    }
    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsCard {
                inputDropTarget
                if !workspace.inputURLs.isEmpty {
                    Text(workspace.inputURLs.map(\.lastPathComponent).joined(separator: "\n"))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(4)
                }
                Divider()
                HStack {
                    Text("Save to")
                    Spacer()
                    Button(workspace.outputURL?.lastPathComponent ?? "Choose folder…", action: chooseOutput)
                }
                HStack {
                    Text("Stronger compression")
                    Spacer()
                    Toggle("Stronger compression", isOn: $aggressive).labelsHidden().toggleStyle(.switch)
                }
                Text(selectedTool == .imageCompressor
                    ? "JPEG, PNG, HEIC and animated GIF. Stronger compression may reduce quality. Originals are kept."
                    : "Uses macOS to save HEVC MP4, up to 1080p, or 720p with stronger compression. Unsupported formats need another converter. Originals are kept.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button("Optimize") {
                        guard let destination = workspace.outputURL else { return }
                        media.optimize(inputs: workspace.inputURLs, destination: destination, tool: selectedTool, aggressive: aggressive)
                    }.buttonStyle(.borderedProminent)
                        .disabled(workspace.inputURLs.isEmpty || workspace.outputURL == nil)
                }
            }.disabled(isRunning)
            status
        }
    }
    private var inputSelector: some View {
        HStack {
            Text(selectedTool == .imageCompressor ? "Images, including GIFs" : "Videos")
            Spacer()
            Button("Choose files…", action: chooseInput)
        }.padding(.vertical, 8)
    }
    @ViewBuilder private var status: some View {
        switch media.state {
        case .running(let progress, let message):
            HStack { ProgressView(value: progress); Text(message).font(.caption); Button("Cancel") { media.cancel() } }
        case .completed(let result):
            SettingsCard {
                Text("Saved \(result.outputURLs.count) file(s).").font(.headline)
                Text("\(ByteCountFormatter.string(fromByteCount: result.originalBytes, countStyle: .file)) → \(ByteCountFormatter.string(fromByteCount: result.outputBytes, countStyle: .file))")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting(result.outputURLs) }
                if result.unchangedCount > 0 {
                    Text("\(result.unchangedCount) file(s) were already compact; original-quality copies were saved.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.circle").foregroundStyle(.red)
                .font(.callout).fixedSize(horizontal: false, vertical: true)
        case .cancelled:
            VStack(alignment: .leading, spacing: 8) {
                Text(media.completedOutputs.isEmpty ? "Cancelled." : "Cancelled. \(media.completedOutputs.count) completed file(s) were saved.")
                    .font(.caption).foregroundStyle(.secondary)
                if !media.completedOutputs.isEmpty {
                    Button("Show completed files in Finder") { NSWorkspace.shared.activateFileViewerSelecting(media.completedOutputs) }
                }
            }
        case .idle: EmptyView()
        }
    }
    private func chooseInput() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = selectedTool == .imageCompressor ? [.image] : [.movie, .video]
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        Self.runPanelModal(panel) { response in
            if response == .OK { workspace.inputURLs = panel.urls; media.reset() }
        }
    }
    private func chooseOutput() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        Self.runPanelModal(panel) { response in if response == .OK { workspace.outputURL = panel.url } }
    }
    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !isRunning else { return false }
        let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !matching.isEmpty else { return false }
        for provider in matching {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                guard let url, url.isFileURL else { return }
                DispatchQueue.main.async {
                    guard !isRunning, MediaOptimizerPolicy.accepts((try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType, tool: selectedTool) else { return }
                    if !workspace.inputURLs.contains(url) { workspace.inputURLs.append(url) }
                }
            }
        }
        return true
    }
    private var layout: some View {
        Group {
            if let onContentHeightChange {
                ScrollView {
                    VStack(alignment: .leading, spacing: compact ? 10 : 14) {
                        header
                        toolPicker
                        content.padding(.trailing, 1)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                        onContentHeightChange($0)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: compact ? 10 : 14) {
                    header
                    toolPicker
                    ScrollView {
                        content.padding(.trailing, 1)
                    }
                    .frame(maxHeight: compact ? 430 : .infinity)
                }
            }
        }
    }


    @ViewBuilder private var inputDropTarget: some View {
        if inNotch {
            inputSelector
        } else {
            inputSelector.onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                acceptDrop(providers)
            }
        }
    }


    private var selectedToolBinding: Binding<MediaTool> {
        Binding {
            selectedTool
        } set: { newValue in
            guard newValue != selectedTool else { return }
            onToolChange?()
            selectedTool = newValue
        }
    }


    private static func runPanelModal(_ panel: NSSavePanel,
                                      completion: @escaping (NSApplication.ModalResponse) -> Void) {
        guard !panelModalActive else { return }
        panelModalActive = true
        if let island = NotchService.shared.presentationWindow, island.isVisible,
           NSApp.currentEvent?.window === island || NSApp.keyWindow === island {
            // The island floats above the modal panel level, so an
            // application-modal dialog would open behind it, and a sheet
            // moves/reskins the borderless island. Open it on its own,
            // just above the island.
            panel.level = NSWindow.Level(rawValue: island.level.rawValue + 1)
            // Like the sheet it replaces, it stays up while another app is active.
            panel.hidesOnDeactivate = false
            panel.begin { response in
                panelModalActive = false
                // Dismissal restores the previous key window after this callback.
                DispatchQueue.main.async { if NotchService.shared.expanded { island.makeKey() } }
                completion(response)
            }
            NSApp.activate(ignoringOtherApps: true)
            // Activation alone can leave the nonactivating island holding focus.
            panel.makeKeyAndOrderFront(nil)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            let response = panel.runModal()
            panelModalActive = false
            QuickLauncherService.shared.refocusAfterModal()
            completion(response)
        }
    }
}
