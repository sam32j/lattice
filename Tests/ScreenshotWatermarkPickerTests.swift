// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import UniformTypeIdentifiers

/// Production chooser flow with only the OS file dialog and thumbnail boundary
/// replaced. No file chooser is shown and no user files are opened.
enum ScreenshotWatermarkPickerTests {
    enum Response { case OK, cancel }
    final class NSOpenPanel {
        var canChooseFiles = false, canChooseDirectories = true, allowsMultipleSelection = true
        var allowedContentTypes: [UTType] = []
        var url: URL? { ScreenshotWindowLayering.selectedURL }
    }
    enum ScreenshotWindowLayering {
        static var response = Response.cancel
        static var selectedURL: URL?
        static var duringSelection: () -> Void = {}
        static func runModalPanel(_ panel: NSOpenPanel, above window: NSWindow?) -> Response {
            duringSelection()
            return response
        }
    }
    enum BackdropPickerAssets {
        static var valid = true
        static func thumbnail(for url: URL) -> Bool? { valid ? true : nil }
    }
    enum NSSound {
        static var beeps = 0
        static func beep() { beeps += 1 }
    }
    struct Application { var keyWindow: NSWindow? }
    static let NSApp = Application()
    final class Model {
        var saved: [ScreenshotSupport.WatermarkStyle] = []
        func addWatermarkPreset(_ style: ScreenshotSupport.WatermarkStyle) { saved.append(style) }
    }
    class State {
        var draft = ScreenshotWatermarkDraft(.init(kind: .text, text: "Keep this"))
        let model = Model()
        var fileSelectionChanged: (Bool) -> Void = { _ in }
    }
    class PresenterState {
        var choosingImage = false
        var popover: NSPopover? = NSPopover()
    }

    static func run(_ suite: TestSuite) {
        let chooser = Chooser()
        let presenter = Presenter()
        var transitions: [Bool] = []
        chooser.fileSelectionChanged = {
            transitions.append($0)
            presenter.setChoosingImage($0)
        }
        ScreenshotWindowLayering.duringSelection = {
            suite.expect(presenter.popover?.behavior == .applicationDefined
                         && !presenter.popoverShouldClose(presenter.popover!),
                         "interacting with Finder's image chooser cannot dismiss the watermark tool")
        }
        defer {
            ScreenshotWindowLayering.duringSelection = {}
            ScreenshotWindowLayering.selectedURL = nil
            ScreenshotWindowLayering.response = .cancel
            BackdropPickerAssets.valid = true
            NSSound.beeps = 0
        }
        func expectRestored() {
            suite.expect(transitions == [true, false] && presenter.popover?.behavior == .transient
                         && presenter.popoverShouldClose(presenter.popover!),
                         "completing or cancelling image selection restores ordinary outside-click dismissal")
            transitions = []
        }
        let original = chooser.draft.style
        chooser.chooseImage()
        suite.expect(chooser.draft.style == original, "cancelling the chooser leaves the watermark draft intact")
        expectRestored()
        ScreenshotWindowLayering.response = .OK
        ScreenshotWindowLayering.selectedURL = URL(fileURLWithPath: "/tmp/watermark-picker-fixture.png")
        chooser.chooseImage()
        suite.expect(chooser.draft.style.kind == .image
                     && chooser.draft.style.imagePath == "/tmp/watermark-picker-fixture.png"
                     && chooser.model.saved.count == 1,
                     "choosing an image returns it to the same draft and collection without closing the tool")
        expectRestored()
        BackdropPickerAssets.valid = false
        let previous = chooser.draft.style
        chooser.chooseImage()
        suite.expect(chooser.draft.style == previous && NSSound.beeps == 1,
                     "an unreadable image leaves the tool available for retry and reports failure")
        expectRestored()
    }
}
