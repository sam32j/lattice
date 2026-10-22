import SwiftUI

struct MouseShortcutExceptionEditor: View {
    let button: Int64
    @ObservedObject private var l10n = L10n.shared
    @State private var revision = 0

    var body: some View {
        let strings = FeatureStrings.mouseExceptions(l10n.language)
        let _ = revision
        AppBundleList(title: strings.listTitle,
                      caption: strings.captionButtonShortcuts,
                      addTitle: strings.addButton, removeLabel: strings.removeButton,
                      bundleIDs: MouseShortcutExceptions.list(for: button),
                      reachesEveryApp: true, acceptsExecutables: true, usesSheet: true,
                      onAdd: { app in
                          MouseShortcutExceptions.set(MouseShortcutExceptions.list(for: button) + [app], for: button)
                          revision += 1
                      }, onRemove: { app in
                          MouseShortcutExceptions.set(MouseShortcutExceptions.list(for: button).filter { $0 != app }, for: button)
                          revision += 1
                      })
    }
}
