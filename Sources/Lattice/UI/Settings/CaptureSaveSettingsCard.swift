// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import AppKit
import SwiftUI

/// Shared save location and templates for screenshot PNGs and recording exports.
struct CaptureSaveSettingsCard: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.captureSaveLocationBookmark) private var folderBookmark = Data()
    @AppStorage(DefaultsKey.captureSaveSubfolderTemplate) private var subfolders = ""
    @AppStorage(DefaultsKey.captureSaveFileNameTemplate) private var nameTemplate = CaptureSaveNaming.defaultTemplate
    @AppStorage(DefaultsKey.screenshotSaveAutomatically) private var autoSaveScreenshot = false
    @AppStorage(DefaultsKey.recorderSaveAutomatically) private var autoSaveRecording = false
    @StateObject private var folderInsertion = CaptureSaveTokenInsertion()
    @StateObject private var fileInsertion = CaptureSaveTokenInsertion()
    @State private var suggested: URL?
    @State private var previewGeneration = 0
    @State private var folderIsMissing = false

    private var strings: CaptureSaveStrings { .localized(l10n.language) }
    private var activeFolder: URL? { CaptureSaveLocation.resolvedFolder() }
    private var savesAutomatically: Bool { autoSaveScreenshot || autoSaveRecording }

    var body: some View {
        SettingsCard(title: strings.save) {
            VStack(alignment: .leading, spacing: 14) {
                SettingsControlRow(title: strings.location) {
                    Button(action: choose) {
                        HStack(spacing: 7) {
                            Image(systemName: folderIsMissing ? "exclamationmark.triangle" : "folder")
                                .font(.system(size: 13))
                            Text(folderIsMissing ? strings.chooseFolder : folderDisplayPath)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .frame(width: 140, height: 32)
                        .background(Color.primary.opacity(0.07),
                                    in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .help(activeFolder.map { abbreviatedPath($0.path) } ?? strings.chooseFolder)
                    .accessibilityLabel(strings.location + ": " + folderDisplayPath)
                }

                saveTemplateRow(title: strings.organize, text: $subfolders,
                                placeholder: strings.optional, insertion: folderInsertion,
                                allowsCounter: false)
                if CaptureSaveNaming.counterCount(subfolders) > 0 {
                    validation(strings.subfolderCounter)
                }
                saveTemplateRow(title: strings.fileName, text: $nameTemplate,
                                placeholder: CaptureSaveNaming.defaultTemplate,
                                insertion: fileInsertion, allowsCounter: true)
                if CaptureSaveNaming.counterCount(nameTemplate) > 1 {
                    validation(strings.oneCounter)
                }

                // Reserve the footnote's full height before the debounced
                // directory scan finishes, so the following card never moves.
                let savedFolder = suggested.map {
                    abbreviatedPath($0.deletingLastPathComponent().path) + "/"
                } ?? ""
                let savedName = suggested?.lastPathComponent ?? ""
                let pathText = Text(strings.savedAs + "  ").foregroundColor(.secondary)
                    + Text(savedFolder).foregroundColor(.secondary)
                    + Text(savedName).foregroundColor(.primary)
                pathText
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // A reserved single-line slot avoids jumps during the async
                    // lookup without leaving a large blank area below Saved as.
                    .frame(height: 18, alignment: .topLeading)
                    .accessibilityLabel(strings.savedAs + " " + savedFolder + savedName)
                    .padding(.top, 2)
            }
            // Keep the fields editable and use the normal Settings text colors,
            // including when neither automatic-save toggle is enabled.
        }
        .onAppear { refresh() }
        .onChange(of: folderBookmark) { _, _ in refresh() }
        .onChange(of: subfolders) { _, _ in refresh() }
        .onChange(of: nameTemplate) { _, _ in refresh() }
        .onChange(of: autoSaveScreenshot) { _, _ in refresh() }
        .onChange(of: autoSaveRecording) { _, _ in refresh() }
    }

    /// Display the same tilde-abbreviated folder path used by the original
    /// Screen Captures destination picker, while keeping the bookmark backing.
    private var folderDisplayPath: String {
        guard let activeFolder else { return strings.chooseFolder }
        return abbreviatedPath(activeFolder.path)
    }

    /// Keep the on-screen path Unix-style without changing the bookmarked URL.
    private func abbreviatedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + String(path.dropFirst(home.count)) }
        return path
    }

    private func validation(_ warning: String) -> some View {
        Label(warning, systemImage: "exclamationmark.triangle")
            .font(.system(size: 11)).foregroundStyle(.orange)
            .accessibilityLabel(warning)
    }

    private func saveTemplateRow(title: String, text: Binding<String>, placeholder: String,
                                 insertion: CaptureSaveTokenInsertion,
                                 allowsCounter: Bool) -> some View {
        SettingsControlRow(title: title) {
            HStack(spacing: 0) {
                CaptureSaveNativeTextField(text: text, placeholder: placeholder, insertion: insertion)
                    .accessibilityLabel(title)
                    .frame(maxWidth: .infinity)
                    .frame(height: 20)
                    .padding(.leading, 10)

                insertMenu(insertion: insertion, allowsCounter: allowsCounter)
                    .frame(width: 24, height: 24)
                    .padding(.trailing, 3)
            }
            // Use a compact native control height; the old 32-pt field
            // background made these two text inputs look disproportionately
            // tall compared with the rest of Capture Settings.
            .frame(width: 280, height: 28)
            .background(Color.primary.opacity(0.07),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(insertion.isFocused ? Color.accentColor : Color.primary.opacity(0.10),
                                  lineWidth: insertion.isFocused ? 1.3 : 0.5)
            }
        }
    }

    private func insertMenu(insertion: CaptureSaveTokenInsertion,
                            allowsCounter: Bool) -> some View {
        Menu {
            Section(strings.date) {
                token(.year, strings.year, "2026", insertion: insertion)
                token(.twoDigitYear, strings.twoDigitYear, "26", insertion: insertion)
                token(.month, strings.month, "11", insertion: insertion)
                token(.monthName, strings.monthName, "November", insertion: insertion)
                token(.day, strings.day, "10", insertion: insertion)
            }
            Section(strings.time) {
                token(.hour, strings.hour, "00", insertion: insertion)
                token(.minute, strings.minute, "36", insertion: insertion)
                token(.second, strings.second, "31", insertion: insertion)
            }
            token(.media, strings.media, "screenshot", insertion: insertion)
            if allowsCounter { token(.counter, strings.counter, "1", insertion: insertion) }
            token(.uuid, strings.uuid, "9b2f6c1e-…", insertion: insertion)
            token(.shortID, strings.shortID, "7c3e9a1f", insertion: insertion)
        } label: {
            Image(systemName: "plus.circle")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .help(strings.insertToken)
        .accessibilityLabel(strings.insertToken)
    }

    private enum Token: String {
        case year = "%year", twoDigitYear = "%y", month = "%mo", monthName = "%month", day = "%d"
        case hour = "%h", minute = "%mi", second = "%s", media = "%media", counter = "%#"
        case uuid = "%uuid", shortID = "%id"
    }

    private func token(_ value: Token, _ title: String, _ example: String,
                       insertion: CaptureSaveTokenInsertion) -> some View {
        Button {
            insertion.insert(value.rawValue)
        } label: {
            HStack {
                Text(title)
                Spacer(minLength: 8)
                Text(example).foregroundStyle(.secondary)
            }
        }
        .accessibilityLabel(title + ", " + example)
    }

    private func select(_ folder: URL) {
        do {
            try CaptureSaveLocation.store(folder)
            folderBookmark = UserDefaults.standard.data(forKey: DefaultsKey.captureSaveLocationBookmark) ?? Data()
        } catch {
            folderIsMissing = true
        }
    }

    private func choose() {
        if let chosen = CaptureSaveLocation.chooseFolder() { select(chosen) }
    }

    /// Debounce directory listing (250 ms), on a utility worker. A late read of
    /// an iCloud/network folder can never replace the preview of a newer edit.
    private func refresh() {
        previewGeneration += 1
        let generation = previewGeneration
        let location = activeFolder
        folderIsMissing = !CaptureSaveLocation.isWritable(location)
        let folder = location ?? CaptureSaveLocation.defaultFolder
        let pathTemplate = subfolders, fileTemplate = nameTemplate
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard generation == previewGeneration else { return }
            let media: CaptureSaveNaming.Media = autoSaveScreenshot || !autoSaveRecording
                ? .screenshot : .recording
            let ext = media == .screenshot ? "png" : "mov"
            let result = await Task.detached(priority: .utility) {
                CaptureSaveNaming.preview(in: folder, subfolderTemplate: pathTemplate,
                                          fileNameTemplate: fileTemplate, date: Date(),
                                          media: media, ext: ext)
            }.value
            guard generation == previewGeneration else { return }
            suggested = result
        }
    }
}

