// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import UniformTypeIdentifiers

/// Screenshot annotation editor with a tool rail, actions, contextual styles
/// and a shared renderer for the canvas and exported image.
struct ScreenshotEditorView: View {
    @ObservedObject var model: ScreenshotEditorModel
    let controller: ScreenshotEditorController
    @ObservedObject private var l10n = L10n.shared
    @StateObject private var keyboard = ScreenshotShortcutContext()

    @Environment(\.colorScheme) private var colorScheme
    @State private var editingText = ""
    @State private var dragInFlight = false
    @State private var drag = ScreenshotSupport.EditorDrag()
    @State private var dragCanvasArea: CGSize?
    @State private var appeared = false
    @State private var backdropPopoverShown = false
    @StateObject private var watermarkTool = ScreenshotWatermarkToolAnchor.Presenter()
    @State private var hoveredTool: ScreenshotSupport.Tool?
    @State private var isTextSelectionHovered = false
    @State private var proxyHovered = false
    @FocusState private var focusedTool: ScreenshotSupport.Tool?
    @State private var toolOptionsShown = false
    @State private var sharing = false
    @State private var sharedRecord: ScreenshotShareRecord?
    @State private var shareAnchor = ShelfSharePickerAnchor.Anchor()
    @State private var sideBarAvailableHeight: CGFloat = 0
    @AppStorage(DefaultsKey.screenshotToolShortcuts) private var bindingsRaw = ""
    @AppStorage(DefaultsKey.screenshotToolShortcutsEnabled) private var toolShortcutsEnabled = true
    @AppStorage(DefaultsKey.screenshotSharingEnabled) private var sharingEnabled = true
    @AppStorage(DefaultsKey.shelfEnabled) private var shelfEnabled = false
    @AppStorage(AppFeature.shelf.availabilityKey) private var shelfAvailable = false

    private var strings: ScreenshotFeatureStrings {
        FeatureStrings.screenshot(l10n.language)
    }

    private static var hollowBlockCursorCache: [Int: NSCursor] = [:]

    private static func hollowBlockCursor(forHeight targetHeight: CGFloat) -> NSCursor {
        let h = max(16.0, min(120.0, targetHeight))
        let key = Int(h.rounded())
        if let cached = hollowBlockCursorCache[key] {
            return cached
        }

        let height = CGFloat(key)
        let width = max(8.0, (height * (25.0 / 45.0)).rounded())
        let cornerRadius = max(2.0, (height * (10.0 / 45.0)).rounded())

        let strokePad: CGFloat = 2.0
        let imageSize = NSSize(width: width + strokePad * 2, height: height + strokePad * 2)

        let image = NSImage(size: imageSize, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let blockRect = CGRect(x: strokePad, y: strokePad, width: width, height: height)
            let path = CGPath(roundedRect: blockRect,
                              cornerWidth: cornerRadius,
                              cornerHeight: cornerRadius,
                              transform: nil)

            context.addPath(path)
            context.setStrokeColor(CGColor(gray: 0, alpha: 0.9))
            context.setLineWidth(2.5)
            context.strokePath()

            context.addPath(path)
            context.setStrokeColor(CGColor(gray: 1, alpha: 1.0))
            context.setLineWidth(1.2)
            context.strokePath()

            return true
        }

        let cursor = NSCursor(image: image, hotSpot: NSPoint(x: imageSize.width / 2, y: imageSize.height / 2))
        hollowBlockCursorCache[key] = cursor
        return cursor
    }

    private var recentCapturesTitle: String {
        FeatureStrings.recentCaptures(l10n.language).title
    }

