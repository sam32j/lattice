# Settings ergonomics

Approved: stable update actions, native changelog dismissal, and sidebar moves.

Updates: always show Check for updates, disabled only during checking,
downloading, and installing. Show Review update when an update is available;
it opens the existing preview. Idle means not checked yet. Render each real
state, including download progress and actionable failure details. Remove the
session flag and keep automatic-check preferences intact.

Changelog: title and version occupy a header above the scope picker. A Done
button and Escape dismiss through SwiftUI. Remove window-chrome mutation.
The parent Settings window remains open and unchanged.

Sidebar: Lattice contains About and Data and Permissions. Keyboard Shortcuts
follows Features in Essentials. Keyboard Light follows Displays under Energy
and Display, routes to Energy, and owns its brightness shortcuts there.
The central shortcuts page retains the same shortcut roles as another editor
of the same preferences.

Verification: update-state presentation, sidebar membership and search routes,
sheet dismissal and parent-window integrity, localized copy, development build,
selftest, full regression harness, and independent review.

Approved Utilities refinement: each sidebar selection opens only its own
preferences. Remove shortcut-only Quick panel and Camera preview sidebar rows;
their settings links target the matching Keyboard Shortcuts rows. Remove the
Quick Toggles settings entry while retaining its runtime panel actions.
Scratchpad and Cleaning Mode retain preferences, without duplicate launch
buttons. Microphone preferences remain isolated under Sound.

Wallpaper belongs to Energy and Display. Keyboard Light owns both hardware
controls and shortcut preferences in its Energy component. Dark-mode switching
belongs to Displays. Eject-disks exceptions belong to Command Bar settings,
with their filtering and persistence retained. This supersedes the earlier
request to delete disk exceptions.

Update balance: place status and last-checked time together as one text block,
centered beside the persistent action group, with a stacked narrow-width layout.
