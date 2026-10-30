import Foundation

enum NotchMissionControlRestorationTests {
    static func run(_ suite: TestSuite) {
        typealias C = NotchPresentationRefreshContract
        let original = CGSize(width: 430, height: 210)
        let replacement = CGSize(width: 510, height: 350)
        func concealed() -> C.Host {
            let host = C.Host()
            host.concealedForMissionControl = true
            host.missionControlRestorationSize = original
            host.missionControlRestorationUsesGlass = true
            host.targetSize = .zero
            host.panel.isVisible = false
            return host
        }
        let untouched = concealed()
        untouched.restoreFromMissionControl()
        suite.expect(untouched.targetSize == original && untouched.usesGlass && untouched.panel.isVisible,
                     "Mission Control restores the original requested surface when nothing changed")
        let changed = concealed()
        changed.present(size: replacement, geometry: changed.currentGeometry, animated: false, usesGlass: false)
        changed.restoreFromMissionControl()
        suite.expect(changed.targetSize == replacement && !changed.usesGlass,
                     "a service request during Mission Control replaces stale restoration size and glass")
        let hidden = concealed()
        hidden.hide(animated: true)
        hidden.restoreFromMissionControl()
        suite.expect(!hidden.panel.isVisible && hidden.targetSize == .zero,
                     "a hide request after concealment settles prevents resurrection")
        let hiding = concealed()
        hiding.panel.isVisible = true
        hiding.targetSize = CGSize(width: 210, height: 38)
        hiding.hidesWhenSettled = true
        hiding.hide(animated: true)
        hiding.restoreFromMissionControl()
        suite.expect(!hiding.panel.isVisible && hiding.targetSize == .zero,
                     "a hide request during the entry shrink also prevents resurrection")
        let quickExit = concealed()
        quickExit.panel.isVisible = true
        quickExit.targetSize = CGSize(width: 210, height: 38)
        quickExit.hidesWhenSettled = true
        quickExit.restoreFromMissionControl()
        suite.expect(quickExit.targetSize == original && quickExit.usesGlass,
                     "a quick exit restores the desired surface rather than the intermediate camera cutout")
        let hideViaPresentation = concealed()
        hideViaPresentation.present(size: .zero, geometry: hideViaPresentation.currentGeometry,
                                    animated: false, hideWhenSettled: true)
        hideViaPresentation.restoreFromMissionControl()
        suite.expect(!hideViaPresentation.panel.isVisible, "a hide-when-settled presentation also cancels restoration")
    }
}
