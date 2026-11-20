import SwiftUI
import AppKit

/// Prevent Lists from supplying their entire document as the window's ideal
/// height. Non-scrolling headers stay inside the detail viewport as well.
///
/// The clip is sideways only. A page's scroll view already reaches up under
/// the title bar (it insets its content by the toolbar's height), and the
/// title bar's frosted scroll-edge material washes that content out, as in
/// System Settings. Clipping vertically cut the drawing off at the bottom of
/// the title bar, which left the bar a solid slab with nothing behind it.
struct SettingsDetailViewport<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geometry in
            content()
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
                .clipShape(SettingsSidewaysClip())
        }
    }
}

/// Clips left and right only; above and below are left open.
private struct SettingsSidewaysClip: Shape {
    func path(in rect: CGRect) -> Path {
        Path(rect.insetBy(dx: 0, dy: -10_000))
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
