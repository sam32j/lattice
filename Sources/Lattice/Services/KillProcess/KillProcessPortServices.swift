// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// What a listening port is for, when Lattice can tell without asking the
/// network. Known macOS services come from a fixed table; a dev server run
/// by a generic runtime (node, python3, bun…) is named after the tool or
/// script it runs. Anything else has no label and its line shows the
/// process holding the port instead.
enum KillProcessPortService: Equatable, Hashable {
    case airPlayAudio, airPlayReceiver, continuity, airDropAndHandoff
    case remoteLogin, fileSharing, screenSharing, musicSharing, printerSharing, remoteManagement
    /// A tool or script a runtime is running, such as `vite` or `server`.
    case tool(String)
}

enum KillProcessPortServices {
    /// Runtimes whose own name says nothing; the program they run does.
    static let runtimes: Set<String> = [
        "node", "bun", "deno", "python", "python3", "ruby", "java", "php", "perl", "dotnet",
    ]

    static func isRuntime(_ processName: String) -> Bool {
        let name = processName.lowercased()
        return runtimes.contains(name) || name.hasPrefix("python3.")
    }

    /// The service on one port. `arguments` is the process's command line,
    /// read only for runtimes; nil when it could not be read.
    static func service(processName: String, port: Int, arguments: [String]?) -> KillProcessPortService? {
        let name = processName.lowercased()
        switch (name, port) {
        case ("controlcenter", 5000): return .airPlayAudio
        case ("controlcenter", 7000): return .airPlayReceiver
        case ("rapportd", _): return .continuity
        case ("sharingd", _): return .airDropAndHandoff
        default: break
        }
        // Well-known ports macOS's own sharing services use.
        switch port {
        case 22: return .remoteLogin
        case 445, 548: return .fileSharing
        case 5900: return .screenSharing
        case 3689: return .musicSharing
        case 631: return .printerSharing
        case 3283: return .remoteManagement
        default: break
        }
        if isRuntime(name), let arguments, let tool = toolName(arguments: arguments) {
            return .tool(tool)
        }
        return nil
    }

    /// The program a runtime runs: `node …/node_modules/.bin/vite` is vite,
    /// `python3 -m http.server` is http.server, `node server.js` is server.
    static func toolName(arguments: [String]) -> String? {
        var index = 1
        while index < arguments.count {
            let argument = arguments[index]
            if argument == "-m", index + 1 < arguments.count { return arguments[index + 1] }
            if argument.hasPrefix("-") {
                index += 1
                continue
            }
            let base = (argument as NSString).lastPathComponent
            let stem = (base as NSString).deletingPathExtension
            // A package's entry file says less than the package: …/vite/bin/vite.js.
            let generic: Set<String> = ["index", "main", "cli", "bin", "run", "start"]
            if generic.contains(stem.lowercased()) {
                let parts = (argument as NSString).pathComponents
                if let package = parts.lastIndex(of: "node_modules").map({ parts.index(after: $0) }),
                   package < parts.count {
                    return parts[package]
                }
            }
            return stem.isEmpty ? nil : stem
        }
        return nil
    }
}
