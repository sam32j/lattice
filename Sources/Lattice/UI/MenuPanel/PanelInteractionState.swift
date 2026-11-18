// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

/// Shared hints between the panel content and the AppKit popover host.
final class PanelInteractionState {
    static let shared = PanelInteractionState()

    /// A visible utility whose workflow intentionally spans clicks in other
    /// apps. This is one input to the close policy, not the policy itself.
    var viewKeepsPopoverOpen = false

    /// A SwiftUI alert or confirmation dialog is presented from the popover.
    /// Closing its parent window underneath the presentation can leave AppKit's
    /// modal state orphaned and make the next panel unresponsive.
    var isPresentingPopoverModal = false

    /// The screen the menu bar icon is on, so the panel caps its height against
    /// that display instead of whichever one happens to be main. Deliberately
    /// not published: the panel reads it while measuring itself, and announcing
    /// a change mid layout would bounce the very height it is capping.
    var anchorScreen: NSScreen?

    private init() {}
}
