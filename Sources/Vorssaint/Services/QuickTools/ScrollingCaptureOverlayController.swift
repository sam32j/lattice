// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreGraphics
import SwiftUI

/// Placement calculations for the CleanShot X-style floating preview window.
enum ScrollingCapturePlacement {
    static let defaultPreviewWidth: CGFloat = 220
    static let defaultPreviewGap: CGFloat = 14
    static let defaultMargin: CGFloat = 16
    static let maxPreviewHeight: CGFloat = 460

    struct PlacementResult {
        let frame: CGRect
        let isFullScreen: Bool
        let isSidePlacement: Bool
        let initialTopY: CGFloat
    }

    static func calculate(
        selectionRect: CGRect,
        visibleFrame: CGRect,
        previewWidth: CGFloat = defaultPreviewWidth,
        initialHeight: CGFloat,
        gap: CGFloat = defaultPreviewGap,
        margin: CGFloat = defaultMargin
    ) -> PlacementResult {
        let isFullScreen = selectionRect.width >= visibleFrame.width - 32
            && selectionRect.height >= visibleFrame.height - 32

        if isFullScreen {
            let x = visibleFrame.maxX - previewWidth - margin
            let y = visibleFrame.minY + margin
            return PlacementResult(
                frame: CGRect(x: x, y: y, width: previewWidth, height: initialHeight),
                isFullScreen: true,
                isSidePlacement: false,
                initialTopY: y + initialHeight
            )
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
            return PlacementResult(
                frame: CGRect(x: chosenX, y: y, width: previewWidth, height: initialHeight),
                isFullScreen: false,
                isSidePlacement: true,
                initialTopY: topY
            )
        } else {
            let y = visibleFrame.minY + margin
            return PlacementResult(
                frame: CGRect(x: chosenX, y: y, width: previewWidth, height: initialHeight),
                isFullScreen: false,
                isSidePlacement: false,
                initialTopY: y + initialHeight
            )
        }
    }
}

/// Selection boundary outline placed directly over the scroll region.
final class ScrollingSelectionBorderView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let rect = bounds.insetBy(dx: 1.5, dy: 1.5)
        guard rect.width > 4, rect.height > 4 else { return }

        let path = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        ctx.addPath(path)
        ctx.setStrokeColor(NSColor.controlAccentColor.withAlphaComponent(0.85).cgColor)
        ctx.setLineWidth(2.5)
        ctx.strokePath()

        // Crisp corner accents
        let bracketLen: CGFloat = min(16, min(rect.width, rect.height) / 3)
        ctx.setStrokeColor(NSColor.white.cgColor)
        ctx.setLineWidth(3.0)

        // Top-left
        ctx.move(to: CGPoint(x: rect.minX, y: rect.maxY - bracketLen))
        ctx.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        ctx.addLine(to: CGPoint(x: rect.minX + bracketLen, y: rect.maxY))

        // Top-right
        ctx.move(to: CGPoint(x: rect.maxX - bracketLen, y: rect.maxY))
        ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bracketLen))

        // Bottom-left
        ctx.move(to: CGPoint(x: rect.minX, y: rect.minY + bracketLen))
        ctx.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        ctx.addLine(to: CGPoint(x: rect.minX + bracketLen, y: rect.minY))

        // Bottom-right
        ctx.move(to: CGPoint(x: rect.maxX - bracketLen, y: rect.minY))
        ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + bracketLen))

        ctx.strokePath()
    }
}

@MainActor
final class ScrollingCaptureViewModel: ObservableObject {
    @Published var nsImage: NSImage?
    @Published var width: Int = 0
    @Published var height: Int = 0
    @Published var isFinishing: Bool = false
    @Published var contentHeight: CGFloat = 160

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
            self.nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))

            let viewportWidth: CGFloat = ScrollingCapturePlacement.defaultPreviewWidth - 24
            let aspectRatio = CGFloat(max(1, height)) / CGFloat(max(1, image.width))
            let targetHeight = viewportWidth * aspectRatio
            self.contentHeight = max(110, min(ScrollingCapturePlacement.maxPreviewHeight, targetHeight))
        }
    }
}

