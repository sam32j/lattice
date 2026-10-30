#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

enum NotchSettingsRenderingProbe {
    static func run(output: URL, failures: inout [String]) {
        guard Bundle.main.bundleIdentifier?.hasPrefix("io.github.sam32j.lattice.tests.") == true else {
            failures.append("Island settings rendering requires isolated preferences."); return
        }
        let defaults = UserDefaults.standard
        defaults.set(NotchIdleContent.none.rawValue, forKey: DefaultsKey.notchIdleContent)
        defaults.set(false, forKey: DefaultsKey.notchEnabled)
        SettingsRefactorProbe.render("island-disabled", view: AnyView(NotchSettings()),
            size: CGSize(width: 820, height: 360), output: output, failures: &failures)
        SettingsRefactorProbe.render("island-disabled-widget-route", view: AnyView(NotchSettings(initialContent: .module(.agents))),
            size: CGSize(width: 820, height: 360), output: output, failures: &failures)
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        defaults.set(true, forKey: DefaultsKey.notchOpenOnHover)
        defaults.set(true, forKey: DefaultsKey.notchHoverExpands)
        defaults.set(false, forKey: DefaultsKey.notchHideUntilHover)
        SettingsRefactorProbe.render("island-quick-actions", view: AnyView(NotchSettings().layoutPage.padding(22)),
            size: CGSize(width: 820, height: 200), output: output, failures: &failures)
        SettingsRefactorProbe.render("island-opening", view: AnyView(NotchSettings().openingCard.padding(22)),
            size: CGSize(width: 820, height: 680), output: output, failures: &failures)
        defaults.set(true, forKey: DefaultsKey.notchHideUntilHover)
        defaults.set(NotchIdleContent.battery.rawValue, forKey: DefaultsKey.notchIdleContent)
        NotchSettings().enforceIdleSelection()
        if defaults.string(forKey: DefaultsKey.notchIdleContent) != NotchIdleContent.none.rawValue {
            failures.append("Hide when idle did not persist Nothing.")
        }
        SettingsRefactorProbe.render("island-hidden-idle", view: AnyView(NotchSettings().activityPage.padding(22)),
            size: CGSize(width: 820, height: 1080), output: output, failures: &failures)
        defaults.set(false, forKey: DefaultsKey.notchHideUntilHover)
        SettingsRefactorProbe.render("island-activity", view: AnyView(NotchSettings().activityPage.padding(22)),
            size: CGSize(width: 820, height: 1080), output: output, failures: &failures)
        MainActor.assumeIsolated { renderReadings(output: output, failures: &failures) }
    }

    @MainActor private static func renderReadings(output: URL, failures: inout [String]) {
        let view = VStack(alignment: .leading, spacing: 24) {
            ForEach([24.0, 32.0, 38.0], id: \.self) { height in
                HStack(spacing: 20) {
                    Text("\(Int(height)) pt").frame(width: 42)
                    ForEach(["68%", "100%", "$12.34"], id: \.self) { value in
                        HStack(spacing: 0) {
                            NotchAgentIdleReading(leading: true, height: height, provider: .claude,
                                fraction: value.hasSuffix("%") ? 0.68 : nil, value: value, tint: .blue)
                                .padding(.leading, min(16, NotchLayout.shoulder(height: height) + NotchLayout.compactEdgeGap))
                                .offset(x: -1.5)
                                .frame(width: 44, height: height, alignment: .trailing)
                            Color.clear.frame(width: 120)
                            NotchAgentIdleReading(leading: false, height: height, provider: .claude,
                                fraction: nil, value: value)
                                .padding(.trailing, 8)
                                .frame(width: 44, height: height, alignment: .trailing)
                        }
                        .frame(height: height)
                        .background(.black, in: NotchShape(attached: true,
                            radius: NotchLayout.surfaceRadius(height: height), cutoutWidth: 120))
                    }
                }
            }
        }
        .font(.system(size: 12)).foregroundStyle(.white).padding(24).background(Color(white: 0.2))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else {
            failures.append("AI usage idle rendering failed"); return
        }
        do { try png.write(to: output.appendingPathComponent("ai-idle-readings.png")) }
        catch { failures.append("Cannot write AI idle render: \(error)") }
    }
}
#endif
