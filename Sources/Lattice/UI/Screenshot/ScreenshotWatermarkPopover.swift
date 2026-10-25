// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import UniformTypeIdentifiers

/// Composition and placement preview live; Done closes the composer.
/// Uploaded images are remembered independently in the image collection.
struct ScreenshotWatermarkPopover: View {
    @ObservedObject var model: ScreenshotEditorModel
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ScreenshotWatermarkDraft
    private let close: (() -> Void)?
    private let fileSelectionChanged: (Bool) -> Void

    init(model: ScreenshotEditorModel, close: (() -> Void)? = nil,
         fileSelectionChanged: @escaping (Bool) -> Void = { _ in }) {
        self.model = model
        self.close = close
        self.fileSelectionChanged = fileSelectionChanged
        _draft = State(initialValue: ScreenshotWatermarkDraft(model.watermarkStyle))
    }

    private var strings: ScreenshotFeatureStrings { FeatureStrings.screenshot(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker(strings.watermarkLabel, selection: Binding(
                get: { draft.style.kind },
                set: { kind in rememberImage(); draft.style.kind = kind })) {
                Text(strings.toolText).tag(ScreenshotSupport.WatermarkStyle.Kind.text)
                Text(strings.watermarkImageLabel).tag(ScreenshotSupport.WatermarkStyle.Kind.image)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .frame(maxWidth: .infinity, alignment: .center)
            if draft.style.kind == .text {
                textComposer
            } else {
                ScreenshotWatermarkCollection(selection: $draft.style,
                    presets: model.watermarkPresets, strings: strings,
                    addImage: chooseImage, remove: removePreset)
            }
            Divider()
            ScreenshotWatermarkStyleControls(style: $draft.style, strings: strings)
                .disabled(!draft.hasInput)
                .opacity(draft.hasInput ? 1 : 0.45)
            Divider()
            HStack {
                Button(l10n.s.shortcutReset) {
                    rememberImage()
                    draft.reset()
                    model.watermarkStyle = .init()
                    closeTool()
                }
                .buttonStyle(.bordered)
                .disabled(!draft.hasInput)
                Spacer()
                Button(l10n.s.doneButton) {
                    guard draft.hasInput else { return }
                    rememberImage()
                    model.watermarkStyle = draft.previewStyle
                    closeTool()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(!draft.hasInput)
            }
        }
        .padding(16)
        .frame(width: 300)
        .onChange(of: draft.style) { _, _ in
            let preview = draft.previewStyle
            if model.watermarkStyle != preview { model.watermarkStyle = preview }
        }
        .onDisappear { rememberImage() }
    }

    private var textComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(strings.watermarkTextPlaceholder, text: Binding(
                get: { draft.style.text },
                set: { draft.style.text = String($0.prefix(ScreenshotSupport.WatermarkStyle.textLimit)) }))
                .textFieldStyle(.roundedBorder)
            HStack(spacing: 6) {
                ForEach(ScreenshotSupport.ColorID.allCases, id: \.self) { color in
                    Button { draft.style.color = color.rawValue } label: {
                        Circle()
                            .fill(Color(nsColor: ScreenshotRenderer.nsColor(color)))
                            .frame(width: 18, height: 18)
                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 0.5))
                            .padding(3)
                            .overlay(Circle().strokeBorder(
                                draft.style.color == color.rawValue ? Color.accentColor : .clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .screenshotIconHover()
                    .screenshotSafeHelp(strings.watermarkColorName(color))
                    .accessibilityLabel(strings.watermarkColorName(color))
                    .accessibilityAddTraits(draft.style.color == color.rawValue ? .isSelected : [])
                }
            }
        }
    }

    private func rememberImage() {
        let style = draft.previewStyle
        guard style.kind == .image else { return }
        model.addWatermarkPreset(style)
    }

    private func removePreset(_ index: Int) {
        guard model.watermarkPresets.indices.contains(index) else { return }
        let removed = model.watermarkPresets[index]
        model.removeWatermarkPreset(at: index)
        let matches = removed.kind == draft.style.kind
            && removed.imagePath == draft.style.imagePath
        if matches { draft.reset() }
    }

    private func chooseImage() {
        rememberImage()
        fileSelectionChanged(true)
        defer { fileSelectionChanged(false) }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]
        if ScreenshotWindowLayering.runModalPanel(panel, above: NSApp.keyWindow) == .OK,
           let url = panel.url {
            guard BackdropPickerAssets.thumbnail(for: url) != nil else { NSSound.beep(); return }
            draft.style.kind = .image
            draft.style.imagePath = url.path
            rememberImage()
        }
    }

    private func closeTool() {
        if let close { close() } else { dismiss() }
    }
}
