// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// AppKit describes a non-activating panel as a system dialog, which tiling
/// window managers track and list on whichever space is current. The shared
/// panel class is compiled here and created deferred, so no window is shown;
/// each floating surface's own file is read for the class it builds.
enum OverlayPanelTests {
    static func run(_ suite: TestSuite) {
        // The Clipboard History window keeps a title bar strip to drag it by.
        for style: NSWindow.StyleMask in [[.borderless, .nonactivatingPanel],
                                          [.titled, .closable, .fullSizeContentView, .nonactivatingPanel]] {
            let overlay = OverlayPanel(contentRect: CGRect(x: 0, y: 0, width: 200, height: 40),
                                       styleMask: style, backing: .buffered, defer: true)
            suite.expect(overlay.accessibilitySubrole() == .unknown,
                         "a floating overlay describes itself as an undescribed window, so window managers skip it")
            suite.expect(overlay.accessibilityRole() == .window && overlay.isAccessibilityElement(),
                         "a floating overlay stays an accessible window for assistive technology")
        }

        let capture = ScreenshotCapturePanel(screenRect: CGRect(x: -10000, y: -10000, width: 200, height: 40))
        capture.isReleasedWhenClosed = false
        defer { capture.close() }
        suite.expect(capture.accessibilitySubrole() == .unknown
                     && capture.accessibilityRole() == .window && capture.isAccessibilityElement(),
                     "capture's specialized panel inherits the overlay window-manager and accessibility behavior")

        // HUDs, previews, pickers and the menu's positioning helper: none is a
        // document window, and each floats over other apps' windows.
        let surfaces = [
            "Sources/Lattice/App/AppDelegate.swift",
            "Sources/Lattice/UI/PermissionGuideOverlay.swift",
            "Sources/Lattice/UI/QuitProtection/QuitProtectionHUD.swift",
            "Sources/Lattice/Services/QuickTools/QuickToolHUD.swift",
            "Sources/Lattice/Services/LatticeHub/LatticeHubPanel.swift",
            "Sources/Lattice/Services/QuickTools/CameraPreviewService.swift",
            "Sources/Lattice/Services/QuickTools/RecentCaptureService.swift",
            "Sources/Lattice/Services/QuickTools/ScreenshotSelectionController.swift",
            "Sources/Lattice/Services/QuickTools/ScreenshotCapturePanel.swift",
            "Sources/Lattice/Services/QuickTools/ScreenshotQuickPreviewController.swift",
            "Sources/Lattice/Services/QuickTools/ScreenshotPinWindow.swift",
            "Sources/Lattice/Services/QuickTools/QRResultController.swift",
            "Sources/Lattice/Services/QuickTools/ScratchpadService.swift",
            "Sources/Lattice/Services/Snippets/SnippetLibraryService.swift",
            "Sources/Lattice/Services/Clipboard/ClipboardHistoryService.swift",
            "Sources/Lattice/Services/CommandBar/CommandBarService.swift",
            "Sources/Lattice/Services/Switcher/AppSwitcher.swift",
            "Sources/Lattice/Services/RadialMenu/RadialMenuService.swift",
            "Sources/Lattice/Services/RadialMenu/RadialNowPlayingService.swift",
            "Sources/Lattice/Services/DockPreview/DockPreviewService.swift",
            "Sources/Lattice/Services/WindowLayout/WindowLayoutService.swift",
            "Sources/Lattice/Services/DiskImageInstaller/DiskImageInstallerService.swift",
            "Sources/Lattice/Services/CleaningMode/CleaningModeManager.swift",
            "Sources/Lattice/Services/Recorder/RecorderIndicator.swift",
        ]
        for path in surfaces {
            let source = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
            suite.expect(source.range(of: #"\bOverlayPanel\(contentRect|:\s*(?:OverlayPanel|ScreenshotCapturePanel)\b"#,
                                      options: .regularExpression) != nil
                         && !source.contains("NSPanel(contentRect")
                         && source.range(of: #"class \w+:\s*NSPanel\b"#, options: .regularExpression) == nil,
                         "\(path) builds its floating panels as overlays, which window managers do not list")
        }
    }
}
