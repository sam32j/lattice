#if VORSSAINT_DEVELOPMENT
import AppKit
import SwiftUI

enum SettingsFollowupRenderingProbe {
    static func run(output: URL, failures: inout [String]) {
        guard Bundle.main.bundleIdentifier?.hasPrefix("com.vorssaint.tests.") == true else {
            failures.append("Follow-up rendering requires an isolated test bundle."); return
        }
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: DefaultsKey.notchEnabled)
        defaults.set(false, forKey: DefaultsKey.notchHidesMenuBarIcon)
        verifyAppMenuPicker(failures: &failures)
        render("menu-bar-visible", AnyView(GeneralToolSettings()), height: 1100, output: output, failures: &failures)
        defaults.set(true, forKey: DefaultsKey.notchHidesMenuBarIcon)
        render("menu-bar-hidden", AnyView(GeneralToolSettings()), height: 1100, output: output, failures: &failures)
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
                    .opacity(CapturePresentationPolicy.toolbarOpacity(overlapsSelection: overlaps, hovered: false))
                }.frame(height: 150).padding(22)
                render(label, AnyView(chrome), height: 200, output: output, failures: &failures)
            }
        }
    }

    /// Change persisted routing without reconstructing the host, then verify the
    /// actual SwiftUI popup's accessible value, not just the preference model.
    private static func verifyAppMenuPicker(failures: inout [String]) {
        let defaults = UserDefaults.standard
        AppMenuDestination.menuBar.save(in: defaults)
        let host = NSHostingView(rootView: SettingsCard { AppMenuDestinationSettings() }.padding(22))
        let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 760, height: 180),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        window.orderFrontRegardless()
        let getter = NSSelectorFromString("accessibilityAttributeValue:")
        let setter = NSSelectorFromString("accessibilitySetValue:forAttribute:")
        let prior = NSApp.perform(getter, with: "AXEnhancedUserInterface")?.takeUnretainedValue() as? NSNumber ?? false
        NSApp.perform(setter, with: true, with: "AXEnhancedUserInterface")
        defer {
            NSApp.perform(setter, with: prior, with: "AXEnhancedUserInterface")
            window.orderOut(nil); window.contentView = nil; window.close()
        }
        for target in [AppMenuDestination.none, .menuBar, .island] {
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            host.layoutSubtreeIfNeeded()
            let title: String
            switch target {
            case .none: title = SettingsOwnershipStrings.text(.none, .enUS)
            case .menuBar: title = L10n.shared.s.menuBarSection
            case .island: title = FeatureStrings.notch(.enUS).title
            }
            target.save(in: defaults)
            RunLoop.main.run(until: Date().addingTimeInterval(0.3))
            host.layoutSubtreeIfNeeded()
            let value = findPicker(in: host)?.perform(NSSelectorFromString("accessibilityValue"))?.takeUnretainedValue() as? String
            if AppMenuDestination.selected(in: defaults) != target || value != title {
                failures.append("App menu picker did not keep \(title) in sync with its rendering destination.")
            }
        }
    }

    private static func findPicker(in element: AnyObject) -> NSObject? {
        if element.accessibilityRole?() == .popUpButton { return element as? NSObject }
        for child in element.accessibilityChildren?() ?? [] {
            if let picker = findPicker(in: child as AnyObject) { return picker }
        }
        return nil
    }

    private static func render(_ name: String, _ view: AnyView, height: CGFloat,
                               output: URL, failures: inout [String]) {
        SettingsRefactorProbe.render(name, view: view, size: CGSize(width: 760, height: height),
                                    output: output, failures: &failures)
    }
}
#endif
