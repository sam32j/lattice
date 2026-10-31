import SwiftUI

/// Finish an in-progress filesystem mutation before allowing the owning
/// utility to disappear. Scans remain cancelable through ordinary disable.
struct FeatureActivationBusyGuard<Content: View>: View {
    let feature: AppFeature
    @ViewBuilder var content: () -> Content

    @ViewBuilder var body: some View {
        switch feature {
        case .cleaner:
            ObservedActivationControl(service: JunkCleaner.shared,
                isBusy: { $0.phase == .cleaning }, content: content)
        case .uninstaller:
            ObservedActivationControl(service: AppUninstaller.shared,
                isBusy: { $0.isRemoving }, content: content)
        case .killProcess, .portManager:
            ObservedActivationControl(service: KillProcessService.shared,
                isBusy: { $0.hasProtectedAction(for: feature) }, content: content)
        case .homebrew, .appUpdates:
            ObservedActivationControl(service: HomebrewManager.shared,
                isBusy: { ($0.operation != nil && $0.operationOwner == feature)
                    || (feature == .homebrew && $0.isTrustingTap) }, content: content)
        default: content()
        }
    }
}

private struct ObservedActivationControl<Service: ObservableObject, Content: View>: View {
    @ObservedObject var service: Service
    let isBusy: (Service) -> Bool
    @ViewBuilder var content: () -> Content

    var body: some View { content().disabled(isBusy(service)) }
}
