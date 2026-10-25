import Foundation
import CoreBluetooth

final class BluetoothBatteryRead: NSObject, PeripheralBluetoothReading, CBCentralManagerDelegate, CBPeripheralDelegate {
    private static let batteryService = CBUUID(string: "180F")
    private static let batteryLevel = CBUUID(string: "2A19")

    private let queue: DispatchQueue
    private let completion: ([BluetoothBatteryReading]) -> Void
    private let cancellation: BoundedProcessCancellation
    private var central: CBCentralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var pending = Set<UUID>()
    private var readings: [BluetoothBatteryReading] = []
    private var didRetrieve = false
    private var finished = false
    private var timeout: DispatchWorkItem?

    init(queue: DispatchQueue, cancellation: BoundedProcessCancellation,
         completion: @escaping ([BluetoothBatteryReading]) -> Void) {
        self.queue = queue
        self.cancellation = cancellation
        self.completion = completion
    }

    func start() {
        guard !finished, !cancellation.isCancelled else { return }
        guard CBManager.authorization == .allowedAlways else { finish(); return }
        central = CBCentralManager(delegate: self,
                                   queue: queue,
                                   options: [CBCentralManagerOptionShowPowerAlertKey: false])
        let timeout = DispatchWorkItem { [weak self] in self?.finish() }
        self.timeout = timeout
        queue.asyncAfter(deadline: .now() + 5, execute: timeout)
    }

    func cancel() { cancellation.cancel(); finish() }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard !finished, !cancellation.isCancelled else { return }
        switch central.state {
        case .poweredOn:
            guard !didRetrieve else { return }
            didRetrieve = true
            let connected = central.retrieveConnectedPeripherals(withServices: [Self.batteryService])
            guard !connected.isEmpty else {
                finish()
                return
            }
            for peripheral in connected {
                guard !cancellation.isCancelled else { finish(); return }
                peripherals[peripheral.identifier] = peripheral
                pending.insert(peripheral.identifier)
                peripheral.delegate = self
                central.connect(peripheral)
            }
        case .unknown, .resetting:
            break
        case .unsupported, .unauthorized, .poweredOff:
            finish()
        @unknown default:
            finish()
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard !finished, !cancellation.isCancelled, pending.contains(peripheral.identifier) else { return }
        peripheral.discoverServices([Self.batteryService])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        complete(peripheral)
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        complete(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard !finished, !cancellation.isCancelled else { return }
        guard error == nil,
              let service = peripheral.services?.first(where: { $0.uuid == Self.batteryService }) else {
            complete(peripheral)
            return
        }
        peripheral.discoverCharacteristics([Self.batteryLevel], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard !finished, !cancellation.isCancelled else { return }
        guard error == nil,
              let characteristic = service.characteristics?.first(where: { $0.uuid == Self.batteryLevel }) else {
            complete(peripheral)
            return
        }
        peripheral.readValue(for: characteristic)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard !finished, !cancellation.isCancelled else { return }
        defer { complete(peripheral) }
        guard error == nil,
              characteristic.uuid == Self.batteryLevel,
              let data = characteristic.value,
              data.count == 1,
              let name = peripheral.name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return
        }
        let percent = Int(data[data.startIndex])
        guard percent <= 100 else { return }
        readings.append(BluetoothBatteryReading(id: peripheral.identifier.uuidString,
                                                name: name,
                                                percent: percent))
    }

    private func complete(_ peripheral: CBPeripheral) {
        guard pending.remove(peripheral.identifier) != nil else { return }
        central?.cancelPeripheralConnection(peripheral)
        peripherals[peripheral.identifier] = nil
        if pending.isEmpty {
            finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        timeout?.cancel()
        timeout = nil
        for peripheral in peripherals.values {
            peripheral.delegate = nil
            central?.cancelPeripheralConnection(peripheral)
        }
        peripherals.removeAll()
        pending.removeAll()
        central?.delegate = nil
        central = nil
        if !cancellation.isCancelled { completion(readings) }
    }
}
