// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics
import SwiftUI

/// Placement calculations for the CleanShot X-style floating preview window.
enum ScrollingCapturePlacement {
    static let defaultPreviewWidth: CGFloat = 220
    static let defaultPreviewHeight: CGFloat = 356
    static let defaultPreviewGap: CGFloat = 14
    static let defaultMargin: CGFloat = 16

    static func calculate(
        selectionRect: CGRect,
        visibleFrame: CGRect,
        previewWidth: CGFloat = defaultPreviewWidth,
        previewHeight: CGFloat = defaultPreviewHeight,
        gap: CGFloat = defaultPreviewGap,
        margin: CGFloat = defaultMargin
    ) -> CGRect {
        let isFullScreen = selectionRect.width >= visibleFrame.width - 32
            && selectionRect.height >= visibleFrame.height - 32

        if isFullScreen {
            let x = visibleFrame.maxX - previewWidth - margin
            let y = visibleFrame.minY + margin
            return CGRect(x: x, y: y, width: previewWidth, height: previewHeight)
        }

        // Try right side of the selection first
        let rightX = selectionRect.maxX + gap
        let leftX = selectionRect.minX - previewWidth - gap

        let chosenX: CGFloat
        let isSide: Bool

        if rightX + previewWidth <= visibleFrame.maxX - margin {
            chosenX = rightX
            isSide = true
        } else if leftX >= visibleFrame.minX + margin {
            chosenX = leftX
            isSide = true
        } else {
            // Neither side fits: fall back to bottom right
            chosenX = visibleFrame.maxX - previewWidth - margin
            isSide = false
        }

        if isSide {
            let topY = min(selectionRect.maxY, visibleFrame.maxY - margin)
            let y = max(visibleFrame.minY + margin, topY - previewHeight)
            return CGRect(x: chosenX, y: y, width: previewWidth, height: previewHeight)
        } else {
            let y = visibleFrame.minY + margin
            return CGRect(x: chosenX, y: y, width: previewWidth, height: previewHeight)
        }
    }
}

@MainActor
final class ScrollingCaptureViewModel: ObservableObject {
    @Published var cgImage: CGImage?
    @Published var width: Int = 0
    @Published var height: Int = 0
    @Published var isFinishing: Bool = false

    let finishTitle: String
    let cancelTitle: String
    let onFinish: () -> Void
    let onCancel: () -> Void

    init(finishTitle: String,
         cancelTitle: String,
         onFinish: @escaping () -> Void,
         onCancel: @escaping () -> Void) {
        self.finishTitle = finishTitle
        self.cancelTitle = cancelTitle
        self.onFinish = onFinish
        self.onCancel = onCancel
    }

    func update(image: CGImage?, height: Int) {
        self.height = height
        if let image {
            self.width = image.width
            self.cgImage = image
        }
    }
}

