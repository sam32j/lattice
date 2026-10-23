import Foundation

enum RadialProfileActivationTests {
    static func run(_ suite: TestSuite) {
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
