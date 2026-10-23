import Foundation

enum BluetoothPermissionLifecycleTests {
    private final class Reader: PeripheralBluetoothReading {
        func start() {}
        func cancel() {}
    }

    static func run(_ suite: TestSuite) {
        let queue = DispatchQueue(label: "com.vorssaint.tests.bluetooth-permission")
        var authorized = false
        var profilerReads = 0
        var clients = 0
        let hid = PeripheralBatteryDevice(id: "HID:fixture", name: "Mouse", percent: 70, kind: .mouse)
        let sampler = PeripheralBatterySampler(bluetoothQueue: queue, readFast: { [hid] },
            readProfiler: { _ in profilerReads += 1; return Data() },
            makeBluetoothRead: { _, _, _ in clients += 1; return Reader() },
            bluetoothAuthorized: { authorized })
        sampler.setEnabled(true)
        let first = sampler.sample(now: 1)
        queue.sync {}
        suite.expect(first.devices == [hid] && profilerReads == 0 && clients == 0,
                     "missing Bluetooth access preserves HID batteries without invoking a profiler or creating a radio client")
        authorized = true
        _ = sampler.sample(now: 400)
        queue.sync {}
        suite.expect(clients == 1, "already-granted Bluetooth access permits an explicitly enabled sampler")
        sampler.setEnabled(false)
        queue.sync {}
        authorized = true
        let changing = PeripheralBatterySampler(bluetoothQueue: queue, readFast: { [] },
            readProfiler: { _ in authorized = false; return Data() },
            makeBluetoothRead: { _, _, _ in clients += 1; return Reader() },
            bluetoothAuthorized: { authorized })
        changing.setEnabled(true)
        _ = changing.sample(now: 1)
        queue.sync {}
        suite.expect(clients == 1, "revocation while the profiler runs prevents the later radio-client startup")
        changing.setEnabled(false)
        queue.sync {}
        authorized = false
        sampler.setEnabled(true)
        _ = sampler.sample(now: 800)
        queue.sync {}
        suite.expect(clients == 1, "permission reset cannot silently create another Bluetooth client")
        sampler.setEnabled(false)
        queue.sync {}
    }
}
