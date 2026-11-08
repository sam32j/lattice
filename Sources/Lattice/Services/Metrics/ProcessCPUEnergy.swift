// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Darwin
import Foundation

struct ProcessCPUEnergy {
    let startedAt: UInt64
    let nanojoules: UInt64

    func watts(since previous: Self, elapsed: TimeInterval) -> Double? {
        guard startedAt == previous.startedAt, nanojoules >= previous.nanojoules,
              elapsed.isFinite, (0.5...30).contains(elapsed) else { return nil }
        return Double(nanojoules - previous.nanojoules) / 1e9 / elapsed
    }

    /// Recount accounts CPU energy for supported hardware. Scope collection to
    /// the current user and skip processes that exit or deny the read.
    static func readCurrentUser() -> [pid_t: Self] {
        let type = UInt32(PROC_UID_ONLY)
        let uid = getuid()
        let stride = MemoryLayout<pid_t>.stride
        let estimatedBytes = proc_listpids(type, uid, nil, 0)
        guard estimatedBytes > 0 else { return [:] }
        var pids = [pid_t](repeating: 0, count: Int(estimatedBytes) / stride + 64)
        let bytes = pids.withUnsafeMutableBytes { proc_listpids(type, uid, $0.baseAddress, Int32($0.count)) }
        guard bytes > 0 else { return [:] }

        var samples: [pid_t: Self] = [:]
        for pid in pids.prefix(Int(bytes) / stride) where pid > 0 {
            var usage = rusage_info_v6()
            let status = withUnsafeMutablePointer(to: &usage) { pointer in
                pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V6, $0)
                }
            }
            if status == 0, usage.ri_proc_start_abstime > 0 {
                samples[pid] = Self(startedAt: usage.ri_proc_start_abstime, nanojoules: usage.ri_energy_nj)
            }
        }
        return samples
    }
}
