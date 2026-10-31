import AppKit
import SwiftUI

extension SettingsView {
    struct SearchKeyMonitor: NSViewRepresentable {
        var customSearchFocused: Bool
        var focusSearch: () -> Void
        var handleKey: (UInt16) -> Bool

        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            context.coordinator.install(for: view)
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            context.coordinator.focusSearch = focusSearch
            context.coordinator.customSearchFocused = customSearchFocused
            context.coordinator.handleKey = handleKey
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(customSearchFocused: customSearchFocused, focusSearch: focusSearch, handleKey: handleKey)
        }

        static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
            coordinator.removeMonitor()
        }

        final class Coordinator: NSObject {
            var customSearchFocused: Bool
            var focusSearch: () -> Void
            var handleKey: (UInt16) -> Bool
            private var monitor: Any?

            init(customSearchFocused: Bool, focusSearch: @escaping () -> Void, handleKey: @escaping (UInt16) -> Bool) {
                self.focusSearch = focusSearch
                self.customSearchFocused = customSearchFocused
                self.handleKey = handleKey
            }

            func install(for view: NSView) {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
                    [weak self, weak view] event in
                    guard let self, let view, let window = view.window,
                          event.window === window else { return event }
                    if event.charactersIgnoringModifiers?.lowercased() == "f",
                       event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command {
                        focusSearch()
                        return nil
                    }
                    guard customSearchFocused, Self.isNavigationKey(event),
                          let editor = window.firstResponder as? NSTextView,
                          editor.isFieldEditor,
                          !editor.hasMarkedText() else { return event }
                    return handleKey(event.keyCode) ? nil : event
                }
            }

            func removeMonitor() {
                guard let monitor else { return }
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }

            private static func isNavigationKey(_ event: NSEvent) -> Bool {
                let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
                guard event.modifierFlags.intersection(blockedModifiers).isEmpty else { return false }
                return [UInt16(126), 125, 36, 76].contains(event.keyCode)
            }


        }
    }

}
