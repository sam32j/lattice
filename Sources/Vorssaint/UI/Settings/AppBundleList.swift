// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Shared app identity list and picker. Callers choose an inline disclosure or
/// a fixed-size editor sheet; both keep the same sorting and picker semantics.
struct AppBundleList<Accessory: View>: View {
    let title: String
    let caption: String
    let addTitle: String
    let removeLabel: String
    /// The listed bundle identifiers in any order; rows are sorted by name.
    let bundleIDs: [String]
    /// Whether the picker reaches every app instead of only the installed
    /// ones: it browses Applications and offers what is running as well.
    let reachesEveryApp: Bool
    /// Whether a program that is not packaged as an app may be added. Only the
    /// lists whose feature can recognize one at runtime pass this (issue #1009).
    let acceptsExecutables: Bool
    let onAdd: (String) -> Void
    let onRemove: (String) -> Void
    let accessory: (String) -> Accessory

    @State private var isExpanded: Bool
    @State private var showingAppPicker = false
    @State private var showingEditor = false
    let usesSheet: Bool
    let canRemove: (String) -> Bool

    init(title: String,
         caption: String,
         addTitle: String,
         removeLabel: String,
         bundleIDs: [String],
         reachesEveryApp: Bool = false,
         acceptsExecutables: Bool = false,
         usesSheet: Bool = false,
         canRemove: @escaping (String) -> Bool = { _ in true },
         onAdd: @escaping (String) -> Void,
         onRemove: @escaping (String) -> Void,
         @ViewBuilder accessory: @escaping (String) -> Accessory) {
        self.usesSheet = usesSheet
        self.canRemove = canRemove
        self.title = title
        self.caption = caption
        self.addTitle = addTitle
        self.removeLabel = removeLabel
        self.bundleIDs = bundleIDs
        self.reachesEveryApp = reachesEveryApp
        self.acceptsExecutables = acceptsExecutables
        self.onAdd = onAdd
        self.onRemove = onRemove
        self.accessory = accessory
        _isExpanded = State(initialValue: !bundleIDs.isEmpty)
    }

    var body: some View {
        Group {
            if usesSheet {
                SettingsControlRow(title: SettingsAppListStrings.text(L10n.shared.language).disabledApps) {
                    Button(SettingsAppListStrings.text(L10n.shared.language).edit) { showingEditor = true }
                }
                .sheet(isPresented: $showingEditor) { editorSheet }
            } else {
                DisclosureGroup(isExpanded: $isExpanded) {
                    appRows
                    addButton
                    Text(caption).font(.caption).foregroundStyle(.secondary)
                } label: {
                    HStack {
                        Text(title)
                        Spacer()
                        if !bundleIDs.isEmpty { Text("\(bundleIDs.count)").foregroundStyle(.secondary) }
                    }
                }
                .sheet(isPresented: $showingAppPicker) { appPickerSheet }
            }
        }
    }

    private var editorSheet: some View {
        AppListSheet(caption: caption, centersContent: bundleIDs.isEmpty, onDone: { showingEditor = false }) {
            if bundleIDs.isEmpty {
                ContentUnavailableView(SettingsAppListStrings.text(L10n.shared.language).disabledApps, systemImage: "app.dashed")
            } else {
                LazyVStack(spacing: 16) { appRows }.padding(16)
            }
        } footer: {
            addButton
        }
        .sheet(isPresented: $showingAppPicker) { appPickerSheet }
    }

    private var addButton: some View {
        Button { showingAppPicker = true } label: { Label(addTitle, systemImage: "plus") }
    }

    private var appRows: some View {
            ForEach(sortedBundleIDs, id: \.self) { bundleID in
                HStack(spacing: 9) {
                    Image(nsImage: InstalledApps.icon(for: bundleID))
                        .resizable()
                        .frame(width: 18, height: 18)
                    if let location = InstalledApps.location(for: bundleID) {
                        // Path identities all display the file's own name —
                        // every bundled runtime is "java" (issue #1009) — so
                        // the directory is what tells the rows apart. Sibling
                        // runtimes share a long common prefix and differ in
                        // the middle or tail, so the head is what truncation
                        // must drop: cutting the middle would hide exactly
                        // the component that differs.
                        VStack(alignment: .leading, spacing: 1) {
                            Text(InstalledApps.name(for: bundleID))
                                .lineLimit(1)
                            Text(location)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                        .help(bundleID)
                    } else {
                        Text(InstalledApps.name(for: bundleID))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    accessory(bundleID)
                    if canRemove(bundleID) {
                        Button { onRemove(bundleID) } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(removeLabel + ": " + InstalledApps.name(for: bundleID))
                    } else {
                        Image(systemName: "lock.fill").foregroundStyle(.tertiary)
                    }
                }
            }

    }

    private var sortedBundleIDs: [String] {
        bundleIDs.sorted {
            let byName = InstalledApps.name(for: $0)
                .localizedCaseInsensitiveCompare(InstalledApps.name(for: $1))
            // Equal display names — three runtimes all named "java" — fall
            // back to the identity so the rows hold one order between renders.
            return byName == .orderedSame ? $0 < $1 : byName == .orderedAscending
        }
    }

    private var appPickerSheet: some View {
        let listed = Set(bundleIDs)
        return AppPickerView(canBrowseApplications: reachesEveryApp,
                             acceptsExecutables: acceptsExecutables) {
            showingAppPicker = false
        } onSelect: { url in
            // Closed first: a file with nothing to be named by is nothing to
            // add, but the sheet still did its job and has to go away.
            showingAppPicker = false
            // What the picked file will be reported as once it runs (#1009),
            // which is a bundle identifier or a path depending on the file,
            // never on which of the two the sheet was pointed at. A list that
            // takes only apps drops a path rather than storing an entry its
            // own matcher would ignore.
            guard let identity = MouseAppExceptionSupport.pickedIdentity(for: url),
                  acceptsExecutables
                      || !MouseAppExceptionSupport.isExecutablePathIdentity(identity) else { return }
            onAdd(identity)
        } onSelectApp: { app in
            showingAppPicker = false
            guard let identity = app.explicitIdentity ?? MouseAppExceptionSupport.pickedIdentity(for: app.url),
                  acceptsExecutables
                      || !MouseAppExceptionSupport.isExecutablePathIdentity(identity) else { return }
            onAdd(identity)
        } loadApps: {
            InstalledApps.installedBundleApplications(excluding: listed,
                                                       includeRunningApplications: reachesEveryApp,
                                                       acceptsExecutables: acceptsExecutables)
        }
    }
}

extension AppBundleList where Accessory == EmptyView {
    init(title: String,
         caption: String,
         addTitle: String,
         removeLabel: String,
         bundleIDs: [String],
         reachesEveryApp: Bool = false,
         acceptsExecutables: Bool = false,
         usesSheet: Bool = false,
         canRemove: @escaping (String) -> Bool = { _ in true },
         onAdd: @escaping (String) -> Void,
         onRemove: @escaping (String) -> Void) {
        self.init(title: title,
                  caption: caption,
                  addTitle: addTitle,
                  removeLabel: removeLabel,
                  bundleIDs: bundleIDs,
                  reachesEveryApp: reachesEveryApp,
                  acceptsExecutables: acceptsExecutables,
                  usesSheet: usesSheet, canRemove: canRemove,
                  onAdd: onAdd,
                  onRemove: onRemove,
                  accessory: { _ in EmptyView() })
    }
}
