import AppKit
import SwiftUI

struct MenuBarUsageBarSettings: View {
    let strings: MenuBarAppearanceStrings
    let colorsTitle: String

    @AppStorage(DefaultsKey.menuBarUsageBarNormalColor) private var normalColor = MenuBarUsageBarSupport.defaultNormalColor
    @AppStorage(DefaultsKey.menuBarUsageBarElevatedColor) private var elevatedColor = MenuBarUsageBarSupport.defaultElevatedColor
    @AppStorage(DefaultsKey.menuBarUsageBarCriticalColor) private var criticalColor = MenuBarUsageBarSupport.defaultCriticalColor
    @AppStorage(DefaultsKey.menuBarUsageBarMediumThreshold) private var mediumThreshold = MenuBarUsageBarSupport.defaultMediumThreshold
    @AppStorage(DefaultsKey.menuBarUsageBarHighThreshold) private var highThreshold = MenuBarUsageBarSupport.defaultHighThreshold

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            // The three colors side by side, named in their tooltips, in the
            // order the bar fills.
            SettingsControlRow(title: colorsTitle) {
                HStack(spacing: 10) {
                    colorWell(strings.normalColor, $normalColor, fallback: MenuBarUsageBarSupport.defaultNormalColor)
                    colorWell(strings.mediumColor, $elevatedColor, fallback: MenuBarUsageBarSupport.defaultElevatedColor)
                    colorWell(strings.highColor, $criticalColor, fallback: MenuBarUsageBarSupport.defaultCriticalColor)
                }
            }
            SettingsControlRow(title: strings.mediumFrom) { percentStepper(mediumBinding, range: 1...99) }
            SettingsControlRow(title: strings.highFrom) { percentStepper(highBinding, range: 2...100) }
        }
        .onAppear(perform: sanitize)
    }

    private func colorWell(_ name: String, _ storage: Binding<String>, fallback: String) -> some View {
        ColorPicker(name, selection: colorBinding(storage, fallback: fallback), supportsOpacity: false)
            .labelsHidden()
            .help(name)
    }

    private func percentStepper(_ value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 6) {
            Text("\(value.wrappedValue)%")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Stepper("", value: value, in: range)
                .labelsHidden()
        }
        .fixedSize()
    }

    private var mediumBinding: Binding<Int> {
        Binding(get: { mediumThreshold },
                set: { mediumThreshold = min(max(1, $0), max(1, highThreshold - 1)) })
    }

    private var highBinding: Binding<Int> {
        Binding(get: { highThreshold },
                set: { highThreshold = min(100, max(mediumThreshold + 1, $0)) })
    }

    private func colorBinding(_ storage: Binding<String>, fallback: String) -> Binding<Color> {
        Binding {
            let rgb = MenuBarUsageBarSupport.rgb(for: storage.wrappedValue, fallback: fallback)
            return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        } set: { color in
            guard let converted = NSColor(color).usingColorSpace(.sRGB) else { return }
            storage.wrappedValue = MenuBarUsageBarSupport.hex(red: Double(converted.redComponent),
                                                              green: Double(converted.greenComponent),
                                                              blue: Double(converted.blueComponent))
        }
    }

    private func sanitize() {
        normalColor = MenuBarUsageBarSupport.sanitizedColorHex(normalColor,
                                                               fallback: MenuBarUsageBarSupport.defaultNormalColor)
        elevatedColor = MenuBarUsageBarSupport.sanitizedColorHex(elevatedColor,
                                                                 fallback: MenuBarUsageBarSupport.defaultElevatedColor)
        criticalColor = MenuBarUsageBarSupport.sanitizedColorHex(criticalColor,
                                                                 fallback: MenuBarUsageBarSupport.defaultCriticalColor)
        let thresholds = MenuBarUsageBarSupport.thresholds(medium: mediumThreshold,
                                                           high: highThreshold)
        mediumThreshold = thresholds.medium
        highThreshold = thresholds.high
    }
}
