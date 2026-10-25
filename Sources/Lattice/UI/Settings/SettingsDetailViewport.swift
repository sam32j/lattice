import SwiftUI
import AppKit

/// Prevent Lists from supplying their entire document as the window's ideal
/// height. Non-scrolling headers stay inside the detail viewport as well.
struct SettingsDetailViewport<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            content()
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .clipped()
        }
    }
}

/// AppKit's automatic separator can linger after returning to the scroll edge.
/// Keep it in lockstep with the native SwiftUI toolbar material's visibility.
struct SettingsToolbarBackdrop: NSViewRepresentable {
    let isScrolled: Bool

    func makeNSView(context: Context) -> SettingsToolbarBackdropView {
        SettingsToolbarBackdropView()
    }

    func updateNSView(_ view: SettingsToolbarBackdropView, context: Context) {
        view.isScrolled = isScrolled
    }
}

final class SettingsToolbarBackdropView: NSView {
    var isScrolled = false {
        didSet { applyAppearance() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyAppearance()
    }

    private func applyAppearance() {
        window?.titlebarAppearsTransparent = !isScrolled
        window?.titlebarSeparatorStyle = isScrolled ? .line : .none
    }
}
