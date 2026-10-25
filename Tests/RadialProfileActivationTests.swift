import Foundation

enum RadialProfileActivationTests {
    static func run(_ suite: TestSuite) {
        for (profile, needsAccess) in [
            (RadialMenuProfile(name: "Apps", items: [RadialMenuItem(kind: .app)]), false),
            (RadialMenuProfile(name: "Mouse", mouseButton: "button:4"), true),
            (RadialMenuProfile(name: "Trackpad", trackpadTap: true), true),
            (RadialMenuProfile(name: "Shortcut", items: [RadialMenuItem(kind: .shortcut)]), true),
        ] {
            let requirements: [SettingsPermission] = RadialMenuSupport.needsAccessibility([profile])
                ? [.accessibility] : []
            suite.expect(requirements.isEmpty != needsAccess,
                         "radial permissions follow the current actions and input triggers")
            var enabled = false
            var requests = 0
            let gate = PermissionActivationCoordinator(requirements: requirements, verify: { _ in false },
                requestAccess: { _, _ in requests += 1 }, applyEnabled: { enabled = $0 })
            gate.setEnabled(true)
            suite.expect(enabled == !needsAccess && requests == (needsAccess ? 1 : 0),
                         "non-privileged radial profiles enable without requesting Accessibility")
        }
        for change in ["switch", "delete", "reorder", "disable", "cancel"] {
            let first = RadialMenuProfile(name: "First")
            let second = RadialMenuProfile(name: "Second", trackpadTap: true)
            var profiles = [first, second]
            var selectedID = first.id
            var enabled = true
            var granted = false
            var complete: ((SettingsPermissionResult) -> Void)?
            let gate = PermissionActivationCoordinator(requirements: [.accessibility], verify: { _ in granted },
                requestAccess: { _, answer in complete = answer }, applyEnabled: { allowed in
                    guard allowed, let index = RadialProfileActivation.index(requestedID: first.id,
                        selectedID: selectedID, enabled: enabled, profiles: profiles) else { return }
                    profiles[index].mouseButton = "button:4"
                    for other in profiles.indices { profiles[other].trackpadTap = other == index }
                })
            gate.setEnabled(true)
            suite.expect(profiles == [first, second], "pending radial access does not change trigger ownership")
            switch change {
            case "switch": selectedID = second.id
            case "delete": profiles.removeFirst()
            case "reorder": profiles.reverse()
            case "disable": enabled = false
            default: gate.cancel()
            }
            let before = profiles
            granted = true
            complete?(.granted)
            if change == "reorder" {
                suite.expect(profiles[1].id == first.id && profiles[1].mouseButton == "button:4"
                             && profiles[1].trackpadTap && !profiles[0].trackpadTap,
                             "a verified radial activation resolves the intended profile's current index")
            } else {
                suite.expect(profiles == before, "late radial grant after \(change) cannot change profiles or ownership")
            }
        }
    }
}