    var body: some View {
        // Real rows and columns, not overlays: the canvas scrolls in its own
        // region, so zoomed content can never slide under the controls.
        ZStack {
            artboard
            VStack(spacing: 0) {
                topBand
                    .padding(.top, 10)
                    .padding(.horizontal, 12)
                HStack(spacing: 0) {
                    ScrollView(.vertical) {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            toolRail
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: max(0, sideBarAvailableHeight))
                    }
                    .scrollIndicators(.never)
                    .fixedSize(horizontal: true, vertical: false)
                    .compositingGroup()
                    .shadow(color: .black.opacity(colorScheme == .light ? 0.08 : 0.22), radius: 10, y: 3)
                    .padding(.leading, 10)
                    canvasArea
                    ScrollView(.vertical) {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            contextualBar
                                .disabled(model.selectedIDs.count > 1)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: max(0, sideBarAvailableHeight))
                    }
                    .scrollIndicators(.never)
                    .fixedSize(horizontal: true, vertical: false)
                    // Keep a slim, constant rail so changing tools cannot refit the image.
                    .frame(width: 40)
                    .compositingGroup()
                    .shadow(color: .black.opacity(colorScheme == .light ? 0.08 : 0.22), radius: 10, y: 3)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: SideBarAvailableHeightKey.self, value: geo.size.height)
                        }
                    )
                    .onPreferenceChange(SideBarAvailableHeightKey.self) { height in
                        sideBarAvailableHeight = height
                    }
                    .padding(.trailing, 10)
                }
                .padding(.top, 4)
                bottomRow
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
            }
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.16), value: model.annotationShadowsEnabled)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: model.backdropStyle)
        .onAppear {
            keyboard.start()
            focusedTool = .select
        }
        .onDisappear { keyboard.stop() }
        .onChange(of: model.editingTextID) { _, newID in
            if let newID, let annotation = model.annotations.first(where: { $0.id == newID }) {
                editingText = annotation.text
            } else {
                editingText = ""
            }
        }
        .sheet(item: $sharedRecord) { record in
            ScreenshotEditorSharedLinkView(record: record,
                                           strings: strings,
                                           close: { sharedRecord = nil })
        }
    }

    /// The window's crown: the brand centered like the menu bar panel, the
    /// actions on the right, the trash for a capture not worth keeping.
    private var topBand: some View {
        ZStack {
            BrandMark(width: 28, tint: Color.primary.opacity(0.85))
            HStack {
                Spacer()
                actionCluster
            }
        }
        .frame(height: 38)
    }

    // MARK: - Artboard

    /// Surface shared by the editor chrome.
    private var artboard: some View {
        Rectangle()
            .fill(Color(nsColor: .windowBackgroundColor))
            .overlay {
                LinearGradient(colors: [Color.primary.opacity(0.035), .clear],
                               startPoint: .top, endPoint: .bottom)
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }

    // MARK: - Canvas

    private var contentPixelSize: CGSize {
        let pad = model.backdropPaddingPixels
        return CGSize(width: model.imageSize.width + pad * 2,
                      height: model.imageSize.height + pad * 2)
    }

    private var canvasArea: some View {
        GeometryReader { proxy in
            // A click can change the selection, and with it the footer's
            // controls and row count. Until the drag ends the canvas and its
            // scroll view keep the region they started in, so neither the
            // fit nor a scroll offset clamped to a new height moves the
            // canvas under a still cursor and turns the click into a drag.
            let available = dragCanvasArea ?? proxy.size
            let zoom = zoomFactor(available: available)
            let canvasSize = CGSize(width: contentPixelSize.width * zoom,
                                    height: contentPixelSize.height * zoom)
            ScrollView([.horizontal, .vertical]) {
                canvas(zoom: zoom, canvasSize: canvasSize, available: available)
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .padding(canvasInsets(available: available, canvas: canvasSize))
            }
            .scrollIndicators(.never)
            .frame(width: available.width, height: available.height, alignment: .topLeading)
            // Trackpad pinch, anchored at the zoom the gesture started from.
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        let base = magnifyBase
                            ?? (model.zoomOverride ?? model.currentDisplayZoom)
                        magnifyBase = base
                        model.setZoom(base * value)
                    }
                    .onEnded { _ in magnifyBase = nil }
            )
        }
        .clipped()
    }

    @State private var magnifyBase: CGFloat?

    // Margin around the capture inside its scroll region.
    // Reserve the shadow's full falloff before the scroll viewport clips it.
    private static let canvasMargin: CGFloat = 40

    private func zoomFactor(available: CGSize) -> CGFloat {
        let zoom: CGFloat
        if let override = model.zoomOverride {
            zoom = override
        } else {
            let width = max(available.width - Self.canvasMargin * 2, 80)
            let height = max(available.height - Self.canvasMargin * 2, 80)
            let fit = min(width / max(contentPixelSize.width, 1),
                          height / max(contentPixelSize.height, 1))
            // Small captures grow to a practical editing size. This affects
            // only the canvas; exported pixels stay untouched.
            zoom = min(fit, 1)
        }
        // Pinch and scroll zoom start from what is actually on screen.
        model.currentDisplayZoom = zoom
        return zoom
    }

    private func canvasInsets(available: CGSize, canvas: CGSize) -> EdgeInsets {
        EdgeInsets(top: max((available.height - canvas.height) / 2, Self.canvasMargin),
                   leading: max((available.width - canvas.width) / 2, Self.canvasMargin),
                   bottom: max((available.height - canvas.height) / 2, Self.canvasMargin),
                   trailing: max((available.width - canvas.width) / 2, Self.canvasMargin))
    }

    private func canvas(zoom: CGFloat, canvasSize: CGSize, available: CGSize) -> some View {
        let outerRadius = model.showsBackdrop
            ? 6
            : max(4, model.cardCornerPixels * zoom)
        return ZStack {
            if model.showsBackdrop {
                backdropFillView
                    .scaleEffect(1 + CGFloat(model.backdropStyle.blur) * 0.08)
                    .blur(radius: ScreenshotSupport.backdropBlurRadius(
                        for: contentPixelSize,
                        factor: CGFloat(model.backdropStyle.blur)) * zoom)
            }
            Canvas { context, size in
                context.withCGContext { cg in
                    drawContent(cg, size: size, zoom: zoom)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: outerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
        )
        .compositingGroup()
        .shadow(color: .black.opacity(colorScheme == .light ? 0.12 : 0.30), radius: 12, y: 4)
        .shadow(color: .black.opacity(colorScheme == .light ? 0.06 : 0.18), radius: 3, y: 1)
        .scaleEffect(appeared ? 1 : 0.965)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                appeared = true
            }
        }
        .overlay {
            canvasInput(zoom: zoom, available: available)
        }
        .overlay(alignment: .topLeading) {
            textEditorOverlay(zoom: zoom)
        }
        .overlay(alignment: .topLeading) {
            cropLoupeOverlay(zoom: zoom, canvasSize: canvasSize)
        }
    }

    private func updateCanvasCursor(at point: CGPoint, zoom: CGFloat, dragging: Bool = false) {
        if let handle = model.resizeHandle(at: point) {
            ScreenshotEditorResizeCursor.cursor(for: handle).set()
        } else if model.tool == .crop {
            if let draft = model.cropDraft, draft.contains(point),
               !ScreenshotSupport.startsNewCropSelection(at: point, draft: draft,
                    within: CGRect(origin: .zero, size: model.imageSize)) {
                (dragging ? NSCursor.closedHand : .openHand).set()
            } else { NSCursor.crosshair.set() }
        } else if model.textSelectionEnabled, model.wordIndex(at: point) != nil {
            NSCursor.iBeam.set()
        } else if model.tool == .highlight {
            let height = model.selectableTextHeight(at: point).map { $0 * zoom } ?? 16
            Self.hollowBlockCursor(forHeight: height).set()
        } else if model.tool == .select ? model.hitTest(point) != nil : model.selectedAnnotationOwns(point) {
            (dragging ? NSCursor.closedHand : .openHand).set()
        } else {
            (model.tool == .select ? NSCursor.arrow : .crosshair).set()
        }
    }

    /// The live backdrop layer, matching exactly what the exporter paints.
    @ViewBuilder
    private var backdropFillView: some View {
        switch model.backdropFill {
        case .none:
            EmptyView()
        case .colors(let components):
            if components.count == 1, let single = components.first {
                Color(.sRGB, red: single.red, green: single.green, blue: single.blue, opacity: 1)
            } else {
                LinearGradient(colors: components.map {
                    Color(.sRGB, red: $0.red, green: $0.green, blue: $0.blue, opacity: 1)
                }, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        case .image(let image):
            // The overlay clips aspect-fill overflow to the backdrop bounds.
            Rectangle()
                .fill(.clear)
                .overlay {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                }
                .clipped()
        }
    }

    private func drawContent(_ cg: CGContext, size: CGSize, zoom: CGFloat) {
        let pad = model.backdropPaddingPixels * zoom
        let imageRect = CGRect(x: pad, y: pad,
                               width: model.imageSize.width * zoom,
                               height: model.imageSize.height * zoom)

        var cardPath: CGPath?
        if model.showsBackdrop {
            // The capture sits on the fill like a card: soft shadow and the
            // user's corner rounding, exactly what the exporter composes.
            let corner = model.cardCornerPixels * zoom
            let path = CGPath(roundedRect: imageRect,
                              cornerWidth: corner, cornerHeight: corner, transform: nil)
            cardPath = path
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: -5), blur: 18,
                         color: CGColor(gray: 0, alpha: 0.38))
            cg.addRect(CGRect(origin: .zero, size: size))
            cg.addPath(path)
            cg.clip(using: .evenOdd)
            cg.addPath(path)
            cg.setFillColor(CGColor(gray: 1, alpha: 1))
            cg.fillPath()
            cg.restoreGState()
        }

        func enterImageSpace() {
            cg.scaleBy(x: zoom, y: zoom)
            cg.translateBy(x: model.backdropPaddingPixels, y: model.backdropPaddingPixels)
            if model.showsBackdrop {
                // The exporter composes annotations before the backdrop, so they
                // never spill onto the margin; the live canvas must agree.
                cg.clip(to: CGRect(origin: .zero, size: model.imageSize))
            }
        }

        // Blur areas replace the pixels under them. With any on the canvas,
        // the capture and its annotations draw in a layer of their own, as
        // the exporter flattens them, so that never reaches the card's
        // shadow or the backdrop. Without one, the layer is skipped, since
        // it costs a canvas-sized buffer on every redraw.
        let isolatesBlurAreas = model.annotations.contains { $0.tool == .pixelate }
        if isolatesBlurAreas { cg.beginTransparencyLayer(auxiliaryInfo: nil) }
        if let cardPath {
            cg.saveGState()
            cg.addPath(cardPath)
            cg.clip()
            drawImageUpright(cg, in: imageRect, canvasHeight: size.height)
            cg.restoreGState()
        } else {
            drawImageUpright(cg, in: imageRect, canvasHeight: size.height)
        }
        cg.saveGState()
        enterImageSpace()
        ScreenshotRenderer.drawAnnotations(model.annotations,
                                           in: cg,
                                           blurSources: model.blurSources,
                                           imageSize: model.imageSize,
                                           scale: model.scale,
                                           annotationShadowsEnabled: model.annotationShadowsEnabled,
                                           skippingText: model.editingTextID)
        cg.restoreGState()
        if isolatesBlurAreas { cg.endTransparencyLayer() }

        cg.saveGState()
        enterImageSpace()
        ScreenshotRenderer.drawWatermark(model.watermarkStyle,
                                         image: model.watermarkImage,
                                         in: cg,
                                         imageSize: model.imageSize,
                                         scale: model.scale,
                                         shadowsEnabled: model.annotationShadowsEnabled,
                                         cornerRadius: model.cardCornerPixels)
        drawTextSelection(cg)
        drawSelectionChrome(cg)
        drawCropChrome(cg, canvasSize: size, zoom: zoom)
        cg.restoreGState()
    }

    /// Highlight for recognized words selected on the canvas.
    private func drawTextSelection(_ cg: CGContext) {
        guard !model.selectedWordIndexes.isEmpty else { return }
        cg.setFillColor(CGColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 0.32))
        for index in model.selectedWordIndexes where model.textWords.indices.contains(index) {
            let rect = model.textWords[index].rect.insetBy(dx: -1.5 * model.scale,
                                                           dy: -1.5 * model.scale)
            let path = CGPath(roundedRect: rect,
                              cornerWidth: 2 * model.scale, cornerHeight: 2 * model.scale,
                              transform: nil)
            cg.addPath(path)
            cg.fillPath()
        }
    }

    private func drawImageUpright(_ cg: CGContext, in rect: CGRect, canvasHeight: CGFloat) {
        cg.saveGState()
        cg.translateBy(x: 0, y: canvasHeight)
        cg.scaleBy(x: 1, y: -1)
        let flipped = CGRect(x: rect.minX,
                             y: canvasHeight - rect.maxY,
                             width: rect.width,
                             height: rect.height)
        cg.draw(model.baseImage, in: flipped)
        cg.restoreGState()
    }

    // MARK: - Gestures

    private func canvasInput(zoom: CGFloat, available: CGSize) -> some View {
        ScreenshotCanvasInput(
            began: { location, modifiers in
                dragInFlight = true
                drag.begin(at: location)
                dragCanvasArea = available
                commitEditingTextIfNeeded()
                let point = imagePoint(from: location, zoom: zoom)
                model.beginDrag(at: point, modifiers: modifiers)
                updateCanvasCursor(at: point, zoom: zoom, dragging: true)
            }, moved: { location, modifiers in
                let point = imagePoint(from: location, zoom: zoom)
                model.continueDrag(to: point, constrained: modifiers.contains(.shift))
                drag.update(to: location)
                updateCanvasCursor(at: point, zoom: zoom, dragging: true)
            }, ended: { location, modifiers, clicks in
                guard dragInFlight else { return }
                dragInFlight = false
                dragCanvasArea = nil
                let point = imagePoint(from: location, zoom: zoom)
                drag.update(to: location)
                let isTap = drag.isTap(for: model.tool)
                if isTap, model.tool == .text || model.tool == .sticker || model.tool == .counter,
                   !CGRect(origin: .zero, size: model.imageSize).contains(point) {
                    return
                }
                model.endDrag(at: point, isTap: isTap)
                if isTap, clicks == 2, !modifiers.contains(.command) { model.editText(at: point) }
                updateCanvasCursor(at: point, zoom: zoom)
                if let editingID = model.editingTextID {
                    editingText = model.annotations.first(where: { $0.id == editingID })?.text ?? ""
                }
            }, hovered: { location in
                if let location {
                    updateCanvasCursor(at: imagePoint(from: location, zoom: zoom), zoom: zoom, dragging: dragInFlight)
                } else if !dragInFlight { NSCursor.arrow.set() }
            })
    }

    private func imagePoint(from viewPoint: CGPoint, zoom: CGFloat) -> CGPoint {
        let pad = model.backdropPaddingPixels
        return CGPoint(x: viewPoint.x / zoom - pad, y: viewPoint.y / zoom - pad)
    }

    // MARK: - Crop loupe

    private static let cropLoupeSize: CGFloat = 72

    @ViewBuilder
    private func cropLoupeOverlay(zoom: CGFloat, canvasSize: CGSize) -> some View {
        if let point = model.cropLoupePoint {
            // A crop edge sits between pixels, not on one, so this loupe wants an
            // even sample side to put that edge in the middle of the frame — the
            // opposite of what the capture loupe's color read needs.
            let sourceRect = ScreenshotSupport.cropLoupeSampleRect(
                around: point,
                imageSize: model.imageSize,
                sideLength: 14,
                centredOnPixel: false)
            if let sample = model.baseImage.cropping(to: sourceRect) {
                let size = Self.cropLoupeSize
                let crossX = min(max((point.x - sourceRect.minX) / sourceRect.width * size, 0.5),
                                 size - 0.5)
                let crossY = min(max((point.y - sourceRect.minY) / sourceRect.height * size, 0.5),
                                 size - 0.5)
                ZStack(alignment: .topLeading) {
                    Image(decorative: sample, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: size, height: size)
                    Rectangle()
                        .fill(Color.black.opacity(0.72))
                        .frame(width: 1, height: size)
                        .offset(x: crossX - 0.5)
                    Rectangle()
                        .fill(Color.black.opacity(0.72))
                        .frame(width: size, height: 1)
                        .offset(y: crossY - 0.5)
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 1)
                        .background(Circle().fill(Color.black.opacity(0.3)))
                        .frame(width: 7, height: 7)
                        .offset(x: crossX - 3.5, y: crossY - 3.5)
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.45), radius: 8, y: 3)
                .position(cropLoupePosition(for: point, zoom: zoom, canvasSize: canvasSize))
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
    }

    private func cropLoupePosition(for point: CGPoint,
                                   zoom: CGFloat,
                                   canvasSize: CGSize) -> CGPoint {
        let size = Self.cropLoupeSize
        let half = size / 2
        let gap: CGFloat = 14
        let pad = model.backdropPaddingPixels
        let anchor = CGPoint(x: (point.x + pad) * zoom,
                             y: (point.y + pad) * zoom)
        var x = anchor.x + half + gap
        var y = anchor.y - half - gap
        if x + half > canvasSize.width { x = anchor.x - half - gap }
        if y - half < 0 { y = anchor.y + half + gap }
        if canvasSize.width >= size {
            x = min(max(x, half), canvasSize.width - half)
        } else {
            x = canvasSize.width / 2
        }
        if canvasSize.height >= size {
            y = min(max(y, half), canvasSize.height - half)
        } else {
            y = canvasSize.height / 2
        }
        return CGPoint(x: x, y: y)
    }

    // MARK: - Selection and crop chrome

    private func drawSelectionChrome(_ cg: CGContext) {
        for mark in model.annotations where model.selectedIDs.contains(mark.id) && mark.id != model.editingTextID {
            ScreenshotSelectionChrome.draw(mark, in: cg, captureScale: model.scale,
                displayZoom: model.currentDisplayZoom, imageSize: model.imageSize,
                showsHandles: model.selectedIDs.count == 1)
        }
    }


    private func drawCropChrome(_ cg: CGContext, canvasSize: CGSize, zoom: CGFloat) {
        guard model.tool == .crop, let draft = model.cropDraft else { return }
        let scale = model.scale
        let pad = model.backdropPaddingPixels
        cg.setFillColor(CGColor(gray: 0, alpha: 0.45))
        cg.beginPath()
        cg.addRect(CGRect(x: -pad, y: -pad,
                          width: canvasSize.width / zoom, height: canvasSize.height / zoom))
        cg.addRect(draft)
        cg.fillPath(using: .evenOdd)
        cg.setStrokeColor(CGColor(gray: 1, alpha: 0.95))
        cg.setLineWidth(1.5 * scale)
        cg.stroke(draft)
        for handle in ScreenshotSupport.Handle.allCases {
            let position = handle.position(in: draft)
            let radius = 4 * scale
            // A crop grip belongs to the edge itself. Do not push full-image
            // grips inward just to keep the entire circle visible.
            let dot = CGRect(x: position.x - radius, y: position.y - radius,
                             width: 8 * scale, height: 8 * scale)
            cg.setFillColor(CGColor(gray: 1, alpha: 1))
            cg.fillEllipse(in: dot)
        }
    }

    // MARK: - Inline text editing

    @ViewBuilder
    private func textEditorOverlay(zoom: CGFloat) -> some View {
        ScreenshotInlineTextEditor(model: model, text: $editingText, zoom: zoom)
    }

    private func commitEditingTextIfNeeded() {
        if let editingID = model.editingTextID {
            controller.endInlineTextEditing()
            model.commitText(editingID, text: editingText)
        }
    }

    // MARK: - Tool rail

    private var orderedTools: [ScreenshotSupport.Tool] {
        ScreenshotSupport.Tool.ordered(from: nil)
    }

    private var toolRail: some View {
        VStack(spacing: 2) {
            ForEach(orderedTools, id: \.self) { tool in
                railButton(tool)
            }
            textSelectionButton
            Divider()
                .frame(width: 22)
                .padding(.vertical, 2)
            Button {
                toolOptionsShown.toggle()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 33, height: 29)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(toolOptionsShown
                                    ? Color.accentColor.opacity(0.22) : .clear)
                    )
                    .foregroundStyle(toolOptionsShown ? Color.accentColor : Color.secondary)
                    .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.borderless)
            .screenshotIconHover()
            .screenshotSafeHelp(strings.toolShortcutsTitle)
            .accessibilityLabel(strings.toolShortcutsTitle)
            .popover(isPresented: $toolOptionsShown, arrowEdge: .leading) {
                ScreenshotToolOrderControls(shortcutsEnabled: $toolShortcutsEnabled)
                    .padding(14)
                    .frame(width: 340)
            }
        }
        .padding(5)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.regularMaterial)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var textSelectionButton: some View {
        let isActive = model.textSelectionEnabled
        let isHovered = isTextSelectionHovered
        return Button {
            commitEditingTextIfNeeded()
            model.tool = .select
            model.selectedID = nil
            model.textSelectionEnabled.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "text.viewfinder")
                    .font(.system(size: 13.5, weight: .medium))
                    .symbolEffect(.bounce, value: isActive)
                    .frame(width: 33, height: 29)
                if toolShortcutsEnabled {
                    Text("T")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .fixedSize()
                        .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                        .padding(2)
                        .opacity(isHovered || isActive ? 0.9 : 0.55)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isActive
                            ? Color.accentColor.opacity(0.22)
                            : isHovered ? Color.primary.opacity(0.08) : .clear)
            )
            .foregroundStyle(isActive ? Color.accentColor : Color.primary.opacity(0.85))
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .scaleEffect(isHovered && !isActive ? 1.06 : 1)
        }
        .buttonStyle(.borderless)
        .screenshotIconHover()
        .onHover { inside in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isTextSelectionHovered = inside
            }
        }
        .screenshotSafeHelp(FeatureStrings.editorRefinements(l10n.language).selectText + (toolShortcutsEnabled ? "  (T)" : ""))
        .accessibilityLabel(FeatureStrings.editorRefinements(l10n.language).selectText)
    }

    private func railButton(_ tool: ScreenshotSupport.Tool) -> some View {
        let isActive = model.tool == tool && !model.textSelectionEnabled
        let isHovered = hoveredTool == tool
        let shortcutLabel = ScreenshotSupport.Tool.shortcutLabel(
            for: tool, orderRaw: nil, bindingsRaw: bindingsRaw, enabled: toolShortcutsEnabled,
            capsLockOn: keyboard.capsLockOn)
        return Button {
            commitEditingTextIfNeeded()
            model.textSelectionEnabled = false
            model.tool = tool
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: tool.screenshotSymbolName)
                    .font(.system(size: 13.5, weight: .medium))
                    .symbolEffect(.bounce, value: isActive)
                    .frame(width: 33, height: 29)
                if let shortcutLabel {
                    Text(shortcutLabel)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .fixedSize()
                        .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                        .padding(2)
                        .opacity(isHovered || isActive ? 0.9 : 0.55)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isActive
                            ? Color.accentColor.opacity(0.22)
                            : isHovered ? Color.primary.opacity(0.08) : .clear)
            )
            .foregroundStyle(isActive ? Color.accentColor : Color.primary.opacity(0.85))
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .scaleEffect(isHovered && !isActive ? 1.06 : 1)
        }
        .buttonStyle(.borderless)
        .screenshotIconHover()
        .focused($focusedTool, equals: tool)
        .onHover { inside in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                hoveredTool = inside ? tool : (hoveredTool == tool ? nil : hoveredTool)
            }
        }
        .screenshotSafeHelp(tool.screenshotTitle(strings)
            + (shortcutLabel.map { "  (\($0))" } ?? ""))
        .accessibilityLabel(tool.screenshotTitle(strings)
            + (shortcutLabel.map { "  (\($0))" } ?? ""))
    }

    // MARK: - QR code (shown only when the capture holds one)

    /// Opens the shared result panel that spells out the code's content, with
    /// copy and open actions.
    private var qrControl: some View {
        Button {
            controller.showQRResult()
        } label: {
            Image(systemName: "qrcode")
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .screenshotIconHover()
        .tint(.accentColor)
        .screenshotSafeHelp(l10n.s.qrResultTitle)
        .accessibilityLabel(l10n.s.qrResultTitle)
    }

    // MARK: - Action cluster (top right)

    private var actionCluster: some View {
        HStack(spacing: 4) {
            Button {
                RecentCaptureService.shared.showHistoryWindow()
            } label: {
                Image(systemName: "photo.stack")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .screenshotIconHover()
            .focusable(false)
            .screenshotSafeHelp(recentCapturesTitle)
            .accessibilityLabel(recentCapturesTitle)

            Divider().frame(height: 16).padding(.horizontal, 3)

            Button {
                controller.discardAndClose()
            } label: {
                Image(systemName: "trash")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .screenshotIconHover()
            .focusable(false)
            .screenshotSafeHelp(strings.discardConfirm)
            .accessibilityLabel(strings.discardConfirm)

            Divider().frame(height: 16).padding(.horizontal, 3)

            Button {
                commitEditingTextIfNeeded()
                model.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .screenshotIconHover()
            .focusable(false)
            .disabled(!model.canUndo)
            .foregroundStyle(model.canUndo ? Color.primary : Color.secondary.opacity(0.4))
            .screenshotSafeHelp(refinementStrings.undo + "  (⌘Z)")
            .accessibilityLabel(refinementStrings.undo)
            Button {
                commitEditingTextIfNeeded()
                model.redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .screenshotIconHover()
            .focusable(false)
            .disabled(!model.canRedo)
            .foregroundStyle(model.canRedo ? Color.primary : Color.secondary.opacity(0.4))
            .screenshotSafeHelp(refinementStrings.redo + "  (⇧⌘Z)")
            .accessibilityLabel(refinementStrings.redo)

            if model.qrReading != nil {
                Divider().frame(height: 16).padding(.horizontal, 3)
                qrControl
                    .focusable(false)
                    .transition(.scale.combined(with: .opacity))
            }

            Divider().frame(height: 16).padding(.horizontal, 3)

            Button {
                commitEditingTextIfNeeded()
                controller.pin()
            } label: {
                Image(systemName: "pin")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .screenshotIconHover()
            .focusable(false)
            .screenshotSafeHelp(strings.pinButton + "  (⌘P)")
            .accessibilityLabel(strings.pinButton)

            Divider().frame(height: 16).padding(.horizontal, 3)

            Button {
                commitEditingTextIfNeeded()
                guard let url = controller.shareFile() else {
                    NSSound.beep()
                    return
                }
                shareAnchor.present([url]) { chosen in
                    if chosen { model.markExported() }
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .screenshotIconHover()
            .focusable(false)
            .background(ShelfSharePickerAnchor(anchor: shareAnchor))
            .screenshotSafeHelp(strings.shareButton)
            .accessibilityLabel(strings.shareButton)

            if sharingEnabled {
                shareMenu
            }
            Divider().frame(height: 16).padding(.horizontal, 3)

            Menu {
                Button(strings.saveButton) {
                    commitEditingTextIfNeeded()
                    controller.save()
                }
                Button(strings.saveAsButton) {
                    commitEditingTextIfNeeded()
                    controller.saveAs()
                }
                if shelfEnabled, shelfAvailable {
                    Button(strings.addToShelfButton) {
                        commitEditingTextIfNeeded()
                        controller.addToShelf()
                    }
                }
            } label: {
                Text(strings.saveButton)
            } primaryAction: {
                commitEditingTextIfNeeded()
                controller.save()
            }
            .focusable(false)
            .fixedSize()
            .screenshotSafeHelp("⇧⌘S")

            Button(l10n.s.doneButton) {
                commitEditingTextIfNeeded()
                controller.done()
            }
            .buttonStyle(.borderedProminent)
            .screenshotSafeHelp("⌘S / ⏎")
        }
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
                .compositingGroup()
                .shadow(color: .black.opacity(colorScheme == .light ? 0.08 : 0.22), radius: 10, y: 3)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private var shareMenu: some View {
        Menu {
            ForEach(ScreenshotShareDuration.allCases) { duration in
                Button(duration.title(strings)) {
                    commitEditingTextIfNeeded()
                    sharing = true
                    controller.share(duration: duration) { record in
                        sharing = false
                        sharedRecord = record
                    }
                }
            }
        } label: {
            Group {
                if sharing {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 13.5, weight: .medium))
                }
            }
            .frame(width: 28, height: 28)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .screenshotIconHover()
        .focusable(false)
        .fixedSize()
        .disabled(sharing)
        .screenshotSafeHelp(sharing ? strings.sharingHUD : strings.shareSectionTitle)
        .accessibilityLabel(strings.shareSectionTitle)
    }

    // MARK: - Bottom row

    private var showsColorControls: Bool {
        switch model.tool {
        case .arrow, .line, .rect, .ellipse, .freehand, .highlight, .text, .counter, .redact:
            return true
        case .select:
            guard let selectedID = model.selectedID,
                  let selected = model.annotations.first(where: { $0.id == selectedID })
            else { return false }
            return selected.tool != .sticker
                && selected.tool != .pixelate
        case .sticker, .pixelate, .crop:
            return false
        }
    }

    private var showsBlurControls: Bool {
        if model.tool == .pixelate { return true }
        guard model.tool == .select,
              let selectedID = model.selectedID,
              let selected = model.annotations.first(where: { $0.id == selectedID })
        else { return false }
        return selected.tool == .pixelate
    }

    /// Text takes a point size where shapes take a thickness.
    private var showsTextSizeControls: Bool {
        if model.tool == .text { return true }
        guard model.tool == .select,
              let selectedID = model.selectedID,
              let selected = model.annotations.first(where: { $0.id == selectedID })
        else { return false }
        return selected.tool == .text
    }

    private var showsArrowStyleControls: Bool {
        if model.tool == .arrow { return true }
        guard model.tool == .select,
              let selectedID = model.selectedID,
              let selected = model.annotations.first(where: { $0.id == selectedID })
        else { return false }
        return selected.tool == .arrow
    }

    /// Depth only means something when there is another shape to pass. The
    /// buttons stay while there is, dimmed until a shape is picked, so picking
    /// or dropping a shape never adds or removes them, and an empty editor
    /// keeps no gap for them. A shape still being drawn counts once it lands.
    private var showsLayerControls: Bool {
        model.annotations.lazy.filter { $0.id != model.draftID }.count > 1
    }

    /// Each direction dims on its own once the shape reaches that end, so the
    /// buttons never offer a move that would do nothing.
    private func canMoveSelected(_ move: ScreenshotSupport.LayerMove) -> Bool {
        guard let selectedID = model.selectedID else { return false }
        return ScreenshotSupport.canReorder(model.annotations, moving: selectedID, move)
    }

    private func layerButton(_ move: ScreenshotSupport.LayerMove,
                             symbol: String,
                             label: String) -> some View {
        Button {
            commitEditingTextIfNeeded()
            model.moveSelected(move)
        } label: {
            Image(systemName: symbol)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .screenshotIconHover()
        .disabled(!canMoveSelected(move))
        .screenshotSafeHelp(label)
        .accessibilityLabel(label)
    }

    private var showsStickerControls: Bool {
        if model.tool == .sticker { return true }
        guard model.tool == .select,
              let selectedID = model.selectedID,
              let selected = model.annotations.first(where: { $0.id == selectedID })
        else { return false }
        return selected.tool == .sticker
    }

    private var refinementStrings: ScreenshotEditorRefinementStrings {
        FeatureStrings.editorRefinements(l10n.language)
    }

    private var showsCornerRadiusControls: Bool {
        if model.tool == .rect || model.tool == .redact { return true }
        guard model.tool == .select,
              let selectedID = model.selectedID,
              let selected = model.annotations.first(where: { $0.id == selectedID })
        else { return false }
        return selected.tool == .rect || selected.tool == .redact
    }

    private var cornerRadiusButton: some View {
        Button {
            model.cornerRadiusEnabled.toggle()
        } label: {
            Image(systemName: "app")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(model.cornerRadiusEnabled ? Color.accentColor.opacity(0.20) : .clear)
                )
                .foregroundStyle(model.cornerRadiusEnabled ? Color.accentColor : Color.primary.opacity(0.65))
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.borderless)
        .screenshotIconHover()
        .fixedSize()
        .screenshotSafeHelp(refinementStrings.cornerRadius)
        .accessibilityLabel(refinementStrings.cornerRadius)
        .accessibilityAddTraits(model.cornerRadiusEnabled ? .isSelected : [])
    }

    private var bottomRow: some View {
        HStack(alignment: .center, spacing: 10) {
            infoChip
            Spacer()
            zoomChip
        }
        .frame(height: 32)
    }

    @ViewBuilder
    private var contextualBar: some View {
        if model.tool == .crop, model.cropDraft != nil {
            cropBar
        } else {
            styleBar
        }
    }

    private var styleBar: some View {
        VStack(spacing: 8) {
            if showsArrowStyleControls {
                arrowStyleMenu
                Divider().frame(width: 16)
            }
            if showsStickerControls {
                stickerMenu
                Divider().frame(width: 16)
            }
            if showsBlurControls {
                blurStyleMenu
                blurTextOnlyButton
                if model.blurStyle.usesStrength {
                    blurLevelControl
                }
                Divider().frame(width: 16)
            }
            if showsColorControls {
                VStack(spacing: 4) {
                    ForEach(ScreenshotSupport.ColorID.allCases, id: \.self) { colorID in
                        colorDot(colorID)
                    }
                }
                Divider().frame(width: 16)
                if showsTextSizeControls {
                    textSizeControl
                } else {
                    VStack(spacing: 4) {
                        ForEach(ScreenshotSupport.StrokeID.allCases, id: \.self) { stroke in
                            strokeGlyph(stroke)
                        }
                    }
                }
                Divider().frame(width: 16)
            }
            if showsCornerRadiusControls {
                cornerRadiusButton
                Divider().frame(width: 16)
            }
            if showsLayerControls {
                layerButton(.backward, symbol: "square.2.layers.3d.bottom.filled",
                            label: strings.sendBackward)
                layerButton(.forward, symbol: "square.2.layers.3d.top.filled",
                            label: strings.bringForward)
                Divider().frame(width: 16)
            }
            annotationShadowButton
            Divider().frame(width: 16)
            backdropButton
            Divider().frame(width: 16)
            watermarkButton
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.regularMaterial)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    /// The same kind of menu as the sticker picker: an inline picker gives
    /// each style a native row with a checkmark, and the sample images come
    /// from the editor's own renderer, so the menu shows exactly what draws.
    private var arrowStyleMenu: some View {
        Menu {
            Picker(strings.arrowStyleLabel, selection: $model.arrowStyle) {
                ForEach(ScreenshotSupport.ArrowStyleID.allCases, id: \.self) { style in
                    Label {
                        Text(strings.arrowStyleTitle(style))
                    } icon: {
                        Image(nsImage: ScreenshotArrowStyleSamples.image(for: style))
                    }
                    .tag(style)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Image(nsImage: ScreenshotArrowStyleSamples.image(for: model.arrowStyle))
                .renderingMode(.template)
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .screenshotIconHover()
        .menuIndicator(.hidden)
        .fixedSize()
        .screenshotSafeHelp(strings.arrowStyleLabel)
        .accessibilityLabel(strings.arrowStyleLabel)
    }

    private var stickerMenu: some View {
        Menu {
            ForEach(ScreenshotSupport.StickerID.allCases, id: \.self) { sticker in
                Button {
                    model.sticker = sticker
                } label: {
                    HStack {
                        Text(sticker.glyph)
                        if model.sticker == sticker {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Text(model.sticker.glyph)
                .font(.system(size: 16))
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .screenshotIconHover()
        .menuIndicator(.hidden)
        .fixedSize()
        .screenshotSafeHelp(strings.toolSticker)
        .accessibilityLabel(strings.toolSticker)
    }

    private var cropBar: some View {
        VStack(spacing: 8) {
            Menu {
                Picker(refinementStrings.aspectRatio, selection: $model.cropAspect) {
                    ForEach(ScreenshotCropAspect.allCases, id: \.self) { aspect in
                        Text(cropAspectTitle(aspect)).tag(aspect)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                Image(systemName: "aspectratio")
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .screenshotIconHover()
            .menuIndicator(.hidden)
            .fixedSize()
            .contentShape(Rectangle())
            .screenshotSafeHelp(refinementStrings.aspectRatio + ": " + cropAspectTitle(model.cropAspect))
            .accessibilityLabel(refinementStrings.aspectRatio)
            .accessibilityValue(cropAspectTitle(model.cropAspect))

            Button {
                model.applyCrop()
            } label: {
                Image(systemName: "checkmark")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .screenshotIconHover()
            .screenshotSafeHelp(strings.cropApply)

            Button {
                model.tool = .select
            } label: {
                Image(systemName: "xmark")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .screenshotIconHover()
            .screenshotSafeHelp(strings.cancel)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.regularMaterial)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func cropAspectTitle(_ aspect: ScreenshotCropAspect) -> String {
        switch aspect {
        case .free: refinementStrings.freeCrop
        case .original: FeatureStrings.recorder(l10n.language).shapeOriginal
        default: aspect.rawValue
        }
    }

    private func colorDot(_ colorID: ScreenshotSupport.ColorID) -> some View {
        let selected = model.color == colorID
        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) {
                model.color = colorID
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(nsColor: ScreenshotRenderer.nsColor(colorID)))
                    .frame(width: 17, height: 17)
                    .overlay(
                        Circle().strokeBorder(Color.primary.opacity(0.22), lineWidth: 0.5)
                    )
                if selected {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.9), lineWidth: 1.5)
                        .frame(width: 23, height: 23)
                }
            }
            .frame(width: 24, height: 24)
            .scaleEffect(selected ? 1.05 : 1)
        }
        .buttonStyle(.borderless)
        .screenshotIconHover()
        .accessibilityLabel(strings.colorLabel)
        .screenshotSafeHelp(strings.colorLabel)
    }

    /// Line-weight glyphs with three increasing stroke widths.
    private func strokeGlyph(_ stroke: ScreenshotSupport.StrokeID) -> some View {
        let selected = model.stroke == stroke
        let height: CGFloat = switch stroke {
        case .small: 1.8
        case .medium: 3.4
        case .large: 5.4
        }
        return Button {
            model.stroke = stroke
        } label: {
            Capsule()
                .fill(selected ? Color.accentColor : Color.primary.opacity(0.6))
                .frame(width: 15, height: height)
                .frame(width: 25, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? Color.accentColor.opacity(0.18) : .clear)
                )
        }
        .buttonStyle(.borderless)
        .screenshotIconHover()
        .screenshotSafeHelp(strings.strokeLabel)
        .accessibilityLabel(strings.strokeLabel)
    }

    /// The rail stays icon-only; the popup has room for a live size slider.
    private var textSizeControl: some View {
        ScreenshotFontSizeControl(value: $model.textSize, title: strings.fontSizeLabel,
                                  onEditingChanged: model.textSizeEditingChanged)
    }

    /// Pixelate, blur or erase, picked the way an arrow style is.
    private var blurStyleMenu: some View {
        Menu {
            Picker(strings.blurStyleLabel, selection: $model.blurStyle) {
                ForEach(ScreenshotSupport.BlurStyleID.allCases, id: \.self) { style in
                    Label(strings.blurStyleTitle(style), systemImage: style.screenshotSymbolName)
                        .tag(style)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Image(systemName: model.blurStyle.screenshotSymbolName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .screenshotIconHover()
        .menuIndicator(.hidden)
        .fixedSize()
        .screenshotSafeHelp(strings.blurStyleLabel)
        .accessibilityLabel(strings.blurStyleLabel)
    }

    /// Covers only recognized text and leaves the rest of the picture intact.
    private var blurTextOnlyButton: some View {
        Button {
            model.blurTextOnly.toggle()
        } label: {
            Image(systemName: "character.textbox")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(model.blurTextOnly ? Color.accentColor.opacity(0.20) : .clear)
                )
                .foregroundStyle(model.blurTextOnly ? Color.accentColor : Color.primary.opacity(0.65))
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.borderless)
        .screenshotIconHover()
        .fixedSize()
        .screenshotSafeHelp(strings.blurTextOnly)
        .accessibilityLabel(strings.blurTextOnly)
        .accessibilityAddTraits(model.blurTextOnly ? .isSelected : [])
    }

    /// Five steps from a light blur to a heavy one; the middle is the
    /// strength the tool always had.
    private var blurLevelControl: some View {
        let levels = ScreenshotSupport.BlurStrength.levels
        return Menu {
            Picker(strings.blurStrengthLabel, selection: Binding(get: { model.blurLevel },
                                                                 set: { model.blurLevel = $0 })) {
                ForEach(levels, id: \.self) { level in
                    Text("\(level)").tag(level)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            Image(systemName: "aqi.medium")
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .screenshotIconHover()
        .menuIndicator(.hidden)
        .fixedSize()
        .screenshotSafeHelp(strings.blurStrengthLabel)
        .accessibilityLabel(strings.blurStrengthLabel)
        .accessibilityValue("\(model.blurLevel)")
    }

    private var annotationShadowButton: some View {
        Button {
            model.annotationShadowsEnabled.toggle()
        } label: {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 12.5, weight: .medium))
                .frame(width: 25, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(model.annotationShadowsEnabled
                                ? Color.accentColor.opacity(0.20) : .clear)
                )
                .foregroundStyle(model.annotationShadowsEnabled
                                    ? Color.accentColor : Color.primary.opacity(0.65))
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.borderless)
        .screenshotIconHover()
        .screenshotSafeHelp(strings.shadowLabel)
        .accessibilityLabel(strings.shadowLabel)
        .accessibilityAddTraits(model.annotationShadowsEnabled ? .isSelected : [])
    }

    private var backdropButton: some View {
        Button {
            backdropPopoverShown.toggle()
        } label: {
            ZStack {
                switch model.backdropStyle.sanitized().kind {
                case .none:
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.85))
                case .image:
                    Image(systemName: "photo.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.85))
                case .preset, .solid, .gradient:
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .fill(fillPreview(for: model.backdropStyle))
                        .frame(width: 18, height: 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                                .strokeBorder(.white.opacity(0.7), lineWidth: 1)
                        )
                }
            }
            .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .screenshotIconHover()
        .screenshotSafeHelp(strings.backdropLabel)
        .accessibilityLabel(strings.backdropLabel)
        .popover(isPresented: $backdropPopoverShown, arrowEdge: .trailing) {
            ScreenshotBackdropPopover(model: model)
        }
    }

    private var watermarkButton: some View {
        let active = model.showsWatermark
        return Button {
            watermarkTool.toggle(model: model)
        } label: {
            Image(systemName: "signature")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(active ? Color.accentColor : Color.primary.opacity(0.85))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.borderless)
        .screenshotIconHover()
        .screenshotSafeHelp(strings.watermarkLabel)
        .accessibilityLabel(strings.watermarkLabel)
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
        .background(ScreenshotWatermarkToolAnchor(presenter: watermarkTool))
    }

    private func fillPreview(for style: ScreenshotSupport.BackdropStyle) -> LinearGradient {
        let colors = BackdropPickerAssets.previewColors(for: style)
        return LinearGradient(colors: colors,
                              startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Corner chips

    private var infoChip: some View {
        HStack(spacing: 8) {
            dragOutHandle
                .onHover { proxyHovered = $0 }
                .onDisappear { proxyHovered = false }
            ZStack(alignment: .leading) {
                Text(dimensionsLabel).opacity(proxyHovered ? 0 : 1)
                Text(refinementStrings.dragPlace).opacity(proxyHovered ? 1 : 0)
            }
            .font(.system(size: 11, weight: .medium).monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(dimensionsLabel)
        }
        .animation(.easeInOut(duration: 0.16), value: proxyHovered)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background {
            Capsule(style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(colorScheme == .light ? 0.08 : 0.22), radius: 6, y: 2)
        }
    }

    private var zoomChip: some View {
        HStack(spacing: 3) {
            zoomButton(active: model.zoomOverride == nil, help: refinementStrings.fitImage + "  (⌘0)") {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 11, weight: .medium))
            } action: {
                model.zoomOverride = nil
            }
            Text(zoomPercentLabel)
                .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 38)
                .lineLimit(1)
                .fixedSize()
            zoomButton(active: isActualZoom, help: refinementStrings.actualSize + "  (⌘1)") {
                Text("1:1")
                    .font(.system(size: 11, weight: .medium))
            } action: {
                model.zoomOverride = 1 / model.scale
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(colorScheme == .light ? 0.08 : 0.22), radius: 6, y: 2)
        }
        .screenshotSafeHelp("⌃ scroll · ⌘+ ⌘-")
    }

    private func zoomButton<Label: View>(active: Bool,
                                         help: String,
                                         @ViewBuilder label: () -> Label,
                                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            label()
                .frame(width: 30, height: 20)
                .background(active ? Color.accentColor : .clear,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .foregroundStyle(active ? Color.white : Color.primary.opacity(0.85))
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.borderless)
        .screenshotIconHover()
        .screenshotSafeHelp(help)
    }

    private var isActualZoom: Bool {
        guard let override = model.zoomOverride else { return false }
        return abs(override - 1 / model.scale) < 0.001
    }

    private var zoomPercentLabel: String {
        let zoom = model.zoomOverride ?? model.currentDisplayZoom
        return "\(Int((zoom * model.scale * 100).rounded()))%"
    }

    private var dimensionsLabel: String {
        let width = model.baseImage.width
        let height = model.baseImage.height
        return "\(width) × \(height) px"
    }

    /// A draggable control that exports the flattened PNG. Lives in infoChip
    /// (bottom row), not the top toolbar — that region overlaps the
    /// window's real system title bar, where no subview-level override
    /// can reliably stop AppKit from treating a click as "move the
    /// window."
    private var dragOutHandle: some View {
        Label(strings.dragOutHandleLabel, systemImage: "arrow.up.doc")
            .labelStyle(.iconOnly)
            .font(.system(size: 11, weight: .medium))
            .frame(width: 26, height: 18)
            .contentShape(Rectangle())
            .onDrag {
                commitEditingTextIfNeeded()
                guard let export = model.exportImage(),
                      let provider = ScreenshotService.dragItemProvider(
                          image: export.image,
                          scale: export.scale,
                          strings: strings
                      )
                else { return NSItemProvider() }
                model.markExported()
                return provider
            }
            .screenshotIconHover()
            .screenshotSafeHelp(refinementStrings.dragPlace)
            .accessibilityLabel(refinementStrings.dragPlace)
    }
}

private struct ScreenshotEditorSharedLinkView: View {
    let record: ScreenshotShareRecord
    let strings: ScreenshotFeatureStrings
    let close: () -> Void
    @State private var deleting = false
    @State private var showingDeleteError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label(strings.sharedLinksTitle, systemImage: "link")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button(strings.done, action: close)
                    .keyboardShortcut(.defaultAction)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(record.url.absoluteString)
                    .font(.system(.body, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                HStack(spacing: 4) {
                    Text(strings.expiresLabel)
                    Text(record.expiresAt, style: .relative)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.055),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
            }

            HStack {
                Spacer()
                Button {
                    if ScreenshotShareService.shared.copy(record.url) {
                        QuickToolHUD.show(icon: "link", message: strings.sharedHUD)
                    } else {
                        NSSound.beep()
                    }
                } label: {
                    Label(strings.copyLink, systemImage: "doc.on.doc")
                }
                .keyboardShortcut("c", modifiers: .command)
                Button(role: .destructive) {
                    deleteLink()
                } label: {
                    if deleting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(strings.deleteLink, systemImage: "trash")
                    }
                }
                .disabled(deleting)
            }
        }
        .padding(20)
        .frame(width: 480)
        .alert(strings.deleteFailedHUD, isPresented: $showingDeleteError) {
            Button(strings.done, role: .cancel) {}
        }
    }

    private func deleteLink() {
        deleting = true
        Task { @MainActor in
            do {
                try await ScreenshotShareService.shared.delete(record)
                QuickToolHUD.show(icon: "link", message: strings.linkDeletedHUD)
                close()
            } catch {
                deleting = false
                showingDeleteError = true
            }
        }
    }
}

extension ScreenshotSupport.Tool {
    var screenshotSymbolName: String {
        switch self {
        case .select: return "cursorarrow"
        case .arrow: return "arrow.up.right"
        case .line: return "line.diagonal"
        case .rect: return "rectangle"
        case .ellipse: return "circle"
        case .freehand: return "scribble.variable"
        case .highlight: return "highlighter"
        case .text: return "textformat"
        case .sticker: return "face.smiling"
        case .counter: return "1.circle"
        case .pixelate: return "aqi.medium"
        case .redact: return "rectangle.fill"
        case .crop: return "crop"
        }
    }

    func screenshotTitle(_ strings: ScreenshotFeatureStrings) -> String {
        switch self {
        case .select: return strings.toolSelect
        case .arrow: return strings.toolArrow
        case .line: return strings.toolLine
        case .rect: return strings.toolRect
        case .ellipse: return strings.toolEllipse
        case .freehand: return strings.toolFreehand
        case .highlight: return strings.toolHighlight
        case .text: return strings.toolText
        case .sticker: return strings.toolSticker
        case .counter: return strings.toolCounter
        case .pixelate: return strings.toolBlur
        case .redact: return strings.toolRedact
        case .crop: return strings.toolCrop
        }
    }
}

extension ScreenshotSupport.BlurStyleID {
    var screenshotSymbolName: String {
        switch self {
        case .pixelate: return "aqi.medium"
        case .blur: return "drop.halffull"
        case .erase: return "eraser"
        }
    }
}

/// Small samples of each arrow style, drawn by the editor's own renderer so
/// the menu and the toolbar show exactly what a stroke will look like. They
/// are templates, so menus tint them like their text.
private enum ScreenshotArrowStyleSamples {
    private static let images: [ScreenshotSupport.ArrowStyleID: NSImage] = Dictionary(
        uniqueKeysWithValues: ScreenshotSupport.ArrowStyleID.allCases.map { ($0, render($0)) })

    static func image(for style: ScreenshotSupport.ArrowStyleID) -> NSImage {
        images[style] ?? render(style)
    }

    private static func render(_ style: ScreenshotSupport.ArrowStyleID) -> NSImage {
        let size = NSSize(width: 36, height: 16)
        let image = NSImage(size: size)
        image.isTemplate = true
        // Rasterized at 2x so the sample stays crisp on Retina displays.
        let scale: CGFloat = 2
        let pixels = CGSize(width: size.width * scale, height: size.height * scale)
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                            pixelsWide: Int(pixels.width),
                                            pixelsHigh: Int(pixels.height),
                                            bitsPerSample: 8,
                                            samplesPerPixel: 4,
                                            hasAlpha: true,
                                            isPlanar: false,
                                            colorSpaceName: .deviceRGB,
                                            bytesPerRow: 0,
                                            bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext
        else { return image }
        bitmap.size = size
        // The renderer works in top-down image pixels.
        context.translateBy(x: 0, y: pixels.height)
        context.scaleBy(x: 1, y: -1)
        // A thin sample; the fixed seed keeps the scribbly one stable.
        let sample = ScreenshotSupport.Annotation(
            tool: .arrow,
            points: [CGPoint(x: 3 * scale, y: pixels.height / 2),
                     CGPoint(x: pixels.width - 3 * scale, y: pixels.height / 2)],
            color: .black,
            stroke: .small,
            arrowStyle: style,
            scribbleSeed: 0x5343524942424C59)
        ScreenshotRenderer.drawAnnotations([sample],
                                           in: context,
                                           blurSources: .none,
                                           imageSize: pixels,
                                           scale: scale,
                                           annotationShadowsEnabled: false)
        image.addRepresentation(bitmap)
        return image
    }
}



private struct SideBarAvailableHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

