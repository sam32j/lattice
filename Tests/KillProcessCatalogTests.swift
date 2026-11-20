// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import Foundation

/// Classification, nesting, search, row content and Quit Others rules for the
/// redesigned Kill Process list.
enum KillProcessCatalogTests {
    static func run(_ suite: TestSuite) {
        let me: uid_t = 501
        let own: pid_t = 900

        func probe(_ pid: pid_t, _ name: String, path: String, uid: uid_t = 501, ppid: pid_t = 1,
                   cpu: Double = 0, memory: Double = 1_000, bundleID: String? = nil, bundle: String? = nil,
                   policy: Int? = nil, responsible: pid_t? = nil, protected: Bool = false) -> KillProcessProbe {
            KillProcessProbe(pid: pid, ppid: ppid, uid: uid, name: name, path: path, cpuPercent: cpu,
                             memoryBytes: memory, startedAt: 1, bundleIdentifier: bundleID, bundlePath: bundle,
                             activationPolicy: policy, responsiblePID: responsible ?? pid, isProtected: protected)
        }

        let probes = [
            probe(100, "Notion", path: "/Applications/Notion.app/Contents/MacOS/Notion", cpu: 10,
                  bundleID: "notion.id", bundle: "/Applications/Notion.app", policy: 0),
            probe(101, "Notion Helper", path: "/Applications/Notion.app/Contents/Frameworks/Notion Helper.app/Contents/MacOS/Notion Helper",
                  ppid: 100, cpu: 11.9, memory: 500, policy: 2, responsible: 100),
            probe(102, "Notion Helper (GPU)", path: "/Applications/Notion.app/Contents/Frameworks/GPU", ppid: 100, cpu: 2),
            probe(110, "Safari", path: "/Applications/Safari.app/Contents/MacOS/Safari", cpu: 30,
                  bundleID: "com.apple.Safari", bundle: "/Applications/Safari.app", policy: 0),
            probe(111, "WebContent", path: "/System/Library/Frameworks/WebKit.framework/XPCServices/WebContent",
                  cpu: 1, responsible: 110),
            probe(120, "Raycast", path: "/Applications/Raycast.app/Contents/MacOS/Raycast", cpu: 3,
                  bundleID: "com.raycast.macos", bundle: "/Applications/Raycast.app", policy: 1),
            probe(130, "BiomeAgent", path: "/System/Library/PrivateFrameworks/BiomeStreams.framework/Support/BiomeAgent", cpu: 0.5),
            probe(131, "node", path: "/usr/local/bin/node", cpu: 4),
            probe(140, "WindowServer", path: "/System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer",
                  uid: 88, cpu: 12, protected: true),
            probe(141, "logd", path: "/usr/libexec/logd", uid: 0, cpu: 0.2),
            probe(own, "Lattice", path: "/Applications/Lattice.app/Contents/MacOS/Lattice", cpu: 1,
                  bundleID: "io.github.sam32j.lattice", bundle: "/Applications/Lattice.app", policy: 1),
            probe(150, "Orphan Helper", path: "/Applications/Gone.app/Contents/MacOS/Helper", cpu: 0.1, responsible: 999),
            probe(160, "zombie", path: "<defunct>"),
            probe(161, "Passwords", path: "com.apple.Passwords.MenuBarExtra", bundleID: "com.apple.Passwords.MenuBarExtra",
                  bundle: "/System/Library/CoreServices/Passwords.app", policy: 1),
            probe(162, "cloudphotod", path: "cloudphotod"),
            probe(163, "SimulatorTrampoline", path: "/Library/Developer/PrivateFrameworks/CoreSimulator.framework/XPCServices/SimulatorTrampoline",
                  bundleID: "com.apple.CoreSimulator.SimulatorTrampoline"),
        ]
        let items = KillProcessCatalog.items(from: probes, ownPID: own, currentUID: me)
        let byPID = Dictionary(uniqueKeysWithValues: items.map { ($0.pid, $0) })

        suite.expect(byPID[100]?.kind == .dockApp && byPID[110]?.kind == .dockApp,
                     "regular apps are Dock apps in Apps")
        suite.expect(byPID[100]?.helpers.map(\.pid) == [101, 102],
                     "helpers nest under their app by responsibility or by bundle, highest CPU first")
        suite.expect(byPID[101] == nil && byPID[102] == nil && byPID[111] == nil,
                     "helpers never get a row of their own")
        suite.expect(byPID[110]?.helpers.map(\.pid) == [111],
                     "a system-path XPC service the app answers for is its helper, not a macOS agent")
        suite.expect(byPID[120]?.kind == .backgroundApp && byPID[120]?.scope == .background,
                     "a user-installed menu bar app is a background app")
        suite.expect(byPID[130]?.kind == .macOSAgent && byPID[130]?.scope == .background,
                     "a user-level macOS process with no parent app is a macOS agent in Background")
        suite.expect(byPID[131]?.kind == .backgroundApp,
                     "an unowned user process outside macOS paths stays actionable in Background")
        suite.expect(byPID[140]?.kind == .system && byPID[141]?.kind == .system,
                     "processes owned by system users are System, view only")
        suite.expect(byPID[own]?.kind == .lattice && byPID[own]?.scope == .apps,
                     "Lattice is listed in Apps as itself")
        suite.expect(byPID[150]?.kind == .backgroundApp,
                     "a helper whose parent has exited shows as a top-level Background row")
        suite.expect(byPID[160] == nil, "zombie processes are left out")
        suite.expect(byPID[161]?.kind == .macOSAgent && byPID[162]?.kind == .macOSAgent
                     && byPID[163]?.kind == .macOSAgent,
                     "Apple menu bar extras, path-less daemons and Apple bundles outside system paths are macOS agents")
        suite.expect(abs((byPID[100]?.cpuPercent ?? 0) - 23.9) < 0.001
                     && byPID[100]?.ownCPUPercent == 10,
                     "an app row totals its helpers' CPU")
        suite.expect(items.first?.pid == byPID[110]?.pid,
                     "rows sort by CPU, highest first")

        // Sections and search.
        let apps = KillProcessCatalog.sections(items, scope: .apps, query: "")
        suite.expect(apps.map(\.scope) == [.apps] && apps.first?.items.map(\.pid) == [own, 100, 110],
                     "a scope shows only its own section; Apps puts This app first, then the rest by name")
        let ordered = KillProcessCatalog.sections(items, scope: .apps, query: "", frontPID: 110,
                                                  isKept: { $0 == "notion.id" })
        suite.expect(ordered.first?.items.map(\.pid) == [own, 110, 100],
                     "Apps orders This app, Front, Kept, then the rest")
        let byCPU = KillProcessCatalog.sections(items, scope: .background, query: "", frontPID: 110)
        suite.expect(byCPU.first?.items.map(\.cpuPercent) == byCPU.first?.items.map(\.cpuPercent).sorted(by: >),
                     "other sections stay sorted by CPU")
        let everything = KillProcessCatalog.sections(items, scope: .everything, query: "")
        suite.expect(everything.map(\.scope) == [.apps, .background, .system],
                     "Everything shows Apps, Background and System in order")
        let helperMatch = KillProcessCatalog.sections(items, scope: .system, query: "gpu")
        suite.expect(helperMatch.map(\.scope) == [.apps]
                     && helperMatch.first?.items.map(\.pid) == [100]
                     && helperMatch.first?.expandedByQuery == [100],
                     "search looks in every scope and opens the parent of a matching helper")
        suite.expect(KillProcessCatalog.sections(items, scope: .apps, query: "130").first?.items.map(\.pid) == [130],
                     "search matches a whole PID")
        suite.expect(KillProcessCatalog.sections(items, scope: .apps, query: "13").flatMap { $0.items.map(\.pid) } == [131, 130],
                     "digits match PIDs from the start, so each digit narrows the list")
        suite.expect(KillProcessCatalog.sections(items, scope: .apps, query: "30").isEmpty,
                     "digits never match the middle of a PID")
        suite.expect(KillProcessCatalog.sections(items, scope: .apps, query: "zzz").isEmpty,
                     "a search with no match has no sections")
        suite.expect(KillProcessCatalog.count(items, in: .background) == 7
                     && KillProcessCatalog.count(items, in: .everything) == items.count,
                     "the scope menu counts top-level rows")

        // Row content.
        let notion = byPID[100]!, raycast = byPID[120]!, agent = byPID[130]!
        let system = byPID[140]!, lattice = byPID[own]!
        suite.expect(KillProcessCatalog.chip(for: notion, frontPID: 100, isKept: true, isNotResponding: true) == .notResponding
                     && KillProcessCatalog.chip(for: notion, frontPID: 100, isKept: true, isNotResponding: false) == .front
                     && KillProcessCatalog.chip(for: notion, frontPID: nil, isKept: true, isNotResponding: false) == .kept
                     && KillProcessCatalog.chip(for: lattice, frontPID: nil, isKept: true, isNotResponding: false) == .thisApp
                     && KillProcessCatalog.chip(for: system, frontPID: nil, isKept: false, isNotResponding: false) == nil
                     && KillProcessCatalog.chip(for: raycast, frontPID: nil, isKept: false, isNotResponding: false) == nil,
                     "a row shows at most one chip, in priority order")
        suite.expect(KillProcessCatalog.primaryAction(for: notion, isNotResponding: false) == .quit
                     && KillProcessCatalog.primaryAction(for: raycast, isNotResponding: false) == .stop
                     && KillProcessCatalog.primaryAction(for: agent, isNotResponding: false) == .stop
                     && KillProcessCatalog.primaryAction(for: notion, isNotResponding: true) == .forceQuit
                     && KillProcessCatalog.primaryAction(for: system, isNotResponding: false) == nil
                     && KillProcessCatalog.primaryAction(for: lattice, isNotResponding: true) == nil,
                     "each row has one primary action, none for System or Lattice")
        func enabled(_ item: KillProcessItem) -> [KillProcessMenuAction] {
            KillProcessCatalog.menu(for: item, in: item.scope).filter(\.isEnabled).map(\.action)
        }
        let appsMenu: [KillProcessMenuAction] = [.keepRunning, .forceQuit, .relaunch, .showInFinder, .copyPID]
        let otherMenu: [KillProcessMenuAction] = [.forceQuit, .relaunch, .showInFinder, .copyPID]
        suite.expect([notion, lattice].allSatisfy { KillProcessCatalog.menu(for: $0, in: .apps).map(\.action) == appsMenu }
                     && [raycast, agent, system, byPID[131]!].allSatisfy {
                         KillProcessCatalog.menu(for: $0, in: $0.scope).map(\.action) == otherMenu },
                     "Skip Quit All leads the Apps menu and is absent elsewhere; the rest is the same everywhere")
        suite.expect(KillProcessCatalog.menu(for: notion, in: .ports).map(\.action) == otherMenu,
                     "an app listed under Ports has no Skip Quit All there")
        suite.expect(enabled(notion) == appsMenu,
                     "a Dock app can use every item")
        suite.expect(enabled(raycast) == otherMenu,
                     "a background app can use every item its menu lists")
        suite.expect(enabled(agent) == [.forceQuit, .relaunch, .showInFinder, .copyPID],
                     "a macOS agent can be relaunched by launchd but not kept")
        suite.expect(enabled(system) == [.showInFinder, .copyPID] && enabled(lattice) == [.showInFinder, .copyPID],
                     "System processes and Lattice offer only Show in Finder and Copy PID")
        suite.expect(enabled(byPID[131]!) == [.forceQuit, .showInFinder, .copyPID],
                     "a process with no bundle cannot be relaunched or kept")
        suite.expect(KillProcessCatalog.hasDescription(agent, language: .enUS)
                     && KillProcessCatalog.hasDescription(system, language: .enUS)
                     && !KillProcessCatalog.hasDescription(notion, language: .enUS),
                     "known macOS agents and system processes get a What Is This? description")
        suite.expect(!KillProcessCatalog.hasDescription(byPID[163]!, language: .enUS)
                     && !KillProcessCatalog.hasDescription(agent, language: .de),
                     "no info icon when all Lattice could say is that it is part of macOS")

        // Quit Others.
        let kept: (String?) -> Bool = { $0 == "com.apple.Safari" }
        suite.expect(KillProcessCatalog.quitOthersTargets(apps[0], isKept: kept).map(\.pid) == [100],
                     "Quit Others in Apps skips kept apps and Lattice")
        let background = everything[1]
        suite.expect(KillProcessCatalog.quitOthersTargets(background, isKept: { _ in false }).isEmpty,
                     "Background never offers Quit all apps")
        suite.expect(KillProcessCatalog.quitOthersTargets(everything[2], isKept: { _ in false }).isEmpty,
                     "System never offers Quit Others")

        let webContent = "/System/Library/Frameworks/WebKit.framework/Versions/A/XPCServices/WebContent.xpc/Contents/MacOS/WebContent"
        suite.expect(KillProcessSupport.pathsMatch(reported: webContent,
                                                   kernel: "/System/Volumes/Preboot/Cryptexes/OS" + webContent)
                     && KillProcessSupport.pathsMatch(reported: "/bin/zsh", kernel: "/bin/zsh")
                     && !KillProcessSupport.pathsMatch(reported: webContent, kernel: "/tmp/WebContent")
                     && !KillProcessSupport.pathsMatch(reported: "/Volumes/Preboot" + webContent,
                                                       kernel: "/System/Volumes/Preboot/Cryptexes/OS" + webContent),
                     "a cryptex path from the kernel matches the plain /System path ps reports, and nothing else")
        // Ports.
        func port(_ number: Int, pid: pid_t, address: String = "127.0.0.1:\(0)") -> KillProcessPort {
            KillProcessPort(port: number, protocolName: "TCP", address: address, pid: pid,
                            processName: "p\(pid)", startedAt: 1)
        }
        let listening = KillProcessCatalog.items(from: probes, ownPID: own, currentUID: me, ports: [
            port(5173, pid: 101), port(3000, pid: 100), port(8080, pid: 131), port(9000, pid: 4242)])
        let listeningByPID = Dictionary(uniqueKeysWithValues: listening.map { ($0.pid, $0) })
        suite.expect(listeningByPID[100]?.ports.map(\.port) == [3000, 5173],
                     "a helper's port groups under its app, lowest port first")
        suite.expect(listening.flatMap(\.ports).count == 3,
                     "a port whose process is not listed is left out")
        let portSections = KillProcessCatalog.sections(listening, scope: .everything, query: "")
        suite.expect(portSections.map(\.scope) == [.apps, .ports, .background, .system],
                     "All Processes shows Ports between Apps and Background")
        suite.expect(portSections.first { $0.scope == .ports }?.items.map(\.pid) == [100, 131],
                     "Ports lists each listening app or process once, by lowest port")
        suite.expect(KillProcessCatalog.sections(listening, scope: .ports, query: "").first?.items.map(\.pid) == [100, 131]
                     && KillProcessCatalog.count(listening, in: .ports) == 2,
                     "the Ports scope shows only processes that listen")
        suite.expect(KillProcessCatalog.sections(listening, scope: .apps, query: ":8080").flatMap { $0.items.map(\.pid) } == [131, 131],
                     "search finds a process by a port it listens on, in its own section and in Ports")
        suite.expect(KillProcessCatalog.sections(listening, scope: .ports, query: ":80").flatMap { $0.items.map(\.pid) } == [131, 131]
                     && KillProcessCatalog.sections(listening, scope: .ports, query: "517").first { $0.scope == .ports }?.items.map(\.pid) == [100],
                     "ports match from the start too, with or without a colon")
        suite.expect(KillProcessCatalog.menu(for: listeningByPID[100]!, in: .ports).map(\.action) == otherMenu,
                     "a listening process keeps the standard menu in Ports")
        suite.expect(KillProcessCatalog.portPrimaryAction(for: listeningByPID[100]!, ownPID: own) == .stop,
                     "in Ports a Dock app's button is Stop, which ends only its listening processes")
        let ownPort = KillProcessCatalog.items(from: probes, ownPID: own, currentUID: me, ports: [port(7000, pid: own)])
        suite.expect(KillProcessCatalog.portPrimaryAction(for: ownPort.first { $0.pid == own }!, ownPID: own) == nil,
                     "Lattice never offers to stop its own ports")
        let unverified = KillProcessPort(port: 4000, protocolName: "TCP", address: "*:4000", pid: 131,
                                         processName: "node", startedAt: nil)
        suite.expect(KillProcessCatalog.stoppablePorts([unverified, port(4001, pid: 131)], ownPID: own).map(\.port) == [4001],
                     "a port whose process is not verified cannot be stopped")
        // Port services.
        typealias Services = KillProcessPortServices
        suite.expect(Services.service(processName: "ControlCenter", port: 5000, arguments: nil) == .airPlayAudio
                     && Services.service(processName: "ControlCenter", port: 7000, arguments: nil) == .airPlayReceiver
                     && Services.service(processName: "ControlCenter", port: 7100, arguments: nil) == nil,
                     "Control Center's fixed AirPlay ports are named; its other ports are not")
        suite.expect([55031, 65402, 65403].allSatisfy {
                         Services.service(processName: "rapportd", port: $0, arguments: nil) == .continuity },
                     "every rapportd port reads Continuity, with no guess about which one is Companion Link")
        suite.expect(Services.service(processName: "sshd", port: 22, arguments: nil) == .remoteLogin
                     && Services.service(processName: "launchd", port: 5900, arguments: nil) == .screenSharing
                     && Services.service(processName: "smbd", port: 445, arguments: nil) == .fileSharing,
                     "macOS sharing services are named by their well-known ports")
        suite.expect(Services.service(processName: "node", port: 8080,
                                      arguments: ["node", "/Users/me/app/node_modules/.bin/vite"]) == .tool("vite")
                     && Services.service(processName: "node", port: 3000, arguments: ["node", "server.js"]) == .tool("server")
                     && Services.service(processName: "python3", port: 8000,
                                         arguments: ["python3", "-m", "http.server", "8000"]) == .tool("http.server")
                     && Services.service(processName: "node", port: 4000,
                                         arguments: ["node", "--inspect", "/p/node_modules/next/dist/bin/index.js"]) == .tool("next"),
                     "a runtime's dev server is named after the tool or script it runs")
        suite.expect(Services.service(processName: "Raycast Backend", port: 7265, arguments: nil) == nil
                     && Services.service(processName: "node", port: 9000, arguments: nil) == nil,
                     "an app's own process, or a runtime whose command line can't be read, gets no label")
        suite.expect(Services.service(processName: "node", port: 5900, arguments: ["node", "server.js"]) == .tool("server")
                     && Services.service(processName: "Python", port: 22, arguments: nil) == nil,
                     "a sharing port held by some other process is not named after the sharing service")
        suite.expect(Services.service(processName: "python3", port: 8000,
                                      arguments: ["python3", "-c", "import http.server; http.server.test()"]) == nil
                     && Services.service(processName: "node", port: 8001, arguments: ["node", "-e", "require('http')"]) == nil,
                     "inline source is never used as a port label")
        let previous = [port(4100, pid: 131), port(4200, pid: 999)]
        suite.expect(KillProcessPortSupport.carriedOver(previous, probes: probes).map(\.port) == [4100],
                     "a timed-out port scan keeps the last listeners whose process is still listed")
        let labeled = KillProcessCatalog.items(from: probes, ownPID: own, currentUID: me, ports: [
            KillProcessPort(port: 5000, protocolName: "TCP", address: "*:5000", pid: 131, processName: "node",
                            startedAt: 1, service: .airPlayAudio)])
        suite.expect(KillProcessCatalog.sections(labeled, scope: .ports, query: "airplay").flatMap { $0.items.map(\.pid) } == [131, 131]
                     && KillProcessCatalog.sections(labeled, scope: .ports, query: "airplay-audio", language: .de)
                         .flatMap { $0.items.map(\.pid) } == [131, 131],
                     "search finds a process by what its ports are for, in English and the app's language")
        suite.expect(KillProcessListStrings.enUS.serviceName(.tool("vite")) == "vite"
                     && FeatureStrings.killProcessList(.de).serviceName(.screenSharing) == "Bildschirmfreigabe",
                     "service names are localized; tool names stay as they are")

        suite.expect(KillProcessPortSupport.listensOnAllInterfaces("*:3000")
                     && !KillProcessPortSupport.listensOnAllInterfaces("127.0.0.1:3000"),
                     "a wildcard bind is marked as open to the network")

        suite.expect(KillProcessCatalog.isSystemPath("/usr/libexec/logd")
                     && !KillProcessCatalog.isSystemPath("/usr/local/bin/node")
                     && !KillProcessCatalog.isSystemPath("/Applications/Notion.app"),
                     "only macOS install paths count as system paths")
    }
}