struct ScrollingCapturePreviewView: View {
    @ObservedObject var model: ScrollingCaptureViewModel
    private let viewportWidth: CGFloat = ScrollingCapturePlacement.defaultPreviewWidth - 24
    private let viewportHeight: CGFloat = 260

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
                    .shadow(color: Color.green.opacity(0.6), radius: 3)
                Text(FeatureStrings.screenshot(L10n.shared.language).scrollingCaptureTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if model.height > 0 {
                    Text("\(model.width > 0 ? "\(model.width) × " : "")\(model.height) px")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1), in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Dynamic Preview Viewport (content stretches as we scroll)
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.35))

                if let cgImage = model.cgImage {
                    let contentH = CGFloat(max(1, model.height)) / CGFloat(max(1, model.width)) * viewportWidth
                    let isOverflowing = contentH > viewportHeight

                    Image(decorative: cgImage, scale: 1.0, orientation: .up)
                        .resizable()
                        .interpolation(.medium)
                        .aspectRatio(contentMode: .fill)
                        .frame(width: viewportWidth, height: contentH)
                        .frame(width: viewportWidth, height: viewportHeight, alignment: isOverflowing ? .bottom : .top)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(.secondary)
                        Text(FeatureStrings.screenshot(L10n.shared.language).scrollingCaptureButton)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: viewportWidth, height: viewportHeight)
            .padding(.horizontal, 12)

            // Footer Action Toolbar
            HStack(spacing: 10) {
                Button(action: model.onCancel) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text(model.cancelTitle)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)

                Button(action: model.onFinish) {
                    HStack(spacing: 5) {
                        if model.isFinishing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                        }
                        Text(model.finishTitle)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(model.isFinishing)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .frame(width: ScrollingCapturePlacement.defaultPreviewWidth, height: ScrollingCapturePlacement.defaultPreviewHeight)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Manages the floating preview window for scrolling capture.
@MainActor
final class ScrollingCaptureOverlayController {
    static let shared = ScrollingCaptureOverlayController()

    nonisolated(unsafe) private(set) static var activePreviewWindowNumber: Int?
    nonisolated(unsafe) private(set) static var activeWindowIDs: Set<CGWindowID> = []

    private var previewPanel: ScrollingCapturePanel?
    private var viewModel: ScrollingCaptureViewModel?

    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?

    private init() {}

    var previewWindowNumber: Int? {
        guard let previewPanel, previewPanel.isVisible else { return nil }
        return previewPanel.windowNumber
    }

    var windowIDs: Set<CGWindowID> {
        var ids: Set<CGWindowID> = []
        if let previewPanel, previewPanel.windowNumber > 0 {
            ids.insert(CGWindowID(previewPanel.windowNumber))
        }
        return ids
    }

    private func syncActiveIDs() {
        Self.activePreviewWindowNumber = previewPanel?.windowNumber
        Self.activeWindowIDs = windowIDs
    }

    func show(region: RecorderSupport.Region?,
              message: String,
              finishTitle: String,
              cancelTitle: String,
              onFinish: @escaping () -> Void,
              onCancel: @escaping () -> Void) {
        dismiss()

        let screen = region.flatMap { reg in
            NSScreen.screens.first { $0.displayID == reg.displayID }
        } ?? NSScreen.main ?? NSScreen.screens[0]

        let visibleFrame = screen.visibleFrame
        let selectionRect = region?.anchorRect ?? screen.frame

        // 1. Setup ViewModel
        let model = ScrollingCaptureViewModel(
            finishTitle: finishTitle,
            cancelTitle: cancelTitle,
            onFinish: { [weak self] in
                guard let self, let vm = self.viewModel, !vm.isFinishing else { return }
                vm.isFinishing = true
                onFinish()
            },
            onCancel: {
                onCancel()
            }
        )
        self.viewModel = model

        // 2. Calculate stable placement
        let frame = ScrollingCapturePlacement.calculate(
            selectionRect: selectionRect,
            visibleFrame: visibleFrame
        )

        // 3. Create and Show Preview Panel
        let panel = ScrollingCapturePanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let previewView = ScrollingCapturePreviewView(model: model)
        let hostingView = ScrollingCaptureHostingView(rootView: AnyView(previewView))
        panel.contentView = hostingView
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()

        self.previewPanel = panel

        // 4. Install keyboard monitors for Esc / Return
        installKeyboardMonitors(onFinish: { [weak self] in
            guard let self, let vm = self.viewModel, !vm.isFinishing else { return }
            vm.isFinishing = true
            onFinish()
        }, onCancel: onCancel)

        syncActiveIDs()
    }

    func update(image: CGImage?, height: Int) {
        viewModel?.update(image: image, height: height)
    }

    func markFinishing() {
        viewModel?.isFinishing = true
    }

    func dismiss() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        if let globalKeyMonitor {
            NSEvent.removeMonitor(globalKeyMonitor)
            self.globalKeyMonitor = nil
        }

        previewPanel?.orderOut(nil)
        previewPanel?.contentView = nil
        previewPanel = nil

        viewModel = nil

        Self.activePreviewWindowNumber = nil
        Self.activeWindowIDs = []
    }

    private func installKeyboardMonitors(onFinish: @escaping () -> Void, onCancel: @escaping () -> Void) {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 53: // Esc
                onCancel()
                return nil
            case 36, 76: // Return / Enter
                onFinish()
                return nil
            default:
                return event
            }
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 53: // Esc
                Task { @MainActor in onCancel() }
            case 36, 76: // Return / Enter
                Task { @MainActor in onFinish() }
            default:
                break
            }
        }
    }
}

final class ScrollingCapturePanel: OverlayPanel {
    override var canBecomeKey: Bool { true }
}

final class ScrollingCaptureHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
