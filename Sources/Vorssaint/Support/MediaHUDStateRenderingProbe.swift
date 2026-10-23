#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Real model state transitions at an isolated encoder boundary. No system
/// dialogs, hardware input, user clipboard or real preferences are involved.
enum MediaHUDStateRenderingProbe {
    static func run(input: URL, output: URL, failures: inout [String]) throws {
        render("hud-empty-dark", model: MediaHUDModel(), dark: true, output: output, failures: &failures)
        let second = output.appendingPathComponent("second-image-with-a-long-name.jpg")
        try FileManager.default.copyItem(at: input, to: second)
        let batch = MediaHUDModel()
        guard batch.receive([input, second]) else { throw NativeMediaError.invalidOutput }
        wait(batch)
        guard case .completed = batch.service.state else { throw NativeMediaError.invalidOutput }
        render("hud-batch", model: batch, output: output, failures: &failures)
        batch.selectedIndex = 1; batch.showsOriginal = true
        render("hud-original-dark", model: batch, dark: true, output: output, failures: &failures)

        let gate = DispatchSemaphore(value: 0)
        let busy = MediaHUDModel(service: MediaService(makeClient: {
            MediaOptimizerClient(optimize: { _, _, _ in
                _ = gate.wait(timeout: .now() + 30)
                throw CancellationError()
            }, cancel: { gate.signal() })
        }))
        defer { busy.cancel(); gate.signal() }
        guard busy.receive([input, second]), busy.busy else { throw NativeMediaError.invalidOutput }
        render("hud-busy", model: busy, output: output, failures: &failures)
        render("hud-busy-island", model: busy, dark: true, island: true, output: output, failures: &failures)

        let failed = MediaHUDModel(service: MediaService(makeClient: {
            MediaOptimizerClient(optimize: { _, _, _ in throw CocoaError(.fileWriteNoPermission) }, cancel: {})
        }))
        guard failed.receive([input]) else { throw NativeMediaError.invalidOutput }
        wait(failed)
        guard case .failed = failed.service.state else { throw NativeMediaError.invalidOutput }
        render("hud-error", model: failed, output: output, failures: &failures)
        render("hud-error-island", model: failed, dark: true, island: true, output: output, failures: &failures)

        let destination = MediaHUDModel(writable: { _ in false })
        guard destination.receive([input]), destination.needsDestination else { throw NativeMediaError.invalidOutput }
        render("hud-destination", model: destination, output: output, failures: &failures)
        _ = destination.receive([input, output.appendingPathComponent("unsupported.pdf")])
        render("hud-invalid-drop-dark", model: destination, dark: true, output: output, failures: &failures)
    }

    private static func wait(_ model: MediaHUDModel) {
        let deadline = Date().addingTimeInterval(10)
        while model.busy && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
    }

    private static func render(_ name: String, model: MediaHUDModel, dark: Bool = false, island: Bool = false,
                               output: URL, failures: inout [String]) {
        let view = MediaHUDView(model: model).frame(width: 350)
            .environment(\.notchPresentation, island)
        let host = NSHostingView(rootView: view)
        host.frame.size.width = 350
        host.layoutSubtreeIfNeeded()
        let fitted = host.fittingSize
        if !fitted.height.isFinite || fitted.height < 150 || fitted.height > 620 {
            failures.append("Invalid HUD state height for \(name): \(fitted)")
        }
        SettingsRefactorProbe.render(name, view: AnyView(view
            .background(island ? Color.black : Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 18))),
            size: CGSize(width: 370, height: max(400, fitted.height + 20)), output: output, failures: &failures,
            colorScheme: dark ? .dark : .light)
    }
}
#endif
