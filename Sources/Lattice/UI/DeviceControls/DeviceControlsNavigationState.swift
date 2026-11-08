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

    static func isActive(_ app: MixerApp) -> Bool {
        MixerRoutingSupport.shouldShowApp(
            isPlaying: app.isPlaying,
            volume: app.volume,
            selectedOutputDeviceUID: app.selectedOutputDeviceUID,
            hideInactiveApps: true
        )
    }

    static func height(
        apps: [MixerApp],
        showInactive: Bool
    ) -> CGFloat {
        let listHeight: CGFloat

        if !AppVolumeMixer.isSupported || apps.isEmpty {
            listHeight = emptyMessageHeight
        } else {
            let count = showInactive
                ? apps.count
                : apps.filter { isActive($0) }.count

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

    @Published private(set) var contentHeight: CGFloat = 430

    @Published var showInactiveApps = false {
        didSet { updateContentHeight() }
    }

    private var measuredMainHeight: CGFloat = 430
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

    private func updateContentHeight() {
        let target: CGFloat

        switch currentSubpage {
        case .main:
            target = measuredMainHeight

        case .appVolumes:
            target = DeviceControlsAppVolumesLayout.height(
                apps: latestApps,
                showInactive: showInactiveApps
            )
        }

        guard abs(contentHeight - target) > 1 else { return }
        contentHeight = target
    }
}
