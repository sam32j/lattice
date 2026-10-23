import AppKit
import Combine
import CoreBluetooth

enum BluetoothAuthorizationPolicy {
    enum Status { case granted, missing, unknown }

    static func status(_ authorization: CBManagerAuthorization) -> Status {
        switch authorization {
        case .allowedAlways: return .granted
        case .notDetermined, .denied, .restricted: return .missing
        @unknown default: return .unknown
        }
    }

    static func canRequest(_ authorization: CBManagerAuthorization) -> Bool { authorization == .notDetermined }
}

/// Reading authorization does not create a radio client or request access.
/// The temporary manager is created only by an explicit Request action; it never scans.
final class BluetoothPermissionAccess: NSObject, ObservableObject, CBCentralManagerDelegate {
    static let shared = BluetoothPermissionAccess()
    @Published private(set) var authorization = CBManager.authorization
    private var requestManager: CBCentralManager?

    func refresh() {
        let value = CBManager.authorization
        if value != authorization { authorization = value }
    }

    func request() {
        refresh()
        guard BluetoothAuthorizationPolicy.canRequest(authorization), requestManager == nil else { return }
        requestManager = CBCentralManager(delegate: self, queue: .main,
            options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        refresh()
        if authorization != .notDetermined { requestManager = nil }
    }

    func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") else { return }
        NSWorkspace.shared.open(url)
    }
}
