import AppKit
import Carbon.HIToolbox

enum BindingRecorderEventTests {
    class State {
        struct Localization { let s = Strings.enUS }
        let l10n = Localization()
        var modifierRecording = ModifierShortcutRecording()
        var pressedModifiers: GlobalShortcutModifiers = []
        var captured: [GlobalShortcutModifiers] = []
        var captureModifiers: ((GlobalShortcutModifiers) -> Void)?
        var canClear = false
        var errorText: String?
        func stopRecording() {}
        func clear() {}
        func onCapture(_ shortcut: GlobalShortcut) { errorText = "conflict" }
    }
    static func run(_ suite: TestSuite) {
        let recorder = Recorder()
        recorder.captureModifiers = { recorder.captured.append($0) }
        _ = recorder.modifierRecording.flagsChanged([.command, .option])
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [.command, .option], timestamp: 0, windowNumber: 0,
            context: nil, characters: "k", charactersIgnoringModifiers: "k",
            isARepeat: false, keyCode: UInt16(kVK_ANSI_K))!
        recorder.handleKeyEvent(event)
        let release = NSEvent.keyEvent(with: .flagsChanged, location: .zero,
            modifierFlags: [], timestamp: 1, windowNumber: 0, context: nil,
            characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 55)!
        recorder.handleFlagsChanged(release)
        suite.expect(recorder.captured.isEmpty,
                     "releasing modifiers after a rejected key never overwrites the binding with a chord")
    }
}
