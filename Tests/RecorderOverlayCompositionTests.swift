// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import CoreImage

enum RecorderOverlayCompositionTests {
    static func run(_ suite: TestSuite) {
        let canvas = CGRect(x: 0, y: 0, width: 400, height: 300)
        let desktop = CIImage(color: CIColor(red: 0, green: 0, blue: 1)).cropped(to: canvas)
        let camera = CIImage(color: CIColor(red: 1, green: 0, blue: 0))
            .cropped(to: CGRect(x: 0, y: 0, width: 100, height: 80))
        var layout = RecorderCameraLayout()
        layout.size = .small
        let compositor = RecorderOverlayCompositor()
        guard let composed = try? compositor.image(screen: desktop, camera: camera, layout: layout, keyImage: nil)
        else { suite.expect(false, "synthetic camera composition succeeds"); return }
        let pip = layout.frame(in: canvas.size)
        suite.expect(pixel(composed, CGPoint(x: pip.midX, y: pip.midY))[0] > 240,
                     "recorded frames contain the camera at the PiP center")
        suite.expect(pixel(composed, CGPoint(x: pip.minX + 2, y: pip.minY + 2))[2] > 240,
                     "circle mask preserves desktop pixels outside its circle")
        layout.isFullArea = true
        guard let full = try? compositor.image(screen: desktop, camera: camera, layout: layout, keyImage: nil)
        else { suite.expect(false, "full-area camera composition succeeds"); return }
        suite.expect(pixel(full, CGPoint(x: 2, y: 2))[0] > 240,
                     "full-area mode records camera pixels instead of the desktop even at canvas corners")
        suite.expect((try? compositor.image(screen: desktop, camera: nil, layout: layout, keyImage: nil)) == nil,
                     "camera-only recording fails closed if camera pixels disappear instead of exposing the desktop")
        layout.isFullArea = false
        guard let unchanged = try? compositor.image(screen: desktop, camera: nil, layout: layout, keyImage: nil)
        else { suite.expect(false, "camera-free composition succeeds"); return }
        suite.expect(pixel(unchanged, CGPoint(x: 20, y: 20))[2] > 240,
                     "camera-free composition preserves the source frame")
        for shape in RecorderCameraLayout.Shape.allCases {
            layout.shape = shape
            guard let masked = try? compositor.image(screen: desktop, camera: camera, layout: layout, keyImage: nil)
            else { suite.expect(false, "each camera shape can be composed"); continue }
            let frame = layout.frame(in: canvas.size)
            let corner = pixel(masked, CGPoint(x: frame.minX + 2, y: frame.minY + 2))
            suite.expect(shape == .circle ? corner[2] > 240 : corner[0] > 240,
                         "\(shape.rawValue) mask records its correct corner pixels")
        }
        layout.shape = .square
        let red = camera.cropped(to: CGRect(x: 0, y: 0, width: 50, height: 80))
        let green = CIImage(color: CIColor(red: 0, green: 1, blue: 0))
            .cropped(to: CGRect(x: 50, y: 0, width: 50, height: 80))
        let asymmetric = red.composited(over: green)
        let frame = layout.frame(in: canvas.size)
        let leftPoint = CGPoint(x: frame.minX + frame.width * 0.25, y: frame.midY)
        guard let normal = try? compositor.image(screen: desktop, camera: asymmetric, layout: layout, keyImage: nil)
        else { suite.expect(false, "asymmetric camera composition"); return }
        layout.isFlipped = true
        guard let flipped = try? compositor.image(screen: desktop, camera: asymmetric, layout: layout, keyImage: nil)
        else { suite.expect(false, "flipped camera composition"); return }
        suite.expect(pixel(normal, leftPoint)[0] > 240 && pixel(flipped, leftPoint)[1] > 240,
                     "horizontal flip changes camera pixels rather than just its preview")
        let key = CIContext().createCGImage(CIImage(color: CIColor(red: 0, green: 1, blue: 0)),
                                           from: CGRect(x: 0, y: 0, width: 32, height: 32))
        guard let withKeys = try? compositor.image(screen: desktop, camera: nil, layout: layout, keyImage: key)
        else { suite.expect(false, "key feedback composition"); return }
        suite.expect(pixel(withKeys, CGPoint(x: 200, y: 20))[1] > 240,
                     "recorded key feedback appears at the bottom center inside the selection")
    }

    static func pixel(_ image: CIImage, _ point: CGPoint) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 4)
        CIContext().render(image, toBitmap: &bytes, rowBytes: 4,
            bounds: CGRect(x: point.x.rounded(.down), y: point.y.rounded(.down), width: 1, height: 1),
            format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return bytes
    }
}
