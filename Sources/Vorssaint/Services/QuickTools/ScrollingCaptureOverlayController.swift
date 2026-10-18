// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics
import SwiftUI

/// Placement calculations for the CleanShot X-style floating preview window.
enum ScrollingCapturePlacement {
    static let defaultPreviewWidth: CGFloat = 220
    static let minPreviewHeight: CGFloat = 64
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
            let topY = visibleFrame.maxY - margin
            let y = max(visibleFrame.minY + margin, topY - initialHeight)
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
            // Neither side fits: fall back to top right
            chosenX = visibleFrame.maxX - previewWidth - margin
            isSide = false
        }

        let topY = isSide
            ? min(selectionRect.maxY, visibleFrame.maxY - margin)
            : (visibleFrame.maxY - margin)
        let y = max(visibleFrame.minY + margin, topY - initialHeight)
        return CGRect(x: chosenX, y: y, width: previewWidth, height: initialHeight)
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
         initialImage: CGImage? = nil,
         initialWidth: Int = 0,
         initialHeightPixels: Int = 0,
         onFinish: @escaping () -> Void,
         onCancel: @escaping () -> Void) {
        self.finishTitle = finishTitle
        self.cancelTitle = cancelTitle
        self.previewHeight = initialHeight
        self.cgImage = initialImage
        self.width = initialWidth
        self.height = initialHeightPixels
        self.onFinish = onFinish
        self.onCancel = onCancel
    }

    func update(image: CGImage, width: Int, height: Int, previewHeight: CGFloat) {
        self.previewHeight = previewHeight
        self.width = width
        self.height = height
        self.cgImage = image
    }
}

/// Borderless edge-to-edge preview image with floating indicator and control pills overlayed directly on top.
struct ScrollingCapturePreviewView: View {
    @ObservedObject var model: ScrollingCaptureViewModel
    private let previewWidth: CGFloat = ScrollingCapturePlacement.defaultPreviewWidth
    private let maxHeight: CGFloat = ScrollingCapturePlacement.maxPreviewHeight

    var body: some View {
        let cardH = model.previewHeight

        ZStack(alignment: .top) {
            // Background card surface
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.12, opacity: 0.92))
                .frame(width: previewWidth, height: cardH)

            // Edge-to-edge Preview Image
            if let cgImage = model.cgImage {
                let contentH = CGFloat(cgImage.height) / CGFloat(max(1, cgImage.width)) * previewWidth
                let isOverflowing = contentH > (maxHeight + 1.0)

                Image(decorative: cgImage, scale: 1.0, orientation: .up)
                    .resizable()
                    .interpolation(.medium)
                    .frame(width: previewWidth, height: contentH)
                    .frame(width: previewWidth, height: cardH, alignment: isOverflowing ? .bottom : .top)
                    .clipped()
            } else {
                ZStack {
                    Color.black.opacity(0.6)
                    ProgressView()
                        .controlSize(.small)
                }
                .frame(width: previewWidth, height: cardH)
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
        .frame(width: previewWidth, height: cardH)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

/// Manages the borderless floating preview window for scrolling capture.
@MainActor
final class ScrollingCaptureOverlayController {
    static let shared = ScrollingCaptureOverlayController()

    nonisolated(unsafe) private(set) static var activePreviewWindowNumber: Int?
    nonisolated(unsafe) private(set) static var activeWindowIDs: Set<CGWindowID> = []

    private var previewPanel: ScrollingCapturePanel?
    private var backdropPanels: [ScrollingCaptureBackdropPanel] = []
    private var viewModel: ScrollingCaptureViewModel?

    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?

    private var visibleFrame: CGRect = .zero
    private var anchorTopY: CGFloat = 0

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
        for panel in backdropPanels where panel.windowNumber > 0 {
            ids.insert(CGWindowID(panel.windowNumber))
        }
        return ids
    }

    private func syncActiveIDs() {
        Self.activePreviewWindowNumber = previewPanel?.windowNumber
        Self.activeWindowIDs = windowIDs
    }

    func show(region: RecorderSupport.Region?,
              initialImage: CGImage? = nil,
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

        // 1. Create full-screen dim backdrop panels for all displays, punching out the selected region
        let targetDisplayID = region?.displayID ?? screen.displayID
        for s in NSScreen.screens {
            let punchOut = (s.displayID == targetDisplayID) ? (region?.anchorRect ?? .zero) : .zero
            let bgPanel = ScrollingCaptureBackdropPanel(screenFrame: s.frame, punchOutRect: punchOut)
            bgPanel.orderFrontRegardless()
            backdropPanels.append(bgPanel)
        }

        // 2. Compute initial aspect-ratio-matched height
        let previewWidth = ScrollingCapturePlacement.defaultPreviewWidth
        let initialWidth = initialImage?.width ?? max(1, Int(selectionRect.width))
        let initialHeightPixels = initialImage?.height ?? max(1, Int(selectionRect.height))
        let aspect = CGFloat(initialHeightPixels) / CGFloat(max(1, initialWidth))
        let initialHeight = min(
            ScrollingCapturePlacement.maxPreviewHeight,
            max(ScrollingCapturePlacement.minPreviewHeight, round(previewWidth * aspect))
        )

        // 3. Setup ViewModel
        let model = ScrollingCaptureViewModel(
            finishTitle: finishTitle,
            cancelTitle: cancelTitle,
            initialHeight: initialHeight,
            initialImage: initialImage,
            initialWidth: initialWidth,
            initialHeightPixels: initialHeightPixels,
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

        // 4. Calculate initial placement
        let frame = ScrollingCapturePlacement.calculate(
            selectionRect: selectionRect,
            visibleFrame: visibleFrame,
            previewWidth: previewWidth,
            initialHeight: initialHeight
        )
        self.anchorTopY = frame.maxY

        // 5. Create and Show Preview Panel above backdrop
        let panel = ScrollingCapturePanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()) + 1)
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

        // 6. Install keyboard monitors for Esc / Return
        installKeyboardMonitors(onFinish: { [weak self] in
            guard let self, let vm = self.viewModel, !vm.isFinishing else { return }
            vm.isFinishing = true
            onFinish()
        }, onCancel: onCancel)

        syncActiveIDs()
    }

