import Foundation
import CoreGraphics

/// Executes the actual delayed insertion method with inert events and time.
enum SnippetDelayedInsertionTests {
    enum ReviewDefaults { static var current: UserDefaults! }
    enum DispatchQueue {
        static let main = Queue()
        final class Queue {
            var callbacks: [() -> Void] = []
            func asyncAfter(deadline: DispatchTime, execute: @escaping () -> Void) { callbacks.append(execute) }
            func next() { callbacks.removeFirst()() }
        }
    }
    enum CGEventSource {
        static var flags: CGEventFlags = []
        static func flagsState(_ state: CGEventSourceStateID) -> CGEventFlags { flags }
    }
    enum NSSound { static func beep() {} }
    static func IsSecureEventInputEnabled() -> Bool { false }
    enum TextSnippetService {
        static var posted: [String] = []
        static func postExpansion(deleteCount: Int, typedTrigger: String, text: String,
                                  trailingKeyCode: CGKeyCode?, trailingFlags: CGEventFlags) { posted.append(text) }
    }
    static func run(_ suite: TestSuite) {
        let domain = "io.github.sam32j.lattice.tests.delayed-snippets.\(UUID())"
        let defaults = UserDefaults(suiteName: domain)!
        ReviewDefaults.current = defaults
        defer {
            defaults.removePersistentDomain(forName: domain)
            ReviewDefaults.current = nil
            DispatchQueue.main.callbacks = []
            TextSnippetService.posted = []
            CGEventSource.flags = []
        }
        let service = Service()
        defaults.set(true, forKey: DefaultsKey.textSnippetsEnabled)
        service.postWhenModifiersReleased(text: "stale", attempt: 0)
        defaults.set(false, forKey: DefaultsKey.textSnippetsEnabled)
        DispatchQueue.main.next()
        suite.expect(TextSnippetService.posted.isEmpty, "disabling snippets cancels insertion during the final settle delay")
        defaults.set(true, forKey: DefaultsKey.textSnippetsEnabled)
        CGEventSource.flags = .maskCommand
        service.postWhenModifiersReleased(text: "held", attempt: 0)
        defaults.set(false, forKey: DefaultsKey.textSnippetsEnabled)
        CGEventSource.flags = []
        DispatchQueue.main.next()
        suite.expect(DispatchQueue.main.callbacks.isEmpty && TextSnippetService.posted.isEmpty,
                     "disabling snippets stops queued modifier-release retries")
        defaults.set(true, forKey: DefaultsKey.textSnippetsEnabled)
        service.postWhenModifiersReleased(text: "current", attempt: 0)
        DispatchQueue.main.next()
        suite.expect(TextSnippetService.posted == ["current"], "a still-enabled insertion posts exactly once")
    }
}
