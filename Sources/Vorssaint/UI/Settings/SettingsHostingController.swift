import AppKit
import SwiftUI

enum SettingsSidebarConfiguration {
    static let width: CGFloat = 230
    static let backgroundColor = NSColor(name: nil) { appearance in
        NSColor(calibratedWhite: appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? 0.14 : 0.92,
                alpha: 1)
    }

    static func apply(to controller: NSSplitViewController) {
        guard let sidebar = controller.splitViewItems.first else { return }
        sidebar.canCollapse = false
        sidebar.minimumThickness = width
        sidebar.maximumThickness = width
        if sidebar.isCollapsed { sidebar.isCollapsed = false }
    }
}

/// SwiftUI's suggested column width alone does not prevent AppKit collapse.
final class SettingsHostingController<Content: View>: NSHostingController<Content> {
    override func viewDidLayout() {
        super.viewDidLayout()
        if let split = splitController(in: self) ?? splitController(in: view) {
            SettingsSidebarConfiguration.apply(to: split)
        }
    }

    private func splitController(in controller: NSViewController) -> NSSplitViewController? {
        if let split = controller as? NSSplitViewController { return split }
        return controller.children.lazy.compactMap { self.splitController(in: $0) }.first
    }

    private func splitController(in view: NSView) -> NSSplitViewController? {
        if let split = view as? NSSplitView, let controller = split.delegate as? NSSplitViewController {
            return controller
        }
        return view.subviews.lazy.compactMap { self.splitController(in: $0) }.first
    }
}
