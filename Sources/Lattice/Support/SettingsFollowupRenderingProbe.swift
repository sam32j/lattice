#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

enum SettingsFollowupRenderingProbe {
    static func run(output: URL, failures: inout [String]) {
        guard Bundle.main.bundleIdentifier?.hasPrefix("io.github.sam32j.lattice.tests.") == true else {
            failures.append("Follow-up rendering requires an isolated test bundle."); return
        }
        for dark in [false, true] {
            for overlaps in [false, true] {
                let label = "capture-chrome-\(dark ? "dark" : "light")-\(overlaps ? "overlap" : "normal")"
                let chrome = ZStack {
                    HStack(spacing: 0) {
                        ForEach(0..<12) { index in (index.isMultiple(of: 2) ? Color.black : Color.white) }
                    }
                    HStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                        Text("Select a window or drag an area").fontWeight(.semibold)
                        Image(systemName: "xmark")
                    }
                    .foregroundStyle(.primary).padding(16)
                    .background(CaptureChromeBackdrop(material: .ultraThinMaterial,
                        shape: RoundedRectangle(cornerRadius: 16)))
                    .environment(\.colorScheme, dark ? .dark : .light)
                    .opacity(CapturePresentationPolicy.toolbarOpacity(overlapsSelection: overlaps, isDragging: overlaps))
                }.frame(height: 150).padding(22)
                render(label, AnyView(chrome), height: 200, output: output, failures: &failures)
            }
        }
    }

    private static func render(_ name: String, _ view: AnyView, height: CGFloat,
                               output: URL, failures: inout [String]) {
        SettingsRefactorProbe.render(name, view: view, size: CGSize(width: 760, height: height),
                                    output: output, failures: &failures)
    }
}
#endif
