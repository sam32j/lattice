import SwiftUI

/// Both the card and its inclusion button share one cancellable enable intent.
struct NotchAccessorySettingsItem: View {
    let title: String
    @Binding var enabled: Bool
    let available: Bool
    let reason: String?
    let reservesReason: Bool
    let unavailableAction: () -> Void
    @ObservedObject private var bluetooth = BluetoothPermissionAccess.shared
    @Environment(\.settingsPermissionAccess) private var access
    @State private var coordinator: PermissionActivationCoordinator?

    private var included: Binding<Bool> {
        Binding(get: { enabled && access.verify(.bluetooth) }, set: change)
    }

    var body: some View {
        NotchEditorItem(symbol: "headphones", title: title, included: included, available: available,
            unavailableReason: available ? nil : reason, unavailableAction: unavailableAction,
            reservesReason: reservesReason) { change(!included.wrappedValue) }
            .permissionActivationLifetime($coordinator)
    }

    private func change(_ desired: Bool) {
        coordinator?.cancel()
        let binding = $enabled
        let next = PermissionActivationCoordinator(requirements: [.bluetooth], verify: access.verify,
            requestAccess: access.request, applyEnabled: { binding.wrappedValue = $0 })
        coordinator = next
        next.setEnabled(desired)
    }
}