/// Holds selection and insertion even while a SwiftUI Menu temporarily steals
/// focus from AppKit's field editor.
final class CaptureSaveTokenInsertion: ObservableObject {
    var insert: (String) -> Void = { _ in }
    var selection: NSRange?
    var wasFocused = false
    @Published var isFocused = false
}

private struct CaptureSaveNativeTextField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    @ObservedObject var insertion: CaptureSaveTokenInsertion

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.placeholderString = placeholder
        field.font = .systemFont(ofSize: 13)
        field.textColor = .labelColor
        // SwiftUI draws the shared Settings control background and border.
        // The native editor remains borderless for exact caret-position inserts.
        field.drawsBackground = false
        field.isBezeled = false
        field.isBordered = false
        field.focusRingType = .none
        field.delegate = context.coordinator
        context.coordinator.field = field
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        field.placeholderString = placeholder
        // NSTextField's explicit semantic colors follow the hosting view's
        // appearance in both light and dark modes.
        field.textColor = .labelColor
        let binding = $text
        let insertion = insertion
        insertion.insert = { [weak field, weak insertion] token in
            guard let field, let insertion else { return }
            let original = field.stringValue as NSString
            let selection = (field.currentEditor()?.selectedRange
                ?? (insertion.wasFocused ? insertion.selection : nil)) ?? NSRange(location: original.length, length: 0)
            let start = min(selection.location, original.length)
            let length = min(selection.length, original.length - start)
            let range = NSRange(location: start, length: length)
            let revised = original.replacingCharacters(in: range, with: token)
            binding.wrappedValue = revised
            field.stringValue = revised
            let caret = NSRange(location: start + (token as NSString).length, length: 0)
            insertion.selection = caret
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
                field.currentEditor()?.selectedRange = caret
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CaptureSaveNativeTextField
        weak var field: NSTextField?
        init(_ parent: CaptureSaveNativeTextField) { self.parent = parent }
        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.insertion.wasFocused = true
            parent.insertion.isFocused = true
        }
        func controlTextDidChange(_ notification: Notification) {
            guard let field else { return }
            parent.text = field.stringValue
            parent.insertion.selection = field.currentEditor()?.selectedRange
        }
        func controlTextDidEndEditing(_ notification: Notification) {
            parent.insertion.selection = field?.currentEditor()?.selectedRange ?? parent.insertion.selection
            parent.insertion.isFocused = false
        }
    }
}