    func update(image: CGImage?, height: Int) {
        guard let panel = previewPanel, let model = viewModel else { return }
        guard let image else { return }

        let previewWidth = ScrollingCapturePlacement.defaultPreviewWidth
        let imageWidth = max(1, image.width)
        let imageHeight = max(image.height, height)

        let aspect = CGFloat(imageHeight) / CGFloat(imageWidth)
        let rawH = previewWidth * aspect

        // If the user manually dragged the panel, update anchorTopY to the new user-dragged position
        let currentMaxY = panel.frame.maxY
        if abs(currentMaxY - self.anchorTopY) > 6 {
            self.anchorTopY = currentMaxY
        }

        // Available height from anchorTopY down to the bottom margin of the screen
        let maxAllowedHeight = min(
            ScrollingCapturePlacement.maxPreviewHeight,
            max(ScrollingCapturePlacement.minPreviewHeight, self.anchorTopY - (visibleFrame.minY + ScrollingCapturePlacement.defaultMargin))
        )

        // Monotonically non-decreasing: smoothly grows downwards as you scroll, never shrinks or oscillates
        let targetHeight = min(
            maxAllowedHeight,
            max(model.previewHeight, round(rawH))
        )

        model.update(image: image, width: imageWidth, height: imageHeight, previewHeight: targetHeight)

        if panel.frame.height != targetHeight {
            let newY = self.anchorTopY - targetHeight
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            panel.setFrame(NSRect(x: panel.frame.origin.x, y: newY, width: previewWidth, height: targetHeight), display: true)
            CATransaction.commit()
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

        backdropPanels.forEach { $0.orderOut(nil) }
        backdropPanels.removeAll()

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

final class ScrollingCaptureBackdropPanel: NSPanel {
    init(screenFrame: CGRect, punchOutRect: CGRect) {
        super.init(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isReleasedWhenClosed = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        canHide = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let view = ScrollingCaptureBackdropView(frame: CGRect(origin: .zero, size: screenFrame.size),
                                                screenFrame: screenFrame,
                                                punchOutRect: punchOutRect)
        contentView = view
        setFrame(screenFrame, display: true)
    }
}

final class ScrollingCaptureBackdropView: NSView {
    private let screenFrame: CGRect
    private let punchOutRect: CGRect
    private let shapeLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()

    init(frame: CGRect, screenFrame: CGRect, punchOutRect: CGRect) {
        self.screenFrame = screenFrame
        self.punchOutRect = punchOutRect
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(shapeLayer)
        layer?.addSublayer(borderLayer)
        updatePath()
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        updatePath()
    }

    private func updatePath() {
        shapeLayer.frame = bounds
        shapeLayer.fillColor = CGColor(gray: 0, alpha: 0.32)
        shapeLayer.fillRule = .evenOdd

        borderLayer.frame = bounds
        borderLayer.fillColor = nil
        borderLayer.strokeColor = CGColor(srgbRed: 0.35, green: 0.62, blue: 1, alpha: 0.85)
        borderLayer.lineWidth = 2.0

        let path = CGMutablePath()
        path.addRect(bounds)

        if punchOutRect.width > 0 && punchOutRect.height > 0 {
            let localX = punchOutRect.minX - screenFrame.minX
            let localY = punchOutRect.minY - screenFrame.minY
            let localPunchOut = CGRect(x: localX, y: localY, width: punchOutRect.width, height: punchOutRect.height)
            path.addRect(localPunchOut)

            let borderPath = CGMutablePath()
            borderPath.addRect(localPunchOut)
            borderLayer.path = borderPath
        } else {
            borderLayer.path = nil
        }
        shapeLayer.path = path
    }
}
