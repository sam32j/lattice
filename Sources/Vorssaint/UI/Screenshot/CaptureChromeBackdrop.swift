import SwiftUI

private struct CaptureChromeOverlapKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    var captureChromeOverlapsSelection: Bool {
        get { self[CaptureChromeOverlapKey.self] }
        set { self[CaptureChromeOverlapKey.self] = newValue }
    }
}

/// A calibrated solid plate over the material keeps text readable against frozen
/// screenshots too. Overlap strengthens it without changing panel hit testing.
struct CaptureChromeBackdrop<S: Shape>: View {
    let material: Material
    let shape: S
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.captureChromeOverlapsSelection) private var overlapsSelection

    var body: some View {
        shape.fill(material)
            .overlay(shape.fill(colorScheme == .dark ? Color.black : Color.white)
                .opacity(CapturePresentationPolicy.plateOpacity(dark: colorScheme == .dark,
                    overlapsSelection: overlapsSelection, reduceTransparency: reduceTransparency)))
            .allowsHitTesting(false)
    }
}
