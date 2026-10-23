import Foundation

enum FileUtilitySessionTests {
    static func run(_ suite: TestSuite) {
        let session = FileUtilitySession()
        session.beginDrag(sharedStandalone: true, optimizerAvailable: true, option: false)
        suite.expect(session.effectiveMode == .cache, "shake initially presents File Cache")
        session.updateDrag(option: true)
        suite.expect(session.effectiveMode == .optimizer, "Option previews MO in the shared drag surface")
        session.updateDrag(option: false)
        suite.expect(session.effectiveMode == .cache, "releasing Option before drop restores File Cache")
        session.updateDrag(option: true)
        suite.expect(session.resolveDrop(option: false) == .cache,
                     "release immediately before drop resolves to cache without waiting for a polling tick")
        session.updateDrag(option: true)
        session.commitDrop()
        session.updateDrag(option: false)
        session.endDrag()
        suite.expect(session.effectiveMode == .optimizer, "an optimizer drop latches MO after Option is released")
        session.select(.cache)
        session.beginDrag(sharedStandalone: false, optimizerAvailable: true, option: true)
        suite.expect(session.effectiveMode == .cache, "Option does not reroute a non-shared presentation")
        session.endDrag()
        session.beginDrag(sharedStandalone: true, optimizerAvailable: false, option: true)
        suite.expect(session.effectiveMode == .cache, "unavailable optimizer cannot capture File Cache drops")
        session.endDrag()
        session.updateDrag(option: true)
        suite.expect(session.effectiveMode == .cache, "Option without a drag never changes the utility")
    }
}
