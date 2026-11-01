import AppKit

enum PermissionDialogPresentationTests {
    static func run(_ suite: TestSuite) {
        let parent = NSWindow(contentRect: NSRect(x: 180, y: 240, width: 800, height: 600),
                              styleMask: [.titled], backing: .buffered, defer: false)
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        parent.contentView = content
        let existing = NSView(frame: content.bounds)
        content.addSubview(existing)
        let alert = NSAlert()
        alert.messageText = "Restart Lattice"
        alert.informativeText = "Restart Lattice to finish permission reset."
        alert.addButton(withTitle: "Restart")
        var modals = 0
        let result = PermissionDialogPresentation.run(alert, over: parent) {
            modals += 1
            suite.expect((parent.childWindows ?? []).isEmpty,
                         "no backdrop dimming child window is attached to the parent")
            suite.expect(abs(alert.window.frame.midX - parent.frame.midX) < 1
                         && abs(alert.window.frame.midY - parent.frame.midY) < 1,
                         "native permission dialogs are centered over their owning Settings window")
            alert.window.setFrameOrigin(NSPoint(x: 0, y: 0))
            NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: alert.window)
            suite.expect(abs(alert.window.frame.midX - parent.frame.midX) < 1
                         && abs(alert.window.frame.midY - parent.frame.midY) < 1,
                         "native modal activation cannot move the dialog away from the requested center")
            return .alertFirstButtonReturn
        }
        suite.expect(result == .alertFirstButtonReturn && modals == 1,
                     "centered presentation preserves the dialog result without adding extra modals")
        suite.expect((parent.childWindows ?? []).isEmpty
                     && content.subviews.count == 1 && content.subviews.first === existing,
                     "content subviews remain unchanged without changing existing content")
        alert.window.setFrameOrigin(NSPoint(x: 31, y: 47))
        NotificationCenter.default.post(name: NSWindow.didBecomeKeyNotification, object: alert.window)
        suite.expect(alert.window.frame.origin == NSPoint(x: 31, y: 47),
                     "dialog placement observers are removed after closing")
        let fallback = PermissionDialogPresentation.run(NSAlert(), over: nil) { .alertSecondButtonReturn }
        suite.expect(fallback == .alertSecondButtonReturn,
                     "presentation without an available owner still preserves Cancel")
        let visibleParent = NSWindow(contentRect: NSRect(x: 180, y: 240, width: 800, height: 600),
                                     styleMask: [.titled], backing: .buffered, defer: false)
        visibleParent.orderFront(nil)
        _ = PermissionDialogPresentation.run(alert, over: visibleParent) {
            suite.expect((visibleParent.childWindows ?? []).isEmpty,
                         "no backdrop dim is attached even when parent is visible")
            return .alertFirstButtonReturn
        }
        visibleParent.orderOut(nil)
        visibleParent.close()
        let uninstallAlert = NSAlert()
        uninstallAlert.alertStyle = .informational
        uninstallAlert.messageText = L10n.shared.s.advancedUninstallConfirmTitle
        uninstallAlert.informativeText = L10n.shared.s.advancedUninstallConfirmBody
        uninstallAlert.addButton(withTitle: L10n.shared.s.advancedUninstallButton)
        uninstallAlert.addButton(withTitle: L10n.shared.s.uninstallerCancel)
        suite.expect(uninstallAlert.alertStyle == .informational
                     && uninstallAlert.buttons.count == 2
                     && uninstallAlert.buttons[0].title == L10n.shared.s.advancedUninstallButton
                     && uninstallAlert.buttons[1].title == L10n.shared.s.uninstallerCancel,
                     "uninstall dialog is configured as a system dialog with app icon and cancel")
    }
}
