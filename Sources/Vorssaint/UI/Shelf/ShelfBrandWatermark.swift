import SwiftUI

struct ShelfBrandWatermark: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        BrandMark(width: 128, tint: colorScheme == .light ? Color.black : Color.white)
            .opacity(colorScheme == .light ? 0.05 : 0.08)
            .rotationEffect(.degrees(-8))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .offset(x: 34, y: 26)
            .allowsHitTesting(false)
    }
}
