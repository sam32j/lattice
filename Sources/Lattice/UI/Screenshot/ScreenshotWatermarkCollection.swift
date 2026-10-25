// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// An image-only collection. Text belongs to the composer, not a preset grid.
struct ScreenshotWatermarkCollection: View {
    @Binding var selection: ScreenshotSupport.WatermarkStyle
    let presets: [ScreenshotSupport.WatermarkStyle]
    let strings: ScreenshotFeatureStrings
    let addImage: () -> Void
    let remove: (Int) -> Void

    private var entries: [(index: Int, style: ScreenshotSupport.WatermarkStyle)] {
        presets.enumerated().filter { $0.element.kind == .image }
            .map { ($0.offset, $0.element) }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(entries, id: \.index) { entry in
                    presetButton(entry.style, index: entry.index)
                }
                Button(action: addImage) {
                    Image(systemName: "plus")
                        .frame(maxWidth: .infinity).frame(height: 42)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.primary.opacity(0.16),
                                          style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(.plain)
                .screenshotIconHover()
                .screenshotSafeHelp(strings.backdropImageButton)
                .accessibilityLabel(strings.backdropImageButton)
            }
            .padding(2)
        }
        .frame(height: min(148, CGFloat((entries.count + 4) / 4) * 50))
    }

    private func presetButton(_ style: ScreenshotSupport.WatermarkStyle, index: Int) -> some View {
        let selected = selection.imagePath == style.imagePath
        let name = URL(fileURLWithPath: style.imagePath ?? "").lastPathComponent
        return Button {
            if style.opacity == 0 {
                selection.kind = .image
                selection.imagePath = style.imagePath
            } else {
                selection = style.sanitized()
            }
        } label: {
            Group {
                if let path = style.imagePath,
                   let thumbnail = BackdropPickerAssets.thumbnail(for: URL(fileURLWithPath: path)) {
                    Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fit).padding(4)
                } else {
                    Image(systemName: "photo.badge.exclamationmark").foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 42)
            .background(Color.gray.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.16), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .screenshotIconHover()
        .screenshotSafeHelp(name)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .contextMenu { Button(strings.backdropDeletePreset, role: .destructive) { remove(index) } }
    }
}
