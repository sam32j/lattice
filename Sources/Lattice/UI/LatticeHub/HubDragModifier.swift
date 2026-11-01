// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji

import SwiftUI

struct HubDragModifier: ViewModifier {
    let item: HubDragItem
    @ObservedObject var session: HubDragSession
    let isEnabled: Bool
    var horizontal = true
    let symbol: String
    var onClick: () -> Void = {}

    private var marker: Alignment {
        horizontal ? (session.target?.after == true ? .trailing : .leading)
            : (session.target?.after == true ? .bottom : .top)
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                HubDragView(destination: .item(item), session: session, isEnabled: isEnabled,
                            horizontal: horizontal, symbol: symbol, onClick: onClick)
            }
            .overlay(alignment: marker) {
                if isEnabled, session.target?.item == item {
                    Capsule().fill(Color.accentColor)
                        .frame(width: horizontal ? 3 : nil, height: horizontal ? nil : 3)
                        .allowsHitTesting(false)
                }
            }
            .opacity(session.active == item ? 0.4 : 1)
    }
}
