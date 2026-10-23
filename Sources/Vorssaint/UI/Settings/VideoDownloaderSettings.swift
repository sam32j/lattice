import AppKit
import SwiftUI

struct VideoDownloaderSettings: View {
    @ObservedObject private var model: VideoDownloader
    @State private var confirmInstall = false
    init(model: VideoDownloader = .shared) { self.model = model }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsCard(title: "Local tools") {
                    ForEach(VideoDownloadDependencies.required, id: \.self) { tool in
                        HStack {
                            Label(tool, systemImage: model.dependencies.tools[tool] == nil ? "exclamationmark.circle" : "checkmark.circle")
                            Spacer()
                            Text(model.dependencies.tools[tool] == nil ? "Not found" : "Ready").foregroundStyle(.secondary)
                        }.help(model.dependencies.tools[tool] ?? "Install this tool to download video and audio.")
                    }
                    Divider()
                    Text("yt-dlp downloads videos. FFmpeg combines streams, ffprobe checks the result, and Deno supports video-site extraction.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Check again", action: model.refreshDependencies)
                        Spacer()
                        if !model.dependencies.ready && model.dependencies.brew == nil {
                            Link("Set up Homebrew…", destination: URL(string: "https://brew.sh")!)
                        } else if !model.dependencies.ready {
                            Button("Install missing tools…") { confirmInstall = true }
                        }
                    }.disabled(model.busy)
                }
                SettingsCard(title: "Video link") {
                    HStack {
                        TextField("https://…", text: $model.link).textFieldStyle(.roundedBorder)
                            .onSubmit { model.fetchInfo() }
                            .onChange(of: model.link) { _, _ in model.linkChanged() }
                        Button("Get video info", action: model.fetchInfo)
                            .disabled(!model.dependencies.ready || model.link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }.disabled(model.busy)
                    Text("Use a single video link. Download only content you own or have permission to save. Some sites restrict downloads or require sign-in.")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                if let info = model.info {
                    SettingsCard(title: "Download") {
                        Text(info.title).font(.headline).textSelection(.enabled)
                        if !info.creator.isEmpty { Text(info.creator).foregroundStyle(.secondary) }
                        if let duration = info.duration, duration.isFinite, duration > 0 {
                            Text(Duration.seconds(duration).formatted(.time(pattern: .hourMinuteSecond)))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Divider()
                        SettingsControlRow(title: "Quality") {
                            Picker("Quality", selection: $model.selectedHeight) {
                                ForEach(info.qualities) { quality in Text(quality.title).tag(quality.height) }
                            }.labelsHidden().pickerStyle(.menu)
                        }
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Save to")
                                Text(model.destination?.path ?? "Choose a folder").font(.caption)
                                    .foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
                            }
                            Spacer()
                            Button("Choose…", action: model.chooseDestination)
                        }
                        HStack {
                            Text("Separate streams merge into MKV; combined videos keep their original format. Existing files are kept.")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Download", action: model.download).buttonStyle(.borderedProminent)
                                .disabled(model.destination == nil || !model.dependencies.ready)
                        }
                    }.disabled(model.busy)
                }
                if model.busy || model.error != nil || !model.phase.isEmpty || model.output != nil {
                    SettingsCard {
                        if model.busy {
                            HStack {
                                if let progress = model.progress { ProgressView(value: progress).frame(maxWidth: 200) }
                                else { ProgressView().controlSize(.small) }
                                Text(model.phase)
                                Spacer()
                                Button("Cancel", action: model.cancel)
                            }
                        } else if !model.phase.isEmpty { Text(model.phase) }
                        if let error = model.error {
                            Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                        }
                        if let output = model.output {
                            HStack {
                                Text(output.lastPathComponent).lineLimit(2)
                                Spacer()
                                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([output]) }
                            }
                        }
                    }
                }
            }.frame(maxWidth: 760).padding(22).frame(maxWidth: .infinity)
        }
        .onAppear { model.refreshDependencies() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in model.refreshDependencies() }
        .confirmationDialog("Install local video tools?", isPresented: $confirmInstall) {
            Button("Install with Homebrew") { model.installTools() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Homebrew will download and install the missing tools and their dependencies on this Mac. This may use significant disk space and take several minutes. No video is downloaded during setup.")
        }
    }
}
