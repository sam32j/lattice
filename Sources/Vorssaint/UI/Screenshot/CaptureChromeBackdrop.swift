import SwiftUI

/// A calibrated solid plate over the material keeps text readable against frozen
/// screenshots too. Selection overlap is handled by fading the whole toolbar.
struct CaptureChromeBackdrop<S: Shape>: View {
    let material: Material
    let shape: S
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        shape.fill(material)
            .overlay(shape.fill(colorScheme == .dark ? Color.black : Color.white)
                .opacity(CapturePresentationPolicy.plateOpacity(dark: colorScheme == .dark,
                    reduceTransparency: reduceTransparency)))
            .allowsHitTesting(false)
    }
}
