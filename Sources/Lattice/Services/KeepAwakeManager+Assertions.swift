import Foundation

extension KeepAwakeManager {
    func applyAssertions() -> Bool {
        let acquired = assertions.acquire(allowDisplaySleep: UserDefaults.standard.bool(
            forKey: DefaultsKey.keepAwakeAllowDisplaySleep))
        assertionFailed = !acquired
        return acquired
    }
    func releaseAssertions() -> Bool {
        assertions.release()
    }
}
