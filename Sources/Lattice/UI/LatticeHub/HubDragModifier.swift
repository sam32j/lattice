// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

struct HubDragModifier: ViewModifier {
    let item: HubDragItem
    @ObservedObject var session: HubDragSession
    let isEnabled: Bool
    var onClick: () -> Void = {}

    func body(content: Content) -> some View {
        content
            .overlay {
                HubDragView(destination: .item(item), session: session, isEnabled: isEnabled,
                            onClick: onClick)
            }
            .opacity(session.active == item ? 0.4 : 1)
    }
}
