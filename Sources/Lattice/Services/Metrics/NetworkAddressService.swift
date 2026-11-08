// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Combine
import Darwin
import Foundation
import SystemConfiguration

/// View-owned. Every reading comes from the local interface list, so no
/// request leaves the machine and there is no provider to name.
final class NetworkAddressService: ObservableObject {
    static let shared = NetworkAddressService()
    @Published private(set) var localAddresses: [String] = []
    @Published private(set) var publicIP: String?
    @Published private(set) var isLoadingPublicIP = false
    private var lastPublicIPFetch: TimeInterval = 0

    func refreshLocalAddresses() {
        let addresses = Self.readLocalAddresses()
        guard addresses != localAddresses else { return }
        localAddresses = addresses
    }

    func refreshPublicIP(force: Bool = false) {
        let now = ProcessInfo.processInfo.systemUptime
        guard force || (publicIP == nil && !isLoadingPublicIP) || (now - lastPublicIPFetch > 300) else { return }
        isLoadingPublicIP = true
        lastPublicIPFetch = now

        let url = URL(string: "https://api.ipify.org")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoadingPublicIP = false
                guard let data,
                      let ip = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !ip.isEmpty, (response as? HTTPURLResponse)?.statusCode == 200,
                      ip.range(of: #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#, options: .regularExpression) != nil else { return }
                self?.publicIP = ip
            }
        }.resume()
    }

    func cancel() {
        localAddresses = []
    }

    static func includesLocalAddress(name: String, flags: UInt32, family: Int32) -> Bool {
        family == AF_INET && flags & UInt32(IFF_UP | IFF_RUNNING) == UInt32(IFF_UP | IFF_RUNNING)
            && MetricFormat.includeNetworkInterface(name)
    }

    static func readLocalAddresses() -> [String] {
        let names = connectionNames()
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0 else { return [] }
        defer { freeifaddrs(first) }
        var addresses = Set<String>()
        var current = first
        while let entry = current?.pointee {
            defer { current = entry.ifa_next }
            guard let address = entry.ifa_addr else { continue }
            let name = String(cString: entry.ifa_name)
            guard includesLocalAddress(name: name, flags: entry.ifa_flags,
                                       family: Int32(address.pointee.sa_family)) else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let ip = String(cString: host)
            // The system knows en0 as "Wi-Fi"; the BSD name means nothing on screen.
            addresses.insert(names[name].map { "\(ip) (\($0))" } ?? ip)
        }
        return addresses.sorted()
    }

    /// The system's own name per interface ("Wi-Fi", "Ethernet"), keyed by BSD
    /// name. An interface the system has no name for keeps no tag.
    private static func connectionNames() -> [String: String] {
        var names: [String: String] = [:]
        for interface in SCNetworkInterfaceCopyAll() as? [SCNetworkInterface] ?? [] {
            guard let bsd = SCNetworkInterfaceGetBSDName(interface) as String?,
                  let display = SCNetworkInterfaceGetLocalizedDisplayName(interface) as String?
            else { continue }
            names[bsd] = display
        }
        return names
    }
}
