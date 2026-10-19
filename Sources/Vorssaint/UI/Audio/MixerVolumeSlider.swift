import AppKit
import SwiftUI

struct MixerVolumeSlider: View {
    @Binding var value: Double
    let normalTint: Color
    let boostTint: Color
    let isBoosting: Bool
    let accentRevision: Int
    let glassEnabled: Bool
    let maximum: Double
    let accessibilityLabel: String

    private var activeTint: Color { isBoosting ? boostTint : normalTint }
    private var percentage: Int { Int((value * 100).rounded()) }

    var body: some View {
        Group {
#if compiler(>=6.2)
            if #available(macOS 26.0, *), glassEnabled {
                LiquidGlassMixerSlider(value: $value,
                                       tint: activeTint,
                                       isBoosting: isBoosting,
                                       maximum: maximum,
                                       accessibilityLabel: accessibilityLabel)
            } else {
                nativeSlider
                    .accessibilityLabel(accessibilityLabel)
                    .accessibilityValue("\(percentage)%")
            }
#else
            nativeSlider
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue("\(percentage)%")
#endif
        }
    }

    private var nativeSlider: some View {
        Slider(value: $value, in: 0...maximum)
            .controlSize(.small)
            // Pass an explicit accent (not nil) for the normal state: on the
            // macOS slider, tint(nil) does not reliably clear a previously
            // applied colour, so the bar would stay amber after leaving boost.
            .tint(activeTint)
            .id(accentRevision)
    }
}

#if compiler(>=6.2)
@available(macOS 26.0, *)
private struct LiquidGlassMixerSlider: View {
    @Binding var value: Double
    let tint: Color
    let isBoosting: Bool
    let maximum: Double
    let accessibilityLabel: String
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    private let knobWidth: CGFloat = 24
    private let knobHeight: CGFloat = 15
    private let trackHeight: CGFloat = 5

    private var progress: CGFloat {
        let clamped = min(max(value, 0), maximum)
        return CGFloat(clamped / maximum)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, knobWidth)
            let amount = progress
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(trackOpacity))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(tint)
                    .frame(width: max(trackHeight, width * amount), height: trackHeight)
                    .shadow(color: tint.opacity(0.18), radius: 3)

                knob
                    .frame(width: knobWidth, height: knobHeight)
                    .offset(x: (width - knobWidth) * amount)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .animation(.easeOut(duration: 0.16), value: amount)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        updateValue(at: gesture.location.x, width: width)
                    }
            )
        }
        .frame(height: knobHeight)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(Int((value * 100).rounded()))%")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                value = min(maximum, value + 0.05)
            case .decrement:
                value = max(0, value - 0.05)
            @unknown default:
                break
            }
        }
    }

    private var trackOpacity: Double {
        colorScheme == .light ? 0.11 : 0.16
    }

    private var knob: some View {
        ZStack {
            knobFill
            Capsule()
                .strokeBorder(tint.opacity(isBoosting ? 0.55 : 0.36), lineWidth: isBoosting ? 1.1 : 0.8)
            Capsule()
                .fill(
                    LinearGradient(colors: [
                        Color.white.opacity(colorScheme == .light ? 0.48 : 0.28),
                        Color.white.opacity(0.06)
                    ], startPoint: .top, endPoint: .bottom)
                )
                .blendMode(.screen)
                .padding(1)
        }
        .shadow(color: tint.opacity(isBoosting ? 0.24 : 0.16), radius: 3, x: 0, y: 0)
        .shadow(color: Color.black.opacity(colorScheme == .light ? 0.08 : 0.18), radius: 2, x: 0, y: 1)
    }

    @ViewBuilder
    private var knobFill: some View {
        if reduceTransparency {
            Capsule()
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(Capsule().fill(tint.opacity(colorScheme == .light ? 0.10 : 0.16)))
        } else {
            Color.clear
                .glassEffect(.regular.tint(tint.opacity(isBoosting ? 0.18 : 0.10)).interactive(), in: Capsule())
        }
    }

    private func updateValue(at x: CGFloat, width: CGFloat) {
        let travel = max(width - knobWidth, 1)
        let normalized = min(max((x - knobWidth / 2) / travel, 0), 1)
        value = Double(normalized) * maximum
    }
}
#endif
