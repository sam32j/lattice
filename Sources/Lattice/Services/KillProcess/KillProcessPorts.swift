// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 Samuel Ji

import Foundation

/// One listening socket: what Process Manager's Ports section lists.
struct KillProcessPort: Identifiable, Equatable {
    let port: Int
    let protocolName: String
    let address: String
    let pid: Int32
    let processName: String
    let startedAt: UInt64?
    /// What the port is for, when Lattice can tell. See `KillProcessPortServices`.
    var service: KillProcessPortService? = nil
    var id: String { "\(protocolName)-\(port)-\(pid)-\(address)" }
}

/// Pure helpers for reading listening ports from `lsof`.
enum KillProcessPortSupport {
    /// Whether an lsof endpoint such as `*:3000` or `127.0.0.1:3000` is bound
    /// to every interface rather than one specific address. A wildcard bind
    /// accepts connections from other machines on the network unless a
    /// firewall stops them, so it is worth pointing out.
    static func listensOnAllInterfaces(_ endpoint: String) -> Bool {
        guard let separator = endpoint.lastIndex(of: ":") else { return false }
        var host = endpoint[..<separator]
        if host.hasPrefix("["), host.hasSuffix("]") {
            host = host.dropFirst().dropLast()
        }
        return host == "*" || host == "0.0.0.0" || host == "::"
    }

    /// The last known listeners still held by the process `ps` just listed,
    /// for a scan whose `lsof` timed out.
    static func carriedOver(_ ports: [KillProcessPort], probes: [KillProcessProbe]) -> [KillProcessPort] {
        let identities = Dictionary(probes.map { ($0.pid, $0.startedAt) }, uniquingKeysWith: { first, _ in first })
        return ports.filter { port in
            guard let current = identities[port.pid] else { return false }
            return port.startedAt == nil || port.startedAt == current
        }
    }

    static func parseLsof(_ text: String) -> [KillProcessPort] {
        var name = "", pid: Int32 = 0, address = "", port = 0, proto = "TCP"
        var rows: [KillProcessPort] = []
        var seen = Set<String>()
        for line in text.split(separator: "\n").map(String.init) {
            guard let type = line.first else { continue }
            let value = String(line.dropFirst())
            switch type {
            case "p":
                pid = Int32(value) ?? 0; port = 0; address = ""
            case "c": name = value
            case "P": proto = value
            case "n":
                address = value
                guard let last = value.split(separator: ":").last, let parsed = Int(last) else {
                    port = 0
                    continue
                }
                port = parsed
                if pid > 0 && port > 0 {
                    let key = "\(proto)|\(port)|\(address)|\(pid)"
                    if seen.insert(key).inserted {
                        rows.append(.init(port: port, protocolName: proto, address: address,
                                          pid: pid, processName: name, startedAt: nil))
                    }
                }
            case "T": continue
            default: continue
            }
        }
        return rows.sorted { $0.port == $1.port ? $0.processName < $1.processName : $0.port < $1.port }
    }
}
