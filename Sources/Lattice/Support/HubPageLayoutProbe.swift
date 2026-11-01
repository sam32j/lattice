#if LATTICE_DEVELOPMENT
import AppKit
import SwiftUI

enum HubPageLayoutProbe {
    static func run(output: URL) throws {
        let launcher = LatticeHubService.shared
        let wasEditing = launcher.isEditing
        launcher.isEditing = true
        defer { launcher.isEditing = wasEditing }
        for (columns, width, count) in [(5, 424.0, 5), (5, 424.0, 10), (5, 424.0, 11),
                                        (6, 504.0, 5), (6, 504.0, 6), (6, 504.0, 12), (6, 504.0, 13)] {
            let items = Array(launcher.enabledItems.prefix(count))
            try HubEditingProbe.require(items.count == count, "Page fixture needs its complete catalog")
            let layout = HubToolLayout.island(count: count, width: width, columns: columns)
            let session = HubDragSession(launcher: launcher)
            let host = NSHostingView(rootView: HubIslandStripView(items: items, notchWidth: width,
                columns: columns, isEditing: true, launcher: launcher, session: session, onTap: { _ in }) { item in
                    Text(item.rawValue).font(.system(size: 11)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                }.background(.black))
            host.sizingOptions = []
            let window = NSWindow(contentRect: CGRect(x: 180, y: 180, width: width, height: layout.size.height),
                styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.orderFrontRegardless()
            defer { window.orderOut(nil); window.contentView = nil; window.close() }
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            host.layoutSubtreeIfNeeded()
            let scrolls = HubEditingProbe.descendants(host).compactMap { $0 as? NSScrollView }
            try HubEditingProbe.require(scrolls.isEmpty == (count <= columns * 2),
                "A complete single page must have no horizontal ScrollView or next-page bezel")
            guard let native = HubEditingProbe.descendants(host).compactMap({ $0 as? HubDragView.DragView })
                .first(where: { $0.configuration?.destination == .tools }),
                  native.configuration?.toolLayout == layout else {
                throw HubEditingProbe.failure("Page rendering and native drag slots must share the exact layout")
            }
            try HubEditingProbe.require(abs(host.convert(native.bounds, from: native).minX) < 1,
                                        "Sparse and full pages must remain aligned to the leading edge")
            if count >= min(5, columns), !layout.isPaged {
                try HubEditingProbe.require(abs(layout.frames[min(columns, count) - 1].maxX - width) < 0.01,
                                            "A complete first row must fill the viewport symmetrically")
            }
            try HubEditingProbe.capture(host, output: output.appendingPathComponent("page-\(columns)-\(count).png"))
            print("HUB_PAGE_OK columns=\(columns) count=\(count) paged=\(layout.isPaged) width=\(width)")
        }
    }
}
#endif
