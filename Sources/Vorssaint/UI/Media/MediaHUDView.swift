import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MediaHUDView: View {
    @ObservedObject var model: MediaHUDModel
    var onClose: (() -> Void)? = nil
    var onHeight: ((CGFloat) -> Void)? = nil
    var onDropCommitted: (() -> Void)? = nil
    var canReceiveDrop: ((NSPasteboard) -> Bool)? = nil
    var receiveDrop: ((NSDraggingInfo) -> Bool)? = nil
    @State private var targeted = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                HStack(spacing: 7) {
                    Image(systemName: "wand.and.stars").foregroundStyle(Color.accentColor)
                    Text("Media Optimizer").font(.headline)
                }.overlay(WindowMoveHandle())
                Spacer()
                if let onClose {
                    Button(action: onClose) { Image(systemName: "xmark") }.buttonStyle(.plain)
                        .help("Close. Running optimization continues.")
                }
            }
            if model.inputs.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "arrow.down.doc").font(.system(size: 25)).foregroundStyle(.secondary)
                    Text("Drop images, GIFs or videos").font(.callout)
                    Button("Choose files…", action: chooseFiles)
                }.frame(maxWidth: .infinity).padding(.vertical, 20)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(
                        targeted ? Color.accentColor : Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            } else {
                preview
                status
                if !model.outputs.isEmpty { actions }
                formatBar
                HStack {
                    Toggle("Stronger compression", isOn: $model.aggressive).controlSize(.small)
                        .disabled(model.busy)
                    Spacer()
                    Button("Optimize") { model.run() }.disabled(model.busy)
                }
                if model.formats.contains(.hevc) {
                    Text("MP4 · up to 1080p, or 720p with stronger compression.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            if model.needsDestination {
                Text("The source folder isn't writable. Choose where to save optimized copies.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Choose save folder…", action: chooseDestination)
            }
            if let error = model.error {
                Label(error, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.red)
            }
            HStack {
                Text("Originals are kept.").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                if !model.inputs.isEmpty { Button("Choose files…", action: chooseFiles).controlSize(.small).disabled(model.busy) }
            }
        }
        .padding(14)
        .fixedSize(horizontal: false, vertical: true)
        .background(MediaHUDDropReceiver(canAccept: { board in
            guard AppFeature.mediaTools.isAvailable else { return false }
            return canReceiveDrop?(board) ?? (MediaHUDPayload.urls(from: board) != nil && !model.busy)
        }, accept: { sender in
                guard AppFeature.mediaTools.isAvailable else { return false }
                if let receiveDrop { return receiveDrop(sender) }
                guard let urls = MediaHUDPayload.urls(from: sender.draggingPasteboard) else { return false }
                let accepted = model.receive(urls)
                if accepted { onDropCommitted?() }
                return accepted
            }, targeted: { targeted = $0 }))
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeight?($0) }
    }
    private var preview: some View {
        VStack(spacing: 8) {
            if model.inputs.count > 1 {
                Picker("File", selection: $model.selectedIndex) {
                    ForEach(Array(model.inputs.enumerated()), id: \.offset) { index, url in
                        Text(url.lastPathComponent).tag(index)
                    }
                }.labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                let url = model.showsOriginal ? model.selectedOriginal : model.selectedOutput ?? model.selectedOriginal
                if let url { MediaHUDThumbnail(url: url).frame(width: 58, height: 58) }
                VStack(alignment: .leading, spacing: 5) {
                    Text(url?.lastPathComponent ?? "")
                        .font(.system(size: 12, weight: .medium)).lineLimit(2).truncationMode(.middle)
                    if let original = model.selectedOriginal, let output = model.selectedOutput {
                        Text("\(size(original)) → \(size(output))").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text(model.inputs.count == 1 ? "1 file" : "\(model.inputs.count) files")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
    @ViewBuilder private var status: some View {
        switch model.service.state {
        case .running(let progress, let message):
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: progress)
                HStack {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel", action: model.cancel).controlSize(.small)
                }
            }
        case .completed(let result):
            let saved = max(0, result.originalBytes - result.outputBytes)
            let percent = result.originalBytes > 0 ? Int((Double(saved) / Double(result.originalBytes) * 100).rounded()) : 0
            Label(saved > 0 ? "Saved \(ByteCountFormatter.string(fromByteCount: saved, countStyle: .file)) · \(percent)%"
                  : result.outputBytes > result.originalBytes ? "Converted · larger total size"
                  : result.outputURLs.count == 1 ? "Copy saved · no size reduction" : "Copies saved · no size reduction",
                  systemImage: saved > 0 ? "checkmark.circle" : "doc")
                .font(.caption).foregroundStyle(.secondary)
        case .failed(let error):
            Label(error, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.red)
            Button("Choose another save folder…", action: chooseDestination).controlSize(.small)
        case .cancelled: Text("Cancelled. Finished copies are kept.").font(.caption).foregroundStyle(.secondary)
        case .idle: EmptyView()
        }
    }
    private var actions: some View {
        HStack(spacing: 10) {
            if let output = model.selectedOutput {
                Button { NSPasteboard.general.clearContents(); NSPasteboard.general.writeObjects([output as NSURL]) }
                    label: { Label("Copy", systemImage: "doc.on.doc") }.help("Copy the optimized file")
                Button { NSWorkspace.shared.activateFileViewerSelecting([output]) }
                    label: { Label("Reveal", systemImage: "folder") }.help("Show the optimized file in Finder")
                Image(systemName: "hand.draw").padding(5).contentShape(Rectangle())
                    .onDrag { NSItemProvider(contentsOf: output) ?? NSItemProvider() }.help("Drag the optimized file")
                    .accessibilityLabel("Drag the optimized file")
            }
            Spacer()
            Toggle("Preview original", isOn: $model.showsOriginal).toggleStyle(.button).controlSize(.small)
                .help("Preview the original. Copy, Reveal and drag still use the optimized file.")
        }.font(.caption).buttonStyle(.borderless)
    }
    private var formatBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            HStack {
                Text(model.formats == [.gif] ? "Optimize as" : "Convert to").font(.caption.weight(.medium))
                Spacer()
                if model.inputs.count > 1 { Text("All \(model.inputs.count) files").font(.caption2).foregroundStyle(.secondary) }
            }
            HStack(spacing: 6) {
                ForEach(model.formats) { format in
                    Button(format.title) { model.run(format: format) }
                        .buttonStyle(.bordered).controlSize(.small)
                        .tint(model.format == format ? .accentColor : nil)
                        .help(format == .gif ? "Optimize GIF without removing animation."
                              : format == .jpeg ? "Convert to a JPEG copy. Transparent areas become white."
                              : "Convert to a \(format.title) copy.")
                }
                Spacer(minLength: 0)
            }.disabled(model.busy || model.needsDestination)
        }
    }
    private func size(_ url: URL) -> String {
        ByteCountFormatter.string(fromByteCount: Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0), countStyle: .file)
    }
    private func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.jpeg, .png, .heic, .gif, .movie, .video]
        panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        let ticket = model.dialogTicket
        MediaHUDDialogs.run(panel) { if $0 == .OK, AppFeature.mediaTools.isAvailable,
            model.acceptFiles(panel.urls, ticket: ticket) { onDropCommitted?() } }
    }
    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.canCreateDirectories = true
        let ticket = model.dialogTicket
        MediaHUDDialogs.run(panel) { if $0 == .OK, AppFeature.mediaTools.isAvailable, let url = panel.url {
            model.acceptDestination(url, ticket: ticket)
        } }
    }
}

private struct MediaHUDThumbnail: View {
    let url: URL
    var body: some View {
        let image = ImageFileSupport.imageThumbnail(at: url, maxPixel: 120)
            .map { NSImage(cgImage: $0, size: .zero) } ?? NSWorkspace.shared.icon(forFile: url.path)
        Image(nsImage: image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
