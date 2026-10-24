#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

/// Renders the production overlays without instantiating any playback service,
/// requesting grants, posting events or mounting the live island lifecycle.
@MainActor
enum NotchMusicSwipeRenderingProbe {
    static func runAndExit() -> Never {
        guard let identity = Bundle.main.bundleIdentifier, identity.hasPrefix("com.vorssaint.tests."),
              let index = CommandLine.arguments.firstIndex(of: "--output-directory"),
              CommandLine.arguments.indices.contains(index + 1) else { exit(2) }
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        let output = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            try verifyRestingDelivery()
            for reduced in [false, true] {
                for scheme in [ColorScheme.light, .dark] {
                    let view = VStack(alignment: .leading, spacing: 16) {
                        Text("Music swipe · \(reduced ? "Reduce Motion" : "Full motion")")
                        ForEach([0.0, 0.5, 1.0], id: \.self) { progress in
                            HStack(spacing: 28) {
                                Text("\(Int(progress * 100))%").frame(width: 40)
                                forDirection(.previous, progress: progress, reduced: reduced)
                                forDirection(.next, progress: progress, reduced: reduced)
                            }
                        }
                    }
                    .font(.system(size: 13)).foregroundStyle(scheme == .dark ? .white : .black)
                    .padding(24).frame(width: 500)
                    .background(scheme == .dark ? Color(white: 0.12) : Color(white: 0.93))
                    .environment(\.colorScheme, scheme)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 2
                    guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                          let bitmap = NSBitmapImageRep(data: tiff),
                          let png = bitmap.representation(using: .png, properties: [:]) else {
                        throw CocoaError(.fileWriteUnknown)
                    }
                    try png.write(to: output.appendingPathComponent("swipe-\(scheme)-reduced-\(reduced).png"))
                }
            }
            print("MUSIC_SWIPE_RENDERING_OK output=\(output.path)")
            exit(0)
        } catch {
            fputs("MUSIC_SWIPE_RENDERING_FAILED \(error)\n", stderr)
            exit(1)
        }
    }

    private static func verifyRestingDelivery() throws {
        let geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1440, height: 900),
                                     safeAreaTop: 0, cameraWidth: 0)
        let host = NotchWindowHost(content: AnyView(Color.black), geometry: geometry, size: geometry.collapsed,
                                  quickAccess: { _, _ in AnyView(Color.clear) })
        defer { host.close() }
        func receivers(in view: NSView) -> Int {
            let own = view.allowedTouchTypes.contains(.indirect) && view.wantsRestingTouches ? 1 : 0
            return own + view.subviews.reduce(0) { $0 + receivers(in: $1) }
        }
        guard let root = host.panel.contentView, receivers(in: root) >= 2 else {
            throw NSError(domain: "MusicSwipeProbe", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "The hosting view and container must retain resting touches."])
        }
        print("MUSIC_SWIPE_RESTING_RECEIVERS_OK")
    }

    private static func forDirection(_ direction: NotchMusicTrackSwipe.Direction, progress: Double, reduced: Bool) -> some View {
        HStack(spacing: 16) {
            NotchMusicSwipeVisualizer(frame: .init(direction: direction, progress: progress), height: 18, reduceMotionOverride: reduced) {
                Image(systemName: "waveform").font(.system(size: 16)).foregroundStyle(.white)
            }
            .frame(width: 40, height: 40).background(.black, in: Capsule())
            Image(systemName: direction == .next ? "forward.fill" : "backward.fill")
                .font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background {
                    NotchMusicSwipeBackdrop(direction: direction,
                        frame: .init(direction: direction, progress: progress, expanded: true), size: 44, reduceMotionOverride: reduced)
                }
                .padding(8).background(.black, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}
#endif
