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
            .overlay {
                if isEnabled, session.target?.item == item {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .allowsHitTesting(false)
                }
            }
            .opacity(session.active == item ? 0.4 : 1)
    }
}
