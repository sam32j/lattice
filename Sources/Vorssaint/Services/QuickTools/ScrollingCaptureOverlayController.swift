// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics
import SwiftUI

/// Placement calculations for the CleanShot X-style floating preview window.
enum ScrollingCapturePlacement {
    static let defaultPreviewWidth: CGFloat = 220
    static let minPreviewHeight: CGFloat = 130
    static let maxPreviewHeight: CGFloat = 460
    static let defaultPreviewGap: CGFloat = 14
    static let defaultMargin: CGFloat = 16

    static func calculate(
        selectionRect: CGRect,
        visibleFrame: CGRect,
        previewWidth: CGFloat = defaultPreviewWidth,
        initialHeight: CGFloat,
        gap: CGFloat = defaultPreviewGap,
        margin: CGFloat = defaultMargin
    ) -> CGRect {
        let isFullScreen = selectionRect.width >= visibleFrame.width - 32
            && selectionRect.height >= visibleFrame.height - 32

        if isFullScreen {
            let x = visibleFrame.maxX - previewWidth - margin
            let y = visibleFrame.minY + margin
            return CGRect(x: x, y: y, width: previewWidth, height: initialHeight)
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
            let y = max(visibleFrame.minY + margin, topY - initialHeight)
            return CGRect(x: chosenX, y: y, width: previewWidth, height: initialHeight)
        } else {
            let y = visibleFrame.minY + margin
            return CGRect(x: chosenX, y: y, width: previewWidth, height: initialHeight)
        }
    }
}

@MainActor
final class ScrollingCaptureViewModel: ObservableObject {
    @Published var cgImage: CGImage?
    @Published var width: Int = 0
    @Published var height: Int = 0
    @Published var isFinishing: Bool = false
    @Published var previewHeight: CGFloat = 160

    let finishTitle: String
    let cancelTitle: String
    let onFinish: () -> Void
    let onCancel: () -> Void

    init(finishTitle: String,
         cancelTitle: String,
         initialHeight: CGFloat,
         onFinish: @escaping () -> Void,
         onCancel: @escaping () -> Void) {
        self.finishTitle = finishTitle
        self.cancelTitle = cancelTitle
        self.previewHeight = initialHeight
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

/// Borderless edge-to-edge preview image with floating indicator and control pills overlayed directly on top.
struct ScrollingCapturePreviewView: View {
    @ObservedObject var model: ScrollingCaptureViewModel
    private let previewWidth: CGFloat = ScrollingCapturePlacement.defaultPreviewWidth

    var body: some View {
        ZStack(alignment: .top) {
            // Edge-to-edge Preview Image
            if let cgImage = model.cgImage {
                let contentH = CGFloat(max(1, model.height)) / CGFloat(max(1, model.width)) * previewWidth
                let isOverflowing = contentH > model.previewHeight

                Image(decorative: cgImage, scale: 1.0, orientation: .up)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: previewWidth, height: max(model.previewHeight, contentH))
                    .frame(width: previewWidth, height: model.previewHeight, alignment: isOverflowing ? .bottom : .top)
                    .clipped()
            } else {
                ZStack {
                    Color.black.opacity(0.4)
                    VStack(spacing: 6) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(FeatureStrings.screenshot(L10n.shared.language).scrollingCaptureButton)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(width: previewWidth, height: model.previewHeight)
            }

            // Top Overlay: Opaque pill with green light indicator and dimension badge
            if model.height > 0 {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                        .shadow(color: Color.green.opacity(0.85), radius: 3)
                    Text("\(model.width > 0 ? "\(model.width) × " : "")\(model.height) px")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(Color.black.opacity(0.75), in: Capsule())
                .padding(.top, 8)
            }

            // Bottom Overlay: Opaque pill with controls (Cancel and Done)
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    Button(action: model.onCancel) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                            Text(model.cancelTitle)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)

                    Button(action: model.onFinish) {
                        HStack(spacing: 4) {
                            if model.isFinishing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            Text(model.finishTitle)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isFinishing)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(5)
                .background(Color.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.bottom, 8)
            }
        }
        .frame(width: previewWidth, height: model.previewHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Manages the borderless floating preview window for scrolling capture.
@MainActor
final class ScrollingCaptureOverlayController {
    static let shared = ScrollingCaptureOverlayController()

    nonisolated(unsafe) private(set) static var activePreviewWindowNumber: Int?
    nonisolated(unsafe) private(set) static var activeWindowIDs: Set<CGWindowID> = []

    private var previewPanel: ScrollingCapturePanel?
    private var viewModel: ScrollingCaptureViewModel?

    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?

    private var visibleFrame: CGRect = .zero

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

        self.visibleFrame = screen.visibleFrame
        let selectionRect = region?.anchorRect ?? screen.frame

        // 1. Compute initial aspect-ratio-matched height
        let previewWidth = ScrollingCapturePlacement.defaultPreviewWidth
        let aspect = selectionRect.height / max(1, selectionRect.width)
        let initialHeight = min(
            ScrollingCapturePlacement.maxPreviewHeight,
            max(ScrollingCapturePlacement.minPreviewHeight, round(previewWidth * aspect))
        )

        // 2. Setup ViewModel
        let model = ScrollingCaptureViewModel(
            finishTitle: finishTitle,
            cancelTitle: cancelTitle,
            initialHeight: initialHeight,
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

        // 3. Calculate initial placement
        let frame = ScrollingCapturePlacement.calculate(
            selectionRect: selectionRect,
            visibleFrame: visibleFrame,
            previewWidth: previewWidth,
            initialHeight: initialHeight
        )

        // 4. Create and Show Preview Panel
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

        // 5. Install keyboard monitors for Esc / Return
        installKeyboardMonitors(onFinish: { [weak self] in
            guard let self, let vm = self.viewModel, !vm.isFinishing else { return }
            vm.isFinishing = true
            onFinish()
        }, onCancel: onCancel)

        syncActiveIDs()
    }

    func update(image: CGImage?, height: Int) {
        guard let panel = previewPanel, let model = viewModel else { return }
        model.update(image: image, height: height)

        let previewWidth = ScrollingCapturePlacement.defaultPreviewWidth
        let imageWidth = max(1, image?.width ?? model.width)
        let imageHeight = height > 0 ? height : (image?.height ?? model.height)

        let aspect = CGFloat(imageHeight) / CGFloat(imageWidth)
        let rawH = previewWidth * aspect
        let newHeight = min(
            ScrollingCapturePlacement.maxPreviewHeight,
            max(ScrollingCapturePlacement.minPreviewHeight, round(rawH))
        )

        model.previewHeight = newHeight

        // Anchor to current top edge and stretch downwards smoothly without animation oscillation
        if abs(panel.frame.height - newHeight) >= 2 {
            let currentX = panel.frame.origin.x
            let currentTopY = panel.frame.maxY
            let newY = currentTopY - newHeight
            panel.setFrame(NSRect(x: currentX, y: newY, width: previewWidth, height: newHeight), display: true)
        }
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