struct ScrollingCapturePreviewView: View {
    @ObservedObject var model: ScrollingCaptureViewModel

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

            // Dynamic Preview Viewport (stretches as we scroll)
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                if let nsImage = model.nsImage {
                    GeometryReader { geo in
                        ScrollViewReader { proxy in
                            ScrollView(.vertical, showsIndicators: false) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geo.size.width)
                                    .id("bottom")
                            }
                            .onChange(of: model.height) {
                                withAnimation(.easeOut(duration: 0.1)) {
                                    proxy.scrollTo("bottom", anchor: .bottom)
                                }
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
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
            .frame(height: model.contentHeight)
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
        .frame(width: ScrollingCapturePlacement.defaultPreviewWidth)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 8)
    }
}

/// Manages the floating preview window and selection border for scrolling capture.
@MainActor
final class ScrollingCaptureOverlayController {
    static let shared = ScrollingCaptureOverlayController()

    nonisolated(unsafe) private(set) static var activePreviewWindowNumber: Int?
    nonisolated(unsafe) private(set) static var activeWindowIDs: Set<CGWindowID> = []

    private var previewPanel: ScrollingCapturePanel?
    private var borderPanel: NSPanel?
    private var viewModel: ScrollingCaptureViewModel?

    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?

    private var placement: ScrollingCapturePlacement.PlacementResult?
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
        if let borderPanel, borderPanel.windowNumber > 0 {
            ids.insert(CGWindowID(borderPanel.windowNumber))
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

        // 1. Show Selection Border (if not full screen)
        let isFullScreen = selectionRect.width >= visibleFrame.width - 32
            && selectionRect.height >= visibleFrame.height - 32
        if !isFullScreen {
            showBorder(selectionRect: selectionRect)
        }

        // 2. Setup ViewModel
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

        // 3. Calculate initial placement
        let initialViewportHeight: CGFloat = 160
        let chromeHeight: CGFloat = 104
        let initialPanelHeight = initialViewportHeight + chromeHeight
        let calc = ScrollingCapturePlacement.calculate(
            selectionRect: selectionRect,
            visibleFrame: visibleFrame,
            initialHeight: initialPanelHeight
        )
        self.placement = calc

        // 4. Create and Show Preview Panel
        let panel = ScrollingCapturePanel(
            contentRect: calc.frame,
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
        panel.setFrame(calc.frame, display: true)
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
        guard let viewModel else { return }
        viewModel.update(image: image, height: height)

        guard let panel = previewPanel, let calc = placement else { return }

        let chromeHeight: CGFloat = 104
        let newPanelHeight = viewModel.contentHeight + chromeHeight
        let currentFrame = panel.frame

        let newY: CGFloat
        if calc.isSidePlacement {
            // Anchor to top edge, stretch downwards
            let targetY = calc.initialTopY - newPanelHeight
            newY = max(visibleFrame.minY + ScrollingCapturePlacement.defaultMargin, targetY)
        } else {
            // Bottom-right placement
            newY = visibleFrame.minY + ScrollingCapturePlacement.defaultMargin
        }

        let newFrame = NSRect(
            x: currentFrame.minX,
            y: newY,
            width: currentFrame.width,
            height: newPanelHeight
        )

        if abs(panel.frame.height - newPanelHeight) > 1 || abs(panel.frame.origin.y - newY) > 1 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(newFrame, display: true)
            }
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

        borderPanel?.orderOut(nil)
        borderPanel?.contentView = nil
        borderPanel = nil

        previewPanel?.orderOut(nil)
        previewPanel?.contentView = nil
        previewPanel = nil

        viewModel = nil
        placement = nil

        Self.activePreviewWindowNumber = nil
        Self.activeWindowIDs = []
    }

    private func showBorder(selectionRect: CGRect) {
        let borderInset: CGFloat = 2
        let borderFrame = selectionRect.insetBy(dx: -borderInset, dy: -borderInset)
        let panel = NSPanel(
            contentRect: borderFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        let borderView = ScrollingSelectionBorderView(frame: NSRect(origin: .zero, size: borderFrame.size))
        panel.contentView = borderView
        panel.setFrame(borderFrame, display: true)
        panel.orderFrontRegardless()

        self.borderPanel = panel
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
