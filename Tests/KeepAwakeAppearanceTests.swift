import AppKit

// Native rendering runs with an isolated preferences domain, never the app's settings.
enum KeepAwakeAppearanceContract {
    static let domain = "io.github.sam32j.lattice.tests.awake-appearance.\(UUID())"
    static let defaults = UserDefaults(suiteName: domain)!
    enum AppInfo { static let name = "Lattice" }
}

enum KeepAwakeAppearanceTests {
    static func run(_ suite: TestSuite) {
        typealias C = KeepAwakeAppearanceContract
        defer { C.defaults.removePersistentDomain(forName: C.domain) }
        C.defaults.set("bolt.fill", forKey: DefaultsKey.menuBarIconSymbol)
        for appearanceName in [NSAppearance.Name.aqua, .darkAqua] {
            NSAppearance(named: appearanceName)!.performAsCurrentDrawingAppearance {
                for tint in ["orange", "green", "blue", "purple", "pink", "none", "unknown"] {
                    for icon in ["vorssaint", "coffee", "eye", "moon", "light", "unknown"] {
                        C.defaults.set(tint, forKey: "keepAwakeIconTint")
                        C.defaults.set(icon, forKey: "keepAwakeActiveIcon")
                        let inactive = C.BlackHoleGlyph.image(active: false)
                        let active = C.BlackHoleGlyph.image(active: true)
                        suite.expect(inactive?.isTemplate == true && active?.isTemplate == false,
                                     "active amber survives legacy \(tint)/\(icon) in \(appearanceName)")
                        suite.expect(active?.size == C.BlackHoleGlyph.pointSize && inactive?.size == active?.size,
                                     "activation keeps a stable menu bar canvas")
                        // Compare against a swatch rendered through the same bitmap color
                        // conversion, rather than comparing device RGB to TIFF's sRGB numbers.
                        let swatch = NSImage(size: C.BlackHoleGlyph.pointSize, flipped: false) { rect in
                            KeepAwakeAppearance.color.setFill()
                            rect.fill()
                            return true
                        }
                        guard let data = active?.tiffRepresentation,
                              let bitmap = NSBitmapImageRep(data: data),
                              let swatchData = swatch.tiffRepresentation,
                              let reference = NSBitmapImageRep(data: swatchData),
                              let expected = reference.colorAt(x: 5, y: 5)?.usingColorSpace(.deviceRGB) else {
                            suite.expect(false, "active image is renderable"); continue
                        }
                        var pixel: NSColor?
                        for y in 0..<bitmap.pixelsHigh {
                            for x in 0..<bitmap.pixelsWide {
                                if let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.95 {
                                    pixel = color.usingColorSpace(.deviceRGB); break
                                }
                            }
                            if pixel != nil { break }
                        }
                        suite.expect(pixel.map {
                            abs($0.redComponent - expected.redComponent) < 0.03
                                && abs($0.greenComponent - expected.greenComponent) < 0.03
                                && abs($0.blueComponent - expected.blueComponent) < 0.03
                        } ?? false, "the native indicator renders the shared amber in both appearances")
                    }
                }
            }
        }
        let legacy: [String: Any] = [
            SettingsBackupSupport.formatVersionKey: 1,
            SettingsBackupSupport.settingsKey: ["keepAwakeIconTint": "none", "keepAwakeActiveIcon": "coffee",
                                                DefaultsKey.menuBarIconSymbol: "bolt.fill",
                                                DefaultsKey.keepAwakePauseWhenLocked: true]
        ]
        let restored = SettingsBackupSupport.sanitizedSettings(from: legacy)
        suite.expect(restored?["keepAwakeIconTint"] == nil && restored?["keepAwakeActiveIcon"] == nil
                     && restored?[DefaultsKey.menuBarIconSymbol] as? String == "bolt.fill"
                     && restored?[DefaultsKey.keepAwakePauseWhenLocked] as? Bool == true,
                     "old backups discard removed appearance choices while keeping unrelated preferences")
        suite.expect(!SettingsBackupSupport.exportKeys().contains("keepAwakeIconTint")
                     && !SettingsBackupSupport.exportKeys().contains("keepAwakeActiveIcon"),
                     "removed appearance preferences no longer export")
    }
}
