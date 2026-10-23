#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

enum MediaHUDRenderingProbe {
    static func run(output: URL, failures: inout [String]) {
        guard let identity = Bundle.main.bundleIdentifier, identity.hasPrefix("com.vorssaint.tests.") else {
            failures.append("HUD probe requires an isolated test bundle."); return
        }
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: DefaultsKey.notchEnabled)
        defaults.set(true, forKey: DefaultsKey.shelfEnabled)
        defaults.set(MediaHUDLocation.window.rawValue, forKey: MediaHUDLocation.preferenceKey)
        SettingsRefactorProbe.render("hud-empty", view: AnyView(MediaHUDView(model: MediaHUDModel())
            .frame(width: 350).background(HUDBackdrop(cornerRadius: 18))),
            size: CGSize(width: 370, height: 400), output: output, failures: &failures)
        do {
            let image = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 512, pixelsHigh: 256,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            let context = CGContext(data: image.bitmapData!, width: 512, height: 256, bitsPerComponent: 8,
                bytesPerRow: image.bytesPerRow, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.setFillColor(CGColor(red: 0.12, green: 0.4, blue: 0.85, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 512, height: 256))
            context.setFillColor(CGColor(red: 1, green: 0.8, blue: 0.2, alpha: 1))
            context.fillEllipse(in: CGRect(x: 250, y: 30, width: 190, height: 190))
            let input = output.appendingPathComponent("sample.jpg")
            try image.representation(using: .jpeg, properties: [.compressionFactor: 1])!.write(to: input)
            let shelf = ShelfService.shared
            settle(0.2)
            _ = shelf.addFiles([input])
            shelf.summon(); settle(0.3)
            SettingsRefactorProbe.render("shared-cache", view: AnyView(FileUtilityStandaloneView()),
                size: CGSize(width: 370, height: 500), output: output, failures: &failures)
            SettingsRefactorProbe.render("cache-original-chrome", view: AnyView(ShelfView(brandWatermark: true)
                .environmentObject(shelf)), size: CGSize(width: 370, height: 500), output: output, failures: &failures)
            let panel = shelf.ensurePanel()
            let kept = shelf.items.map(\.id)
            let session = FileUtilitySession.shared
            session.beginDrag(sharedStandalone: true, optimizerAvailable: true, option: false)
            session.updateDrag(option: true)
            shelf.refitSharedUtility(); settle(0.3)
            SettingsRefactorProbe.render("shared-optimizer", view: AnyView(FileUtilityStandaloneView()),
                size: CGSize(width: 370, height: 500), output: output, failures: &failures)
            if shelf.ensurePanel() !== panel || session.effectiveMode != .optimizer {
                failures.append("Option preview did not reuse the File Cache panel.")
            }
            session.updateDrag(option: false); shelf.refitSharedUtility(); settle(0.2)
            if session.effectiveMode != .cache || shelf.items.map(\.id) != kept {
                failures.append("Option release did not restore unchanged File Cache content.")
            }
            let released = output.appendingPathComponent("released-option.jpg")
            try FileManager.default.copyItem(at: input, to: released)
            let board = NSPasteboard.withUniqueName()
            defer { board.releaseGlobally() }
            board.writeObjects([released as NSURL])
            let routing = FileUtilityPresentation(optionIsHeld: { false })
            let receiver = MediaHUDDropReceiver.Receiver()
            receiver.canAccept = routing.canAccept; receiver.accept = routing.accept
            session.updateDrag(option: true)
            let releaseDrag = MediaHUDDragFixture(board: board, window: panel)
            if !receiver.performDragOperation(releaseDrag) || session.effectiveMode != .cache || shelf.itemCount != kept.count + 1 {
                failures.append("A child drop receiver did not return an immediately released Option drop to File Cache.")
            }
            let retained = shelf.items.map(\.id)
            session.beginDrag(sharedStandalone: true, optimizerAvailable: true, option: true)
            session.updateDrag(option: true)
            let model = MediaHUDModel.shared
            if !model.receive([input]) { failures.append("HUD did not accept its local image fixture.") }
            session.commitDrop(); session.updateDrag(option: false); session.endDrag()
            let deadline = Date().addingTimeInterval(10)
            while model.busy && Date() < deadline { settle(0.01) }
            guard case .completed = model.service.state else { throw NativeMediaError.invalidOutput }
            shelf.refitSharedUtility(); settle(0.3)
            if shelf.ensurePanel() !== panel || session.effectiveMode != .optimizer || shelf.items.map(\.id) != retained {
                failures.append("Committed MO job changed its window or File Cache contents.")
            }
            if !panel.frame.width.isFinite || panel.frame.height < 150 || panel.frame.height > 850 {
                failures.append("Shared HUD has invalid geometry: \(panel.frame)")
            }
            SettingsRefactorProbe.render("hud-result", view: AnyView(MediaHUDView(model: model).frame(width: 350)
                .background(HUDBackdrop(cornerRadius: 18))), size: CGSize(width: 370, height: 500),
                output: output, failures: &failures)
            SettingsRefactorProbe.render("hud-island", view: AnyView(MediaHUDView(model: model)
                .environment(\.notchPresentation, true).foregroundStyle(.white).colorScheme(.dark)
                .background(.black).clipShape(RoundedRectangle(cornerRadius: 28))),
                size: CGSize(width: 500, height: 500), output: output, failures: &failures, colorScheme: .dark)
            try MediaHUDStateRenderingProbe.run(input: input, output: output, failures: &failures)
            FileUtilityPresentation.shared.select(.cache); settle(0.2)
            FileUtilityPresentation.shared.select(.optimizer); settle(0.2)
            if shelf.ensurePanel() !== panel || shelf.items.map(\.id) != retained || model.outputs.isEmpty {
                failures.append("Explicit mode switching lost the panel, cache or optimizer result.")
            }
            print("MEDIA_HUD_SHARED_PANEL_OK frame=\(panel.frame) cached=\(shelf.itemCount) outputs=\(model.outputs.count)")
            shelf.hide()
            shelf.clear()
            settle(0.1)
            if let container = PrivateFileStore.containerURL, container.lastPathComponent == identity {
                try? FileManager.default.removeItem(at: container)
            }
        } catch { failures.append("HUD integration fixture: \(error)") }
    }
    private static func settle(_ seconds: TimeInterval) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
}
#endif
