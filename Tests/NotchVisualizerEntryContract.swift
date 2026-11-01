enum NotchVisualizerEntryContract {
    enum NotchVisualizerRuntime {
        static var reconciliations = 0
        static func reconcileParents() { reconciliations += 1 }
    }
    static func run(_ suite: TestSuite) {
        NotchVisualizerRuntime.reconciliations = 0
        Service().synchronizeEntry()
        suite.expect(NotchVisualizerRuntime.reconciliations == 1,
                     "parent activation is reconciled before preference-work cancellation and every Island early-return guard")
    }
}
