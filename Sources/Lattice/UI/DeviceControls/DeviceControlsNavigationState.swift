// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji


import Foundation
import Combine

enum DeviceControlsAppVolumesLayout {
    static let verticalInset: CGFloat = 4
    static let headerHeight: CGFloat = 16
    static let sectionSpacing: CGFloat = 10
    static let rowHeight: CGFloat = 78
    static let dividerHeight: CGFloat = 1
    static let emptyMessageHeight: CGFloat = 64
    static let emptyActiveHeight: CGFloat = 102

    static func isActive(_ app: MixerApp, arrangement: MixerAppArrangement? = nil) -> Bool {
        app.isPlaying
    }

    static func isVisible(_ app: MixerApp, showInactive: Bool, arrangement: MixerAppArrangement? = nil) -> Bool {
        if showInactive || app.isPlaying { return true }
        let arr = arrangement ?? MixerAppArrangement(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.mixerAppArrangement) ?? "")
        return arr.isPinned(app.persistenceID)
    }

    static func height(
        apps: [MixerApp],
        showInactive: Bool
    ) -> CGFloat {
        let listHeight: CGFloat

        if !AppVolumeMixer.isSupported || apps.isEmpty {
            listHeight = emptyMessageHeight
        } else {
            let arr = MixerAppArrangement(rawValue: UserDefaults.standard.string(forKey: DefaultsKey.mixerAppArrangement) ?? "")
            let count = apps.filter { isVisible($0, showInactive: showInactive, arrangement: arr) }.count

            if count == 0 {
                listHeight = emptyActiveHeight
            } else {
                listHeight =
                    CGFloat(count) * rowHeight +
                    CGFloat(count - 1) * dividerHeight
            }
        }

        return verticalInset * 2 +
            headerHeight +
            sectionSpacing +
            listHeight
    }
}

final class DeviceControlsNavigationState: ObservableObject {
    static let shared = DeviceControlsNavigationState()

    enum Subpage: Equatable {
        case main
        case appVolumes
    }

    @Published var currentSubpage: Subpage = .main {
        didSet { updateContentHeight() }
    }

    @Published private(set) var contentHeight: CGFloat = 450

    @Published var showInactiveApps = false {
        didSet { updateContentHeight() }
    }

    private(set) var measuredMainHeight: CGFloat = 450
    private(set) var measuredAppVolumesHeight: CGFloat = 0
    private var latestApps: [MixerApp] = []
    private var subscriptions = Set<AnyCancellable>()

    private init() {
        AppVolumeMixer.shared.$apps
            .receive(on: DispatchQueue.main)
            .sink { [weak self] apps in
                guard let self else { return }
                self.latestApps = apps
                self.updateContentHeight()
            }
            .store(in: &subscriptions)
    }

    func resetSubpage() {
        currentSubpage = .main
    }

    func updateMeasuredMainHeight(_ height: CGFloat) {
        guard height.isFinite, height > 0 else { return }

        let target = ceil(height)
        guard abs(measuredMainHeight - target) > 1 else {
            return
        }

        measuredMainHeight = target
        updateContentHeight()
    }

    func updateMeasuredAppVolumesHeight(_ height: CGFloat) {
        guard height.isFinite, height > 0 else { return }

        let target = ceil(height)
        guard abs(measuredAppVolumesHeight - target) > 1 else {
            return
        }

        measuredAppVolumesHeight = target
        updateContentHeight()
    }

    private func updateContentHeight() {
        let target: CGFloat

        switch currentSubpage {
        case .main:
            target = measuredMainHeight

        case .appVolumes:
            let calculated = DeviceControlsAppVolumesLayout.height(
                apps: latestApps,
                showInactive: showInactiveApps
            ) + 10
            let actual = measuredAppVolumesHeight > 0 ? measuredAppVolumesHeight : calculated
            // Minimal height of the inherited height of the device control page and max height of 670 px
            target = min(670, max(measuredMainHeight, actual))
        }

        guard abs(contentHeight - target) > 1 else { return }
        contentHeight = target
    }
}
