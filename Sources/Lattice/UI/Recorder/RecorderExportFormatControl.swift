// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The editor's one export options menu, beside the speed control: video
/// quality, then the GIF's size and frame rate. The toolbar keeps its own
/// video and GIF actions, so there is no separate format switch. Changes
/// apply to this recording only; Settings holds the defaults new ones start from.
struct RecorderExportOptionsMenu: View {
    @ObservedObject var model: RecorderEditorModel
    @ObservedObject private var l10n = L10n.shared
    @State private var showsCustomSize = false
    @State private var draftPercent = 75.0

    static let gifSizePresets = [100, 75, 50]
    static let gifFrameRatePresets = [8, 12, 15, 24, 30, 50]

    private var strings: RecorderFeatureStrings { FeatureStrings.recorder(l10n.language) }
    private var formatStrings: RecorderExportFormatStrings { FeatureStrings.recorderExportFormat(l10n.language) }

    private func qualityTitle(_ quality: RecorderSupport.Quality) -> String {
        switch quality {
        case .high: return strings.qualityHigh
        case .balanced: return strings.qualityBalanced
        case .small: return strings.qualitySmall
        }
    }

    private func gifTitle(_ percent: Int) -> String {
        switch percent {
        case 100: return strings.qualityHigh
        case 75: return strings.qualityBalanced
        case 50: return strings.qualitySmall
        default: return formatStrings.customSize
        }
    }

    private func dimensions(_ size: CGSize) -> String {
        guard size.width > 0, size.height > 0 else { return "" }
        return "\(Int(size.width)) × \(Int(size.height))"
    }

    /// What the video preset actually produces for this recording. A file
    /// size would be a guess; the resolution is a fact.
    private var title: String {
        let video = model.exportSize(for: .video, canvas: model.exportCanvasSize)
        return qualityTitle(model.document.resolvedQuality) + "  " + dimensions(video)
    }

    var body: some View {
        Menu {
            Picker(strings.qualityLabel, selection: Binding(
                get: { model.document.quality },
                set: { value in
                    guard !model.isExporting else { return }
                    var next = model.document
                    next.quality = value
                    model.document = next
                })) {
                ForEach(RecorderSupport.Quality.allCases, id: \.rawValue) { quality in
                    Text(qualityTitle(quality)).tag(quality.rawValue)
                }
            }
            .pickerStyle(.inline)
            Divider()
            // A Picker provides the native menu checkmark for each preset.
            Picker(formatStrings.gifSize, selection: Binding(
                get: { model.document.resolvedGIFScalePercent },
                set: { model.setGIFScalePercent($0) })) {
                ForEach(Self.gifSizePresets, id: \.self) { percent in
                    Text(gifTitle(percent) + " (\(percent)%)").tag(percent)
                }
                if !Self.gifSizePresets.contains(model.document.resolvedGIFScalePercent) {
                    Text(formatStrings.customSize + " (\(model.document.resolvedGIFScalePercent)%)")
                        .tag(model.document.resolvedGIFScalePercent)
                }
            }
            .pickerStyle(.inline)
            Button(formatStrings.customSize + "…") {
                draftPercent = Double(model.document.resolvedGIFScalePercent)
                showsCustomSize = true
            }
            Divider()
            Picker(formatStrings.frameRate, selection: Binding(
                get: { model.document.resolvedGIFFrameRate },
                set: { model.setGIFFrameRate($0) })) {
                ForEach(Self.gifFrameRatePresets, id: \.self) { rate in
                    Text("\(rate) FPS").tag(rate)
                }
                if !Self.gifFrameRatePresets.contains(model.document.resolvedGIFFrameRate) {
                    Text("\(model.document.resolvedGIFFrameRate) FPS").tag(model.document.resolvedGIFFrameRate)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(title, systemImage: "slider.horizontal.3")
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 240, alignment: .leading)
        }
        // Pin the menu itself so it cannot consume its row's free width.
        .menuStyle(.borderlessButton)
        .fixedSize()
        .screenshotSafeHelp(strings.qualityLabel)
        .accessibilityLabel(strings.qualityLabel)
        .accessibilityValue(title)
        .disabled(model.isExporting)
        .popover(isPresented: $showsCustomSize) { customSizePopover }
    }

    private var customSizePopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(formatStrings.customSize).font(.headline)
            HStack {
                Text("\(Int(draftPercent))%")
                Spacer()
                Text(dimensions(RecorderSupport.gifOutputSize(
                    source: model.exportCanvasSize, scalePercent: Int(draftPercent))))
            }
            .monospacedDigit()
            Slider(value: $draftPercent, in: 1...100, step: 1)
                .accessibilityLabel(formatStrings.gifSize)
                .accessibilityValue("\(Int(draftPercent))%")
            HStack {
                Spacer()
                Button(strings.cancelButton, role: .cancel) { showsCustomSize = false }
                Button(FeatureStrings.screenshot(l10n.language).done) {
                    model.setGIFScalePercent(Int(draftPercent))
                    showsCustomSize = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 280)
        .disabled(model.isExporting)
    }
}
