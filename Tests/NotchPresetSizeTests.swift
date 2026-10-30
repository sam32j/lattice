import Foundation

enum NotchPresetSizeTests {
    static func run(_ suite: TestSuite) {
        for layout in NotchSize.allCases {
            for cameraHeight: CGFloat in [24, 32, 40, 64] {
                let geometry = NotchGeometry(screen: CGRect(x: 0, y: 0, width: 1470, height: 956),
                                             safeAreaTop: cameraHeight, cameraWidth: 210, layout: layout)
                let area = geometry.activationArea(in: geometry.expanded, hasHeader: true,
                                                   compactActivity: false, expandedHeader: true)
                suite.expect(geometry.pageTopInset >= cameraHeight && geometry.headerCameraGap == 210,
                             "both presets keep page content below the physical camera at every camera height")
                suite.expect(area.width == 210 && area.height == cameraHeight
                             && area.midX == geometry.expanded.width / 2,
                             "the collapse target covers only the camera in both presets")
                let content = geometry.contentSize(for: geometry.expandedSize(module: .system, systemCards: 1))
                let inset = NotchLayout.systemHoverInset(width: content.width)
                suite.expect((content.width - inset * 2) * 1.028 <= content.width
                             && NotchLayout.systemCardHeight * 1.028 <= NotchLayout.systemCardHeight + inset * 2,
                             "hovering a full-width system card stays within the preset viewport")
            }
        }
        suite.expect(NotchSize.allCases.map(\.rawValue) == ["compact", "spacious"],
                     "Dynamic Island offers only the two opinionated size presets")
        for stored in ["custom", "compact", "spacious"] {
            let domain = "io.github.sam32j.lattice.tests.preset-size.\(UUID())"
            let defaults = UserDefaults(suiteName: domain)!
            defer { defaults.removePersistentDomain(forName: domain) }
            defaults.set(stored, forKey: DefaultsKey.notchSize)
            defaults.set(590, forKey: "notchCustomWidth")
            defaults.set(620, forKey: "notchCustomHeight")
            defaults.set(true, forKey: DefaultsKey.notchDefaultProfileInitialized)
            Defaults.migrateExistingNotchDefaults(in: defaults, domainName: domain)
            let expected = stored == "custom" ? "spacious" : stored
            suite.expect(defaults.string(forKey: DefaultsKey.notchSize) == expected,
                         "legacy custom sizing migrates to Spacious while supported presets stay selected: \(stored)")
            suite.expect(defaults.object(forKey: "notchCustomWidth") == nil
                         && defaults.object(forKey: "notchCustomHeight") == nil,
                         "obsolete custom dimensions are removed: \(stored)")
            Defaults.migrateExistingNotchDefaults(in: defaults, domainName: domain)
            suite.expect(defaults.string(forKey: DefaultsKey.notchSize) == expected,
                         "preset migration is idempotent: \(stored)")
        }
        suite.expect(!SettingsBackupSupport.exportKeys().contains("notchCustomWidth")
                     && !SettingsBackupSupport.exportKeys().contains("notchCustomHeight"),
                     "backups do not export removed sizing controls")
    }
}
