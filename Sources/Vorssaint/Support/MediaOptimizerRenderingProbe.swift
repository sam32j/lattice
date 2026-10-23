#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

enum MediaOptimizerRenderingProbe {
    static func run(output: URL, failures: inout [String]) {
        guard Bundle.main.bundleIdentifier?.hasPrefix("com.vorssaint.tests.") == true else {
            failures.append("Optimizer rendering requires an isolated bundle."); return
        }
        for tool in MediaTool.allCases {
            SettingsRefactorProbe.render("optimizer-\(tool.title.lowercased())", view: AnyView(
                MediaWorkspaceView(compact: false, media: MediaService(), initialTool: tool).padding(22)),
                size: CGSize(width: 760, height: 720), output: output, failures: &failures)
        }
        do {
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256,
                bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            memset(bitmap.bitmapData!, 160, bitmap.bytesPerRow * bitmap.pixelsHigh)
            let input = output.appendingPathComponent("sample.png")
            try bitmap.representation(using: .png, properties: [:])!.write(to: input)
            let media = MediaService()
            let workspace = MediaWorkspaceSelection()
            workspace.inputURLs = [input]; workspace.outputURL = output
            workspace.tool = .imageCompressor; workspace.loadedInitialInputs = true
            media.optimize(inputs: [input], destination: output, tool: .imageCompressor, aggressive: false)
            let deadline = Date().addingTimeInterval(10)
            while Date() < deadline {
                if case .running = media.state { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
                else { break }
            }
            if case .completed = media.state { }
            else { failures.append("Bundled optimizer did not complete its local PNG fixture: \(media.state)") }
            SettingsRefactorProbe.render("optimizer-result", view: AnyView(MediaWorkspaceView(compact: false,
                media: media, workspace: workspace).padding(22)), size: CGSize(width: 760, height: 720),
                output: output, failures: &failures)
        } catch { failures.append("Optimizer fixture: \(error)") }
    }
}
#endif
